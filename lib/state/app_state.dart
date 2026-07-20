import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../config/api_config.dart';
import '../data/api/api.dart';
import '../data/api/api_client.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../screens/registration/registration_data.dart';

enum RootTab { home, queue, patients, calendar, more }

enum ConsultSubTab { prescription, labTests, reports, history }

/// Which pre-main-app screen [RootShell] should show. Resolved at launch
/// (from a saved session) and after every login/logout/apply/verify.
enum AuthStage {
  /// Restoring a saved session — show a splash/loading state.
  checkingSession,

  /// No valid session — show the phone/OTP login screen.
  loggedOut,

  /// Logged in, but this account has no doctor application yet — show the
  /// onboarding choice (solo self-apply vs hospital invite).
  needsOnboarding,

  /// Logged in, application submitted, awaiting super-admin/hospital-admin
  /// review — show a "pending verification" screen.
  pendingReview,

  /// Logged in and `role == doctor` — show the main app.
  ready,
}

/// Central app state managing all authentication, onboarding, dashboard,
/// queue, WebRTC call, AI scribe, prescription signing, roster, and compliance logic.
///
/// Login/OTP (`sendOtp`/`verifyOtp`) is intentionally still mocked — see
/// `ApiConfig`'s doc comment for why. Everything else in this file that
/// touches the network calls the real `healthcare-api` backend (via `Api.*`)
/// or the AI microservice (via `Api.ai`) directly.
class AppState extends ChangeNotifier {
  AppState() {
    queue = MockData.buildQueue();
    patientHistory = MockData.buildPatientHistory();
    _allPatientHistory = List.from(patientHistory);
    _ensureSelectedHistory();
    sortQueue();
    _initConnectivity();
    // Fire-and-forget: restore yesterday's queue statuses + last-synced
    // timestamp from local storage so a killed app reopened offline still
    // shows real (not blank) data.
    hydrateQueueCache();
    hydrateSignatureCache();
    hydrateConsultationPreferences();
    _wireApiAuth();
    // Restores a saved session (if any) and routes to the right screen —
    // the mock/cached data above stays on screen until that resolves.
    unawaited(_bootstrapSession());
  }

  // ---- connectivity & offline cache ----
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool isOffline = false;

  /// Surfaces a fast, clear "you're offline" message instead of letting an
  /// action hang until the dio request eventually times out. Returns true
  /// (and pushes a notification) when the action should be skipped.
  bool _blockIfOffline(String actionDescription) {
    if (!isOffline) return false;
    _pushNotification("You're offline — $actionDescription will sync once you're back online.");
    return true;
  }

  void _initConnectivity() {
    _connectivity.checkConnectivity().then((result) {
      isOffline = result.every((r) => r == ConnectivityResult.none);
      notifyListeners();
    }).catchError((_) {
      // Platform channel unavailable (e.g. widget tests) — assume online.
    });
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final offline = results.every((r) => r == ConnectivityResult.none);
      if (offline != isOffline) {
        isOffline = offline;
        logAuditEvent(offline ? 'Device went offline' : 'Device back online');
        notifyListeners();
      }
    });
  }

  static const _kQueueStatusCacheKey = 'queue_status_cache';
  static const _kQueueLastUpdatedKey = 'queue_last_updated';

  Future<void> _persistQueueSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusMap = {for (final p in queue) p.id: p.status.name};
      await prefs.setString(_kQueueStatusCacheKey, jsonEncode(statusMap));
      await prefs.setString(_kQueueLastUpdatedKey, lastUpdatedQueue.toIso8601String());
    } catch (_) {
      // Best-effort local cache; a failure here shouldn't break the UI action.
    }
  }

  /// Restores cached appointment statuses (and the last-synced timestamp)
  /// from local storage, so re-opening the app while offline shows the
  /// state as of the last successful sync rather than a fresh mock reset.
  Future<void> hydrateQueueCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_kQueueStatusCacheKey);
      final updatedStr = prefs.getString(_kQueueLastUpdatedKey);
      if (cached != null) {
        final Map<String, dynamic> statusMap = jsonDecode(cached);
        for (final p in queue) {
          final saved = statusMap[p.id] as String?;
          if (saved != null) {
            p.status = ConsultStatus.values.firstWhere(
              (s) => s.name == saved,
              orElse: () => p.status,
            );
          }
        }
        sortQueue();
      }
      if (updatedStr != null) {
        lastUpdatedQueue = DateTime.tryParse(updatedStr) ?? lastUpdatedQueue;
      }
      notifyListeners();
    } catch (_) {
      // No cache yet, or platform channel unavailable — keep fresh mock data.
    }
  }

  // ---- authentication (POST /auth/mobile/send-otp + verify-otp) ----
  static const _kAccessTokenKey = 'auth_access_token';
  static const _kRefreshTokenKey = 'auth_refresh_token';

  AuthStage authStage = AuthStage.checkingSession;
  String? _accessToken;
  String? _refreshToken;
  bool otpSending = false;
  bool otpVerifying = false;
  String? devOtp;

  /// Wires the shared [ApiClient] to this instance's token state — set once,
  /// not re-created per request. [ApiClient] itself holds no session state.
  void _wireApiAuth() {
    ApiClient.instance.getAccessToken = () => _accessToken;
    ApiClient.instance.onUnauthorized = _tryRefreshToken;
  }

  Future<void> _persistTokens() async {
    try {
      await _secureStorage.write(key: _kAccessTokenKey, value: _accessToken);
      await _secureStorage.write(key: _kRefreshTokenKey, value: _refreshToken);
    } catch (_) {
      // Best-effort — the session still works for this run even if it can't
      // be persisted, it just won't survive an app restart.
    }
  }

  /// Restores a saved session at launch, if any, then routes to the right
  /// [AuthStage].
  Future<void> _bootstrapSession() async {
    try {
      // A platform channel with no native implementation (widget-test
      // sandbox, or a genuinely wedged secure-storage plugin on-device)
      // never rejects — it just never resolves. A short timeout keeps a
      // doctor from being stuck on the checking-session splash forever;
      // worst case they just see the login screen and sign in again.
      _accessToken = await _secureStorage.read(key: _kAccessTokenKey).timeout(const Duration(seconds: 5));
      _refreshToken = await _secureStorage.read(key: _kRefreshTokenKey).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Secure storage unavailable/timed out — treat as a fresh, logged-out session.
    }
    if (_accessToken == null || _refreshToken == null) {
      authStage = AuthStage.loggedOut;
      notifyListeners();
      return;
    }
    await _resolveSessionStage();
  }

  /// `POST /auth/mobile/send-otp`.
  Future<bool> sendOtp(String phone) async {
    otpSending = true;
    devOtp = null;
    notifyListeners();
    try {
      final result = await Api.mobileAuth.sendOtp(phone);
      // Only present while SMS isn't configured server-side — see
      // `mobileAuth.controller.js::sendOtp`'s `devOtp` field.
      devOtp = result['devOtp'] as String?;
      return true;
    } catch (e) {
      _pushNotification(_describeError(e));
      return false;
    } finally {
      otpSending = false;
      notifyListeners();
    }
  }

  /// `POST /auth/mobile/verify-otp` — on success, persists tokens and routes
  /// straight to the right [AuthStage] (main app / onboarding choice /
  /// pending review), so the login screen never has to know which.
  Future<bool> verifyOtp({required String phone, required String otp}) async {
    otpVerifying = true;
    notifyListeners();
    try {
      final result = await Api.mobileAuth.verifyOtp(phone: phone, otp: otp);
      _accessToken = result['accessToken'] as String?;
      _refreshToken = result['refreshToken'] as String?;
      if (_accessToken == null || _refreshToken == null) {
        _pushNotification('Login failed — please try again.');
        return false;
      }
      await _persistTokens();
      logAuditEvent('Logged in via OTP');
      await _resolveSessionStage();
      return true;
    } catch (e) {
      _pushNotification(_describeError(e));
      return false;
    } finally {
      otpVerifying = false;
      notifyListeners();
    }
  }

  /// Public entry point for screens that want to re-check the session (e.g.
  /// [PendingReviewScreen]'s "Check Status" button) without duplicating the
  /// resolution logic below.
  Future<void> refreshSessionStage() => _resolveSessionStage();

  /// Test-only backdoor: jumps straight to [stage] without a real OTP
  /// login/network round-trip. Widget tests exercise app *screens*, not the
  /// live backend — that's covered by manual/device testing instead (see the
  /// migration plan's verification section).
  @visibleForTesting
  void debugSignInForTests({AuthStage stage = AuthStage.ready, Map<String, dynamic>? profile}) {
    _accessToken = 'debug-test-token';
    _refreshToken = 'debug-test-refresh-token';
    authStage = stage;
    if (stage == AuthStage.ready) {
      doctorProfile = profile ??
          {
            'firstName': 'Ayush',
            'lastName': 'Gupta',
            'nmcRegistrationNumber': 'NMC-2016-MH-08421',
            'consultationFeeInPerson': 500,
            'consultationFeeOnline': 500,
          };
    }
    notifyListeners();
  }

  /// Tries `GET /doctors/me/profile` first — success means `role == doctor`
  /// already (that route is `authorize('doctor')`-gated), so the account is
  /// fully onboarded. A 403 means authenticated but not yet a doctor, so the
  /// application status decides between [AuthStage.needsOnboarding] and
  /// [AuthStage.pendingReview]. Any other failure (network) keeps the
  /// session as [AuthStage.ready] rather than bouncing back to login for a
  /// connectivity blip — per-screen loads already handle that gracefully.
  Future<void> _resolveSessionStage() async {
    try {
      doctorProfile = await Api.doctors.getMyProfile();
      authStage = AuthStage.ready;
      notifyListeners();
      unawaited(refreshQueue());
      unawaited(loadPatientHistory());
      unawaited(loadNotifications());
      unawaited(initPushNotifications());
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        await _refreshApplicationStage();
        return;
      }
      if (e.isUnauthorized) return; // onUnauthorized already handled/logged out
      authStage = AuthStage.ready;
      notifyListeners();
    } catch (_) {
      authStage = AuthStage.ready;
      notifyListeners();
    }
  }

  /// `GET /doctors/me/application-status` — distinguishes "never applied"
  /// from "applied, awaiting review" for an authenticated non-doctor account.
  Future<void> _refreshApplicationStage() async {
    try {
      final status = await Api.doctors.getMyApplicationStatus();
      authStage = status['hasApplication'] == true ? AuthStage.pendingReview : AuthStage.needsOnboarding;
    } catch (_) {
      authStage = AuthStage.needsOnboarding;
    }
    notifyListeners();
  }

  // ---- push notifications (PUT/DELETE /auth/fcm-token) ----
  String? _fcmToken;
  StreamSubscription<String>? _fcmTokenRefreshSub;

  /// Requests notification permission and registers this device's FCM token
  /// once signed in. Firebase itself is initialized in `main.dart`, guarded
  /// there — if no real Firebase project config has been dropped in yet
  /// (see that file's comment), every call here just throws and is caught,
  /// so a missing config degrades to "no push" rather than crashing.
  Future<void> initPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      notificationsGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      notifyListeners();
      if (!notificationsGranted) return;

      final token = await messaging.getToken();
      if (token != null) await _registerPushToken(token);

      await _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = messaging.onTokenRefresh.listen(_registerPushToken);
    } catch (e) {
      logAuditEvent('Push notification setup skipped: ${_describeError(e)}');
    }
  }

  Future<void> _registerPushToken(String token) async {
    try {
      await Api.auth.registerFcmToken(token, defaultTargetPlatform.name);
      _fcmToken = token;
    } catch (e) {
      logAuditEvent('FCM token registration failed: ${_describeError(e)}');
    }
  }

  Future<void> _removePushToken() async {
    await _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    final token = _fcmToken;
    if (token == null) return;
    try {
      await Api.auth.removeFcmToken(token);
    } catch (_) {
      // Best-effort — a stale token left registered just means one device
      // that may get an occasional push after logout, not a functional bug.
    } finally {
      _fcmToken = null;
    }
  }

  /// Refreshes the access token on a 401 from any authenticated call (see
  /// `ApiClient.onUnauthorized`); logs out if the refresh token is itself
  /// invalid/expired, since that means the session is truly dead.
  Future<bool> _tryRefreshToken() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      _accessToken = await Api.mobileAuth.refresh(refreshToken);
      await _persistTokens();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    if (rtcState != 'disconnected') await _teardownCall();
    await _removePushToken();
    _accessToken = null;
    _refreshToken = null;
    doctorProfile = null;
    authStage = AuthStage.loggedOut;
    nmcNumber = '';
    isNmcVerified = false;
    digitalSignature = '';
    notificationsGranted = false;
    cameraMicGranted = false;
    isAppLocked = false;
    regFirstName = '';
    regMiddleName = '';
    regLastName = '';
    regDateOfBirth = null;
    regGender = '';
    regContactPhone = '';
    regOfficialEmail = '';
    regExperienceYears = 0;
    regSpecialties = [];
    regQualifications = [];
    regLanguages = [];
    regClinicLocation = '';
    regState = '';
    regCity = '';
    regPincode = '';
    regVideoFee = 500;
    regInPersonFee = 500;
    regNmcCertificateFile = null;
    regGovIdFile = null;
    regDegreeCertificateFile = null;
    _resetConsultDraft();
    logAuditEvent('Logged out');
    notifyListeners();
    try {
      await _secureStorage.delete(key: _kAccessTokenKey);
      await _secureStorage.delete(key: _kRefreshTokenKey);
      await _secureStorage.delete(key: _kSignatureKey);
    } catch (_) {}
  }

  String nmcNumber = '';
  bool isNmcVerified = false;
  String digitalSignature = '';
  bool notificationsGranted = false;
  bool cameraMicGranted = false;
  bool isOnline = true;
  bool isAppLocked = false;

  // ---- doctor registration wizard (Welcome -> Doctor Registration) ----
  String regFirstName = '';
  String regMiddleName = '';
  String regLastName = '';
  DateTime? regDateOfBirth;
  String regGender = '';
  String regContactPhone = '';
  String regOfficialEmail = '';
  int regExperienceYears = 0;
  List<String> regSpecialties = [];
  List<Map<String, String>> regQualifications = [];
  List<String> regLanguages = [];
  String regClinicLocation = '';
  String regState = '';
  String regCity = '';
  String regPincode = '';
  double regVideoFee = 500;
  double regInPersonFee = 500;
  String? regNmcCertificateFile;
  String? regGovIdFile;
  String? regDegreeCertificateFile;

  // ---- real doctor profile (GET /doctors/me/profile) ----
  Map<String, dynamic>? doctorProfile;

  /// `doctorProfile` (real backend name) → `digitalSignature` (the name the
  /// doctor typed during onboarding's "Configure Digital Signature" step,
  /// stored locally) → a plain, honest "Doctor" placeholder. Never fabricates
  /// a fictitious name when neither is available yet.
  String get doctorDisplayName {
    final p = doctorProfile;
    if (p != null) {
      final name = _fullName(p);
      if (name.isNotEmpty) return 'Dr. $name';
    }
    final sig = digitalSignature.trim();
    if (sig.isNotEmpty) return sig.startsWith('Dr') ? sig : 'Dr. $sig';
    return 'Doctor';
  }

  /// Real NMC number when the profile has loaded, else whatever was entered
  /// in the (mocked) onboarding flow, else a placeholder.
  String get doctorNmcNumber {
    final real = doctorProfile?['nmcRegistrationNumber'] as String?;
    if (real != null && real.isNotEmpty) return real;
    return nmcNumber.isNotEmpty ? nmcNumber : 'NMC-2016-MH-08421';
  }

  String get doctorQualificationsLabel {
    final quals = doctorProfile?['qualifications'];
    if (quals is List && quals.isNotEmpty) {
      final degrees = quals.whereType<Map>().map((q) => q['degree']).whereType<String>().where((d) => d.isNotEmpty);
      if (degrees.isNotEmpty) return degrees.join(', ');
    }
    return 'MBBS, MD (Medicine)';
  }

  Future<void> loadDoctorProfile() async {
    try {
      doctorProfile = await Api.doctors.getMyProfile();
      notifyListeners();
    } catch (e) {
      logAuditEvent('Doctor profile load failed: ${_describeError(e)}');
    }
  }

  /// `PUT /doctors/me/profile` — merges [patch] into the real profile on
  /// success (so the UI reflects exactly what the server accepted) and
  /// returns whether it succeeded; callers show their own success/error UI.
  Future<bool> updateDoctorProfile(Map<String, dynamic> patch) async {
    if (_blockIfOffline('Saving your profile')) return false;
    try {
      doctorProfile = await Api.doctors.updateMyProfile(patch);
      logAuditEvent('Doctor profile updated');
      notifyListeners();
      return true;
    } catch (e) {
      final message = _describeError(e);
      logAuditEvent('Doctor profile update failed: $message');
      _pushNotification('Could not save your profile — $message');
      return false;
    }
  }

  // ---- working hours (GET/PUT /doctors/me/availability) ----
  static const weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  Map<String, dynamic>? doctorAvailability;
  bool isLoadingAvailability = false;

  /// Lazily loaded — only fetched when the doctor actually opens Working
  /// Hours, not eagerly at app start like `doctorProfile`.
  Future<void> loadAvailability() async {
    isLoadingAvailability = true;
    notifyListeners();
    try {
      doctorAvailability = await Api.doctors.getMyAvailability();
    } catch (e) {
      logAuditEvent('Availability load failed: ${_describeError(e)}');
      _pushNotification('Could not load your working hours — ${_describeError(e)}');
    } finally {
      isLoadingAvailability = false;
      notifyListeners();
    }
  }

  /// [weeklySchedule] maps each of [weekdays] to a list of `{start, end, mode}`
  /// (24h `HH:mm`, mode one of `online`/`in_person`/`both`) range maps — an
  /// empty list means "closed that day".
  Future<bool> saveAvailability(Map<String, List<Map<String, String>>> weeklySchedule, {required int slotDurationMinutes}) async {
    if (_blockIfOffline('Saving your working hours')) return false;
    try {
      doctorAvailability = await Api.doctors.setMyAvailability({'weeklySchedule': weeklySchedule, 'slotDurationMinutes': slotDurationMinutes});
      logAuditEvent('Working hours updated');
      notifyListeners();
      return true;
    } catch (e) {
      final message = _describeError(e);
      logAuditEvent('Working hours update failed: $message');
      _pushNotification('Could not save your working hours — $message');
      return false;
    }
  }

  // ---- navigation ----
  RootTab tab = RootTab.home;
  ConsultSubTab consultSubTab = ConsultSubTab.prescription;

  // ---- queue ----
  late List<QueuePatient> queue;
  NoShowAlert? noShowAlert;
  String? activePatientId;
  bool isLoadingQueue = false;
  DateTime lastUpdatedQueue = DateTime.now();

  // ---- LiveKit video call (POST /consultations/:id/video/token) ----
  String rtcState = 'disconnected'; // disconnected, connecting, connected, reconnecting, failed
  int callSeconds = 0;
  Timer? _callTimer;
  bool audioMuted = false;
  bool videoMuted = false;
  bool screenSharing = false;
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _roomListener;
  lk.VideoTrack? localVideoTrack;
  lk.VideoTrack? remoteVideoTrack;
  sio.Socket? _consultationSocket;

  // ---- Clinical documentation (populated from backend on resume; no live editor UI) ----
  SoapNote soap = SoapNote();
  IcdCode? selectedIcd;
  List<TranscriptLine> activeTranscript = [];
  bool aiPrescriptionLoading = false;

  // ---- prescription ----
  static const kDefaultFollowUpPrefKey = 'consultation_settings.default_follow_up';
  String _defaultFollowUpPreference = '7 Days';
  List<Medicine> rxMedicines = [Medicine()];
  String rxNotes = '';
  String followUp = '7 Days';
  String referral = 'None';
  bool prescriptionSending = false;
  bool prescriptionSent = false;
  String rxError = '';
  int signingStep = 0; // 0: none, 1: POST draft, 2: Approve PDF, 3: Complete Appt
  String signedPdfUrl = '';
  // Set once step 1 (create draft) succeeds so a retry after a step 2/3
  // failure re-uses the already-created prescription instead of creating a
  // duplicate. Cleared on final success or when the consult draft resets.
  String? _pendingPrescriptionId;
  // True when the prescription itself was signed successfully but the final
  // "mark consultation complete" sync step failed — surfaced on the signed
  // screen so the doctor knows to check the queue rather than assuming
  // everything finished cleanly.
  bool consultationCompletionFailed = false;

  // ---- patients history ----
  String? selectedHistoryId;
  late List<PatientHistory> patientHistory;
  List<PatientHistory> _allPatientHistory = [];
  Map<String, Map<String, dynamic>> _patientsById = {};
  bool isLoadingHistory = false;

  // ---- notifications & audit ----
  List<String> inAppNotifications = [];
  int unreadNotificationCount = 0;
  List<String> auditTrail = [];

  QueuePatient? get activePatient {
    final id = activePatientId;
    if (id != null) {
      for (final p in queue) {
        if (p.id == id) return p;
      }
    }
    return queue.isNotEmpty ? queue.first : null;
  }

  PatientHistory? get selectedHistory {
    final id = selectedHistoryId;
    if (id == null) return null;
    for (final p in patientHistory) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Keeps a history item selected by default (matching the original
  /// mock-data UX) without stomping on a real user selection: only resets
  /// to the first item when nothing is selected yet, or the previously
  /// selected item fell out of the current (possibly filtered/reloaded) list.
  void _ensureSelectedHistory() {
    final id = selectedHistoryId;
    final stillValid = id != null && patientHistory.any((h) => h.id == id);
    if (!stillValid) {
      selectedHistoryId = patientHistory.isNotEmpty ? patientHistory.first.id : null;
    }
  }

  /// Turns a caught error into a short, user-facing string. A 401 reaching
  /// here means `ApiClient.onUnauthorized` already tried and failed to
  /// refresh the session (see that hook in [_wireApiAuth]), which also
  /// triggers [logout] — so this is just the message for whatever call was
  /// in flight when that happened, not a call to action in itself.
  String _describeError(Object e) {
    if (e is ApiException) {
      if (e.isUnauthorized) {
        return 'Your session expired — please log in again.';
      }
      return e.message;
    }
    return e.toString();
  }

  /// Public entry point for screens that catch their own errors (e.g. a
  /// local PDF-open failure) and need the same friendly, non-technical
  /// copy this class already uses for its own audit log / notifications.
  String describeError(Object e) => _describeError(e);

  void _pushNotification(String text) {
    inAppNotifications.insert(0, text);
    notifyListeners();
  }

  // ---- doctor solo-apply application (POST /doctors/apply) ----
  /// Called once from the final "Submit Application" step of
  /// [DoctorRegistrationScreen] — already authenticated via the mobile JWT
  /// from OTP login, so `POST /doctors/apply` (`optionalAuth`) links the
  /// application to this account immediately rather than by email at
  /// verification time. Uploads any provided documents first.
  ///
  /// Returns an error message on failure, or null on success. Deliberately
  /// does NOT change [authStage] — the wizard shows a success summary first,
  /// and [acknowledgeApplicationSubmitted] is what actually navigates away,
  /// once the doctor continues past it (mirrors the previous mocked flow's
  /// UX, just backed by a real submission now).
  Future<String?> submitDoctorApplication(RegistrationData data) async {
    regFirstName = data.firstName;
    regMiddleName = data.middleName;
    regLastName = data.lastName;
    regDateOfBirth = data.dateOfBirth;
    regGender = data.gender;
    regContactPhone = data.contactPhone;
    regOfficialEmail = data.officialEmail;
    nmcNumber = data.nmcRegistrationNumber;
    regExperienceYears = data.experienceYears;
    regSpecialties = data.specialties;
    regQualifications = data.qualifications;
    regLanguages = data.languages;
    regClinicLocation = data.clinicLocation;
    regState = data.state;
    regCity = data.city;
    regPincode = data.pincode;
    regVideoFee = data.videoFee;
    regInPersonFee = data.inPersonFee;
    regNmcCertificateFile = data.nmcCertificateFile;
    regGovIdFile = data.govIdFile;
    regDegreeCertificateFile = data.degreeCertificateFile;
    notifyListeners();

    try {
      final documents = <String, String>{};
      if (data.nmcCertificateFile != null) {
        documents['nmcCert'] = await Api.doctors.uploadDocument(File(data.nmcCertificateFile!), 'nmc_cert');
      }
      if (data.govIdFile != null) {
        documents['idProof'] = await Api.doctors.uploadDocument(File(data.govIdFile!), 'gov_id');
      }
      if (data.degreeCertificateFile != null) {
        documents['degreeCert'] = await Api.doctors.uploadDocument(File(data.degreeCertificateFile!), 'degree_cert');
      }

      await Api.doctors.apply({
        'firstName': data.firstName,
        if (data.middleName.trim().isNotEmpty) 'middleName': data.middleName,
        'lastName': data.lastName,
        'email': data.officialEmail,
        if (data.gender.isNotEmpty) 'gender': data.gender.toLowerCase(),
        if (data.dateOfBirth != null) 'dateOfBirth': data.dateOfBirth!.toIso8601String(),
        'phone': data.contactPhone,
        'nmcRegistrationNumber': data.nmcRegistrationNumber,
        'specialties': data.specialties,
        'experience': data.experienceYears,
        'qualifications': data.qualifications
            .map((q) => {'degree': q['degree'], 'institution': q['institution'], 'year': int.tryParse(q['year'] ?? '')})
            .toList(),
        'languages': data.languages,
        'location': {'address': data.clinicLocation, 'city': data.city, 'state': data.state, 'pincode': data.pincode},
        'consultationFeeInPerson': data.inPersonFee,
        'consultationFeeOnline': data.videoFee,
        'consultationType': 'both',
        if (documents.isNotEmpty) 'documents': documents,
      });

      digitalSignature = data.fullName;
      isNmcVerified = false; // pending super-admin verification, not true yet
      logAuditEvent('Doctor application submitted for ${data.fullName}');
      notifyListeners();
      unawaited(_secureStorage.write(key: _kSignatureKey, value: data.fullName).catchError((_) {
        // Best-effort; the signature still works for this session even if
        // secure storage is unavailable, it just won't survive a restart.
      }));
      return null;
    } catch (e) {
      final message = _describeError(e);
      logAuditEvent('Doctor application submission failed: $message');
      return message;
    }
  }

  /// Called once the doctor dismisses the post-submit success summary.
  void acknowledgeApplicationSubmitted() {
    authStage = AuthStage.pendingReview;
    logAuditEvent('Application submission acknowledged');
    notifyListeners();
  }

  // ---- hospital-invite application (POST /invites/:token/*) ----
  /// `GET /invites/:token`. Returns null (and surfaces a notification) on
  /// any failure — invalid/expired/consumed tokens all read the same to the
  /// caller: "couldn't load this invite."
  Future<Map<String, dynamic>?> loadInvite(String token) async {
    try {
      return await Api.invites.get(token);
    } catch (e) {
      _pushNotification(_describeError(e));
      return null;
    }
  }

  /// `PUT /auth/me/email` — a phone-only OTP account has no email by
  /// default; the invite flow requires one matching the invite (see
  /// `invite.controller.js`'s `EMAIL_MISMATCH` check). Returns an error
  /// message, or null on success.
  Future<String?> setMyEmail(String email) async {
    try {
      await Api.auth.updateMyEmail(email);
      return null;
    } catch (e) {
      return _describeError(e);
    }
  }

  /// `POST /invites/:token/application` — autosave; failures are non-fatal
  /// per the website's own behavior (returns an error string for the caller
  /// to toast, not block navigation on).
  Future<String?> saveInviteDraft(String token, Map<String, dynamic> body) async {
    try {
      await Api.invites.saveDraft(token, body);
      return null;
    } catch (e) {
      return _describeError(e);
    }
  }

  Future<String?> uploadInviteDocument(String token, File file, String docType) async {
    try {
      await Api.invites.uploadDocument(token, file, docType);
      return null;
    } catch (e) {
      return _describeError(e);
    }
  }

  /// `POST /invites/:token/application/submit` — on success, moves to
  /// [AuthStage.pendingReview] immediately (unlike the solo-apply wizard,
  /// there's no local success-summary screen to defer past here).
  Future<String?> submitInviteApplication(String token) async {
    try {
      await Api.invites.submit(token);
      authStage = AuthStage.pendingReview;
      logAuditEvent('Hospital invite application submitted');
      notifyListeners();
      return null;
    } catch (e) {
      return _describeError(e);
    }
  }

  void grantNotificationPermission() {
    notificationsGranted = true;
    logAuditEvent('Notification permission granted');
    notifyListeners();
  }

  void grantCameraMicPermission() {
    cameraMicGranted = true;
    logAuditEvent('Camera & Mic permissions granted');
    notifyListeners();
  }

  void setAvailability(bool val) {
    isOnline = val;
    logAuditEvent('Doctor availability toggled to: ${val ? "Online" : "Offline"}');
    notifyListeners();
  }

  void lockApp() {
    isAppLocked = true;
    logAuditEvent('App locked');
    notifyListeners();
  }

  void unlockApp() {
    isAppLocked = false;
    logAuditEvent('App unlocked via Biometrics');
    notifyListeners();
  }

  void logAuditEvent(String action) {
    final timestamp = DateTime.now().toIso8601String();
    auditTrail.add('[$timestamp] $action');
  }

  // ---- navigation ----
  void setTab(RootTab t) {
    tab = t;
    notifyListeners();
  }

  void setConsultSubTab(ConsultSubTab t) {
    consultSubTab = t;
    notifyListeners();
  }

  // ---- queue actions ----
  void sortQueue() {
    queue.sort((a, b) {
      // In progress comes first
      if (a.status == ConsultStatus.inProgress && b.status != ConsultStatus.inProgress) return -1;
      if (b.status == ConsultStatus.inProgress && a.status != ConsultStatus.inProgress) return 1;

      // Waiting is second
      if (a.status == ConsultStatus.waiting && b.status != ConsultStatus.waiting && b.status != ConsultStatus.inProgress) return -1;
      if (b.status == ConsultStatus.waiting && a.status != ConsultStatus.inProgress && a.status != ConsultStatus.waiting) return 1;

      // Confirmed is third
      if (a.status == ConsultStatus.confirmed &&
          b.status != ConsultStatus.inProgress &&
          b.status != ConsultStatus.waiting &&
          b.status != ConsultStatus.confirmed) {
        return -1;
      }
      if (b.status == ConsultStatus.confirmed &&
          a.status != ConsultStatus.inProgress &&
          a.status != ConsultStatus.waiting &&
          a.status != ConsultStatus.confirmed) {
        return 1;
      }

      // Urgent bubbles to top within their categories
      if (a.isUrgent != b.isUrgent) {
        return a.isUrgent ? -1 : 1;
      }

      // Tie-break by time
      return a.time.compareTo(b.time);
    });
  }

  /// Appointment ids with a queue action (confirm/start/no-show/complete)
  /// currently syncing to the server. [refreshQueue] preserves the local
  /// entry for these instead of overwriting it with a possibly-stale server
  /// snapshot fetched mid-sync.
  final Set<String> _pendingSyncIds = {};

  /// `GET /appointments/doctor` → today's queue. Local walk-ins (added via
  /// [addWalkInPatient], which have no backend appointment) survive a
  /// refresh; everything else is replaced wholesale by the server's view.
  Future<void> refreshQueue() async {
    if (_blockIfOffline('Refreshing the queue')) return;
    isLoadingQueue = true;
    notifyListeners();
    try {
      final raw = await Api.appointments.listForDoctor();
      final mapped = raw.map(_mapAppointmentToQueuePatient).toList();
      final walkIns = queue.where((p) => p.isWalkIn).toList();
      final pending = {for (final p in queue) if (_pendingSyncIds.contains(p.id)) p.id: p};
      queue = [
        for (final p in mapped) pending[p.id] ?? p,
        ...walkIns,
      ];
      lastUpdatedQueue = DateTime.now();
      sortQueue();
      logAuditEvent('Queue refreshed from server');
    } catch (e) {
      logAuditEvent('Queue refresh failed: ${_describeError(e)}');
      _pushNotification('Could not refresh queue — ${_describeError(e)}');
    } finally {
      isLoadingQueue = false;
      notifyListeners();
      unawaited(_persistQueueSnapshot());
    }
  }

  // Queue actions below update local state optimistically and persist it to
  // the offline cache immediately, then sync to the server in the
  // background. A sync failure is logged and surfaced as a notification but
  // does NOT roll back the optimistic UI — this app is built offline-first
  // (see root AGENTS.md), and reverting a doctor's just-taken action the
  // moment the network hiccups would be worse than a background sync retry
  // (not yet implemented) catching up later.
  void confirmPatient(String id) {
    final p = _findQueue(id);
    if (p == null) return;
    p.status = ConsultStatus.confirmed;
    logAuditEvent('Appointment $id confirmed');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());

    _pendingSyncIds.add(id);
    unawaited(Api.appointments.confirm(id).catchError((e) {
      logAuditEvent('Confirm failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync confirmation with the server — ${_describeError(e)}');
      return <String, dynamic>{};
    }).whenComplete(() => _pendingSyncIds.remove(id)));
  }

  /// Prepares state for a brand-new consultation. Navigation into the
  /// Consult Room is the caller's responsibility (it's a pushed route, not
  /// a bottom-nav tab), since a doctor only ever enters it for a specific
  /// patient rather than browsing into it directly.
  void startNewConsult(String id) {
    _resetConsultDraft();
    final p = _findQueue(id);
    if (p == null) return;
    p.status = ConsultStatus.inProgress;
    activePatientId = id;
    consultSubTab = ConsultSubTab.prescription;
    logAuditEvent('Consultation started for patient $id');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());

    _pendingSyncIds.add(id);
    unawaited(() async {
      try {
        final result = await Api.appointments.start(id);
        final consultation = result['consultation'];
        if (consultation is Map) {
          p.consultationId = consultation['_id'] as String?;
          notifyListeners();
        }
      } catch (e) {
        // No consultationId means notes/soap/diagnosis/prescription-signing
        // for this consult can't sync later either — surfaced once here
        // rather than silently on each subsequent action.
        logAuditEvent('Failed to start consultation on server: ${_describeError(e)}');
        _pushNotification('Could not start consultation on the server — ${_describeError(e)}');
      } finally {
        _pendingSyncIds.remove(id);
      }
    }());
  }

  void resumeConsult(String id) {
    _resetConsultDraft();
    final p = _findQueue(id);
    if (p == null) return;
    activePatientId = id;
    consultSubTab = ConsultSubTab.prescription;
    logAuditEvent('Consultation resumed for patient $id');
    notifyListeners();
    final consultationId = p.consultationId;
    if (consultationId != null) {
      unawaited(_hydrateConsultation(consultationId));
    }
  }

  /// Pulls the SOAP note, primary diagnosis, and transcript for an
  /// already-started consultation back into local state — needed when a
  /// doctor resumes a consult after leaving the screen (or restarting the
  /// app) rather than staying on it start-to-finish.
  Future<void> _hydrateConsultation(String consultationId) async {
    try {
      final c = await Api.consultations.getById(consultationId);
      final soapNote = c['soapNote'];
      if (soapNote is Map && (soapNote['subjective'] != null || soapNote['assessment'] != null)) {
        final isDoctor = soapNote['doctorApproved'] == true;
        soap = SoapNote(
          subjective: (soapNote['subjective'] as String?) ?? '',
          objective: (soapNote['objective'] as String?) ?? '',
          assessment: (soapNote['assessment'] as String?) ?? '',
          plan: (soapNote['plan'] as String?) ?? '',
          subjectiveSource: isDoctor ? 'doctor' : 'ai',
          objectiveSource: isDoctor ? 'doctor' : 'ai',
          assessmentSource: isDoctor ? 'doctor' : 'ai',
          planSource: isDoctor ? 'doctor' : 'ai',
        );
      }
      final diagnosis = c['diagnosis'];
      if (diagnosis is List && diagnosis.isNotEmpty && diagnosis.first is Map) {
        final first = diagnosis.first as Map;
        selectedIcd = IcdCode(code: (first['icdCode'] as String?) ?? '', desc: (first['description'] as String?) ?? '');
      }
      final transcript = c['transcript'];
      final diarization = transcript is Map ? transcript['speakerDiarization'] : null;
      if (diarization is List) {
        activeTranscript = diarization
            .whereType<Map>()
            .map((t) => TranscriptLine(speaker: (t['speaker'] as String?) ?? 'doctor', text: (t['text'] as String?) ?? ''))
            .toList();
      }
      notifyListeners();
    } catch (e) {
      logAuditEvent('Could not load consultation details: ${_describeError(e)}');
    }
  }

  /// Completes the current consultation: pushes the SOAP note (if the
  /// doctor wrote one) then marks the appointment complete — which cascades
  /// to marking the linked consultation complete server-side too. Returns
  /// whether the server sync actually succeeded, so callers (e.g.
  /// [approveAndSign]) can tell a real completion apart from one that only
  /// happened locally.
  Future<bool> completeConsultation() async {
    if (rtcState != 'disconnected') await endCall();
    final id = activePatientId;
    final p = id == null ? null : _findQueue(id);
    if (p == null || id == null) return false;
    final consultationId = p.consultationId;
    p.status = ConsultStatus.completed;
    logAuditEvent('Consultation completed for patient $id');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());

    _pendingSyncIds.add(id);
    try {
      if (consultationId != null && soap.hasContent) {
        await Api.consultations.updateSoap(
          consultationId,
          subjective: soap.subjective,
          objective: soap.objective,
          assessment: soap.assessment,
          plan: soap.plan,
        );
      }
      await Api.appointments.complete(id);
      return true;
    } catch (e) {
      logAuditEvent('Complete failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync completion with the server — ${_describeError(e)}');
      return false;
    } finally {
      _pendingSyncIds.remove(id);
    }
  }

  void markNoShow(String id) {
    final p = _findQueue(id);
    if (p == null) return;
    p.status = ConsultStatus.noShow;
    unawaited(_persistQueueSnapshot());

    // Find next patient chronologically (scheduled or confirmed)
    final remaining = queue.where((q) =>
        q.id != id &&
        (q.status == ConsultStatus.scheduled ||
            q.status == ConsultStatus.confirmed ||
            q.status == ConsultStatus.waiting));

    noShowAlert = NoShowAlert(
      name: p.name,
      next: remaining.isNotEmpty ? remaining.first.name : null,
    );
    logAuditEvent('Patient $id marked as No-Show');
    sortQueue();
    notifyListeners();

    _pendingSyncIds.add(id);
    unawaited(Api.appointments.markNoShow(id).catchError((e) {
      logAuditEvent('No-show failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync no-show with the server — ${_describeError(e)}');
    }).whenComplete(() => _pendingSyncIds.remove(id)));
  }

  void seeNextPatient() {
    final alert = noShowAlert;
    if (alert != null && alert.next != null) {
      final match = queue.where((q) => q.name == alert.next);
      if (match.isNotEmpty) {
        startNewConsult(match.first.id);
      }
    }
    noShowAlert = null;
    notifyListeners();
  }

  void dismissNoShow() {
    noShowAlert = null;
    notifyListeners();
  }

  QueuePatient? _findQueue(String id) {
    for (final p in queue) {
      if (p.id == id) return p;
    }
    return null;
  }

  QueuePatient? findQueueById(String id) => _findQueue(id);

  /// Adds a walk-in patient directly to today's queue (no prior appointment,
  /// and — since there's no backend endpoint for a doctor to create an
  /// appointment on a patient's behalf — no backend record either). Survives
  /// `refreshQueue()` calls; can't be used for real prescriptions/consults
  /// since it has no `patientRecordId`.
  void addWalkInPatient({
    required String name,
    required int age,
    required String gender,
    required String mode,
  }) {
    final id = 'walkin-${DateTime.now().millisecondsSinceEpoch}';
    final now = TimeOfDay.now();
    final hour12 = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final time = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} '
        '${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    queue.add(QueuePatient(
      id: id,
      name: name,
      age: age,
      gender: gender,
      mode: mode,
      time: time,
      status: ConsultStatus.waiting,
      isWalkIn: true,
      isKnownPatient: false,
      riskSummary: const RiskSummary(tags: [], allergies: [], comorbidities: [], recentLabAbnormalities: 'None'),
      vitals: const VitalsSeries(bp: [], bpDates: [], hr: [], hrDates: []),
    ));
    logAuditEvent('Walk-in patient $name added to queue');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());
  }

  // ---- patient notes & lab tests (Patient Details / Consultation tabs) ----
  final Map<String, List<PatientNote>> patientNotes = {};
  final Map<String, List<LabTestOrder>> patientLabTests = {};

  List<PatientNote> notesFor(String patientId) => patientNotes[patientId] ?? const [];
  List<LabTestOrder> labTestsFor(String patientId) => patientLabTests[patientId] ?? const [];

  void addPatientNote(String patientId, String text) {
    if (text.trim().isEmpty) return;
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    patientNotes.putIfAbsent(patientId, () => []).insert(0, PatientNote(text: text.trim(), timestamp: timestamp));
    logAuditEvent('Note added for patient $patientId');
    notifyListeners();
  }

  void orderLabTest(String patientId, String testName) {
    patientLabTests.putIfAbsent(patientId, () => []).add(LabTestOrder(name: testName));
    logAuditEvent('Lab test "$testName" ordered for patient $patientId');
    notifyListeners();
  }

  // ---- app settings ----
  String selectedLanguage = 'English';

  void setLanguage(String value) {
    selectedLanguage = value;
    notifyListeners();
  }

  static const _kSignatureKey = 'digital_signature';

  /// Restores the doctor's digital signature from secure, encrypted-at-rest
  /// storage (Android Keystore / iOS Keychain via `flutter_secure_storage`)
  /// so it survives an app restart — matching what onboarding tells the
  /// doctor ("stored securely on your device").
  Future<void> hydrateSignatureCache() async {
    try {
      final saved = await _secureStorage.read(key: _kSignatureKey);
      if (saved != null && saved.isNotEmpty) {
        digitalSignature = saved;
        notifyListeners();
      }
    } catch (_) {
      // Secure storage unavailable (e.g. widget tests) — signature will be
      // re-entered via onboarding instead.
    }
  }

  /// Loads the doctor's saved default follow-up period (Profile ›
  /// Consultation Settings) so new prescriptions start from their real
  /// preference instead of an app-wide hardcoded '7 Days'.
  Future<void> hydrateConsultationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kDefaultFollowUpPrefKey);
      if (saved != null && saved.isNotEmpty) {
        _defaultFollowUpPreference = saved;
        followUp = saved;
        notifyListeners();
      }
    } catch (_) {
      // No preference saved yet, or platform channel unavailable.
    }
  }

  void _resetConsultDraft() {
    if (rtcState != 'disconnected') unawaited(_teardownCall());
    rtcState = 'disconnected';
    callSeconds = 0;
    _callTimer?.cancel();
    _callTimer = null;
    audioMuted = false;
    videoMuted = false;
    screenSharing = false;
    aiPrescriptionLoading = false;
    soap = SoapNote();
    selectedIcd = null;
    rxMedicines = [Medicine()];
    rxNotes = '';
    followUp = _defaultFollowUpPreference;
    referral = 'None';
    prescriptionSending = false;
    prescriptionSent = false;
    rxError = '';
    signingStep = 0;
    _pendingPrescriptionId = null;
    consultationCompletionFailed = false;
    activeTranscript = [];
  }

  // ---- LiveKit video call actions ----
  /// Test-only backdoor: drives the join/leave-confirmation UI without a
  /// real LiveKit connection, which needs camera/mic/network the widget-test
  /// sandbox doesn't have (see `debugSignInForTests`'s doc comment — same
  /// rationale). Real media is exercised by manual/device testing instead.
  @visibleForTesting
  void debugConnectCallForTests() {
    rtcState = 'connected';
    callSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      callSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Fetches a real LiveKit token (`POST /consultations/:id/video/token`,
  /// mobile-JWT-ready server-side) and connects. Requires the consultation
  /// to have already started — [startNewConsult]/[resumeConsult] set
  /// `p.consultationId`; there's no call without one.
  Future<void> beginCall() async {
    final id = activePatientId;
    final p = id == null ? null : _findQueue(id);
    final consultationId = p?.consultationId;
    if (consultationId == null) {
      _pushNotification('Could not start the call — this consultation has no server session yet.');
      return;
    }

    rtcState = 'connecting';
    notifyListeners();

    try {
      final tokenData = await Api.consultations.getVideoToken(consultationId);
      final token = tokenData['token'] as String?;
      final livekitUrl = tokenData['livekitUrl'] as String?;
      if (token == null || livekitUrl == null) {
        throw ApiException(message: 'Server did not return a video token');
      }

      final room = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: true, dynacast: true));
      _room = room;
      final listener = room.createListener();
      _roomListener = listener;
      _wireRoomEvents(listener);

      await room.connect(livekitUrl, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(true);
      localVideoTrack = _firstVideoTrack(room.localParticipant?.videoTrackPublications);

      rtcState = 'connected';
      callSeconds = 0;
      logAuditEvent('LiveKit call connected (consultation $consultationId)');

      _callTimer?.cancel();
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        callSeconds++;
        notifyListeners();
      });

      unawaited(_connectConsultationSocket(consultationId));
      notifyListeners();
    } catch (e) {
      rtcState = 'failed';
      logAuditEvent('LiveKit connect failed: ${_describeError(e)}');
      _pushNotification('Could not join the video call — ${_describeError(e)}');
      notifyListeners();
    }
  }

  lk.VideoTrack? _firstVideoTrack(List<lk.LocalTrackPublication>? pubs) {
    if (pubs == null || pubs.isEmpty) return null;
    final track = pubs.first.track;
    return track is lk.VideoTrack ? track as lk.VideoTrack : null;
  }

  void _wireRoomEvents(lk.EventsListener<lk.RoomEvent> listener) {
    listener
      ..on<lk.RoomReconnectingEvent>((_) {
        rtcState = 'reconnecting';
        logAuditEvent('LiveKit connection interrupted — reconnecting');
        notifyListeners();
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        rtcState = 'connected';
        logAuditEvent('LiveKit connection recovered');
        notifyListeners();
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        if (rtcState == 'disconnected') return;
        logAuditEvent('LiveKit room disconnected: ${event.reason}');
        unawaited(_teardownCall());
      })
      ..on<lk.TrackSubscribedEvent>((event) {
        final track = event.track;
        if (track is lk.VideoTrack) {
          remoteVideoTrack = track;
          notifyListeners();
        }
      })
      ..on<lk.TrackUnsubscribedEvent>((event) {
        if (identical(remoteVideoTrack, event.track)) {
          remoteVideoTrack = null;
          notifyListeners();
        }
      })
      ..on<lk.ParticipantDisconnectedEvent>((_) {
        remoteVideoTrack = null;
        logAuditEvent('Patient left the video call');
        notifyListeners();
      });
  }

  /// `/consultation` Socket.IO namespace — join/leave signalling and live
  /// transcript chunks (Deepgram STT, server-side). Auth rides the same
  /// mobile JWT as REST (`authAny`'s precedence — see the socket's server
  /// middleware). Audio capture-and-forward for transcription
  /// (`transcript:audio`) is NOT wired here: it would need a second,
  /// independent mic-capture pipeline running alongside LiveKit's own
  /// (mobile OS audio sessions are generally exclusive-access), which is a
  /// separate native-audio effort — the transcript panel still shows
  /// whatever the server pushes, honestly empty if nothing does.
  Future<void> _connectConsultationSocket(String consultationId) async {
    try {
      final socket = sio.io(
        '${ApiConfig.socketBaseUrl}/consultation',
        sio.OptionBuilder()
            .setTransports(['websocket'])
            .setQuery({'token': _accessToken ?? ''})
            .disableAutoConnect()
            .build(),
      );
      _consultationSocket = socket;
      socket.onConnect((_) {
        socket.emit('consultation:join', {'consultationId': consultationId});
        socket.emit('transcript:start', {'consultationId': consultationId});
      });
      socket.on('transcript:chunk', (data) {
        if (data is Map) {
          activeTranscript.add(TranscriptLine(speaker: (data['speaker'] as String?) ?? 'doctor', text: (data['text'] as String?) ?? ''));
          notifyListeners();
        }
      });
      socket.on('message:received', (data) {
        if (data is Map && data['message'] is Map) {
          inCallMessages.add(Map<String, dynamic>.from(data['message'] as Map));
          notifyListeners();
        }
      });
      socket.on('participant:joined', (_) => logAuditEvent('Patient joined the consultation room'));
      socket.on('participant:left', (_) => logAuditEvent('Patient left the consultation room'));
      socket.on('error', (data) => logAuditEvent('Consultation socket error: $data'));
      socket.connect();
    } catch (e) {
      logAuditEvent('Consultation socket connect failed: ${_describeError(e)}');
    }
  }

  /// In-call async chat (`message:send`/`message:received`) — separate from
  /// the transcript; persisted server-side on `Consultation.messages`.
  List<Map<String, dynamic>> inCallMessages = [];

  void sendConsultationMessage(String text) {
    final trimmed = text.trim();
    final socket = _consultationSocket;
    final id = activePatientId;
    final consultationId = id == null ? null : _findQueue(id)?.consultationId;
    if (trimmed.isEmpty || socket == null || consultationId == null) return;
    socket.emit('message:send', {'consultationId': consultationId, 'text': trimmed});
  }

  Future<void> endCall() => _teardownCall(emitLeave: true);

  Future<void> _teardownCall({bool emitLeave = false}) async {
    if (emitLeave) {
      final id = activePatientId;
      final consultationId = id == null ? null : _findQueue(id)?.consultationId;
      if (consultationId != null) {
        _consultationSocket?.emit('transcript:stop', {'consultationId': consultationId});
        _consultationSocket?.emit('consultation:leave', {'consultationId': consultationId});
      }
    }
    _callTimer?.cancel();
    _callTimer = null;
    await _roomListener?.dispose();
    _roomListener = null;
    try {
      await _room?.disconnect();
    } catch (_) {
      // Already gone (e.g. server-initiated disconnect) — nothing to clean up.
    }
    _room = null;
    localVideoTrack = null;
    remoteVideoTrack = null;
    _consultationSocket?.disconnect();
    _consultationSocket = null;
    inCallMessages = [];
    rtcState = 'disconnected';
    audioMuted = false;
    videoMuted = false;
    screenSharing = false;
    logAuditEvent('LiveKit call ended');
    notifyListeners();
  }

  Future<void> toggleMic() async {
    final newMuted = !audioMuted;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(!newMuted);
      audioMuted = newMuted;
    } catch (e) {
      logAuditEvent('Toggle microphone failed: ${_describeError(e)}');
    }
    notifyListeners();
  }

  Future<void> toggleCam() async {
    final newMuted = !videoMuted;
    try {
      await _room?.localParticipant?.setCameraEnabled(!newMuted);
      videoMuted = newMuted;
      localVideoTrack = newMuted ? null : _firstVideoTrack(_room?.localParticipant?.videoTrackPublications);
    } catch (e) {
      logAuditEvent('Toggle camera failed: ${_describeError(e)}');
    }
    notifyListeners();
  }

  Future<void> toggleShare() async {
    final newSharing = !screenSharing;
    try {
      await _room?.localParticipant?.setScreenShareEnabled(newSharing);
      screenSharing = newSharing;
    } catch (e) {
      // Mobile screen-share needs a foreground service + MediaProjection
      // flow (Android) that isn't wired in this pass — fails gracefully.
      logAuditEvent('Screen share toggle failed: ${_describeError(e)}');
      _pushNotification('Screen sharing is not available on this device yet.');
    }
    notifyListeners();
  }

  // ---- drug warning logic ----
  // Local allergy cross-check against the patient's known allergy list —
  // stays client-side rather than calling `GET /ai/drug-interactions`
  // (confirmed a hardcoded stub server-side, always returns `interactions:
  // []` regardless of input — wiring it would make results *worse* than
  // this).
  List<String> getWarningsForMed(String medName) {
    final warnings = <String>[];
    if (medName.trim().isEmpty) return warnings;
    final patient = activePatient;
    if (patient != null) {
      for (final allergy in patient.riskSummary.allergies) {
        final normAllergy = allergy.toLowerCase();
        final normMed = medName.toLowerCase();
        if (normAllergy.contains('penicillin') &&
            (normMed.contains('penicillin') ||
                normMed.contains('amoxicillin') ||
                normMed.contains('ampicillin') ||
                normMed.contains('peni'))) {
          warnings.add('⚠️ Penicillin Allergy: Avoid Penicillins');
        }
        if (normAllergy.contains('sulfa') &&
            (normMed.contains('sulfa') ||
                normMed.contains('bactrim') ||
                normMed.contains('septra') ||
                normMed.contains('co-trimoxazole'))) {
          warnings.add('⚠️ Sulfa Allergy: Avoid Sulfa medications');
        }
        if (normAllergy.contains('aspirin') &&
            (normMed.contains('aspirin') ||
                normMed.contains('ibuprofen') ||
                normMed.contains('advil') ||
                normMed.contains('naproxen') ||
                normMed.contains('nsaid'))) {
          warnings.add('⚠️ Aspirin/NSAID Allergy: Avoid Aspirin & NSAIDs');
        }
      }
    }
    return warnings;
  }

  List<String> getDrugInteractions() {
    final interactions = <String>[];
    final names = rxMedicines.map((m) => m.name.toLowerCase().trim()).toList();
    bool hasMed(String term) => names.any((n) => n.contains(term));

    if (hasMed('sildenafil') && hasMed('nitroglycerin')) {
      interactions.add('❌ Severe Interaction: Sildenafil + Nitroglycerin causes fatal hypotension.');
    }
    if (hasMed('aspirin') && hasMed('ibuprofen')) {
      interactions.add('⚠️ Interaction: Ibuprofen limits antiplatelet action of Aspirin.');
    }
    if (hasMed('warfarin') && hasMed('aspirin')) {
      interactions.add('❌ Severe Interaction: Warfarin + Aspirin significantly increases bleeding risk.');
    }
    return interactions;
  }

  // ---- prescription actions ----
  bool get hasValidMedicine => rxMedicines.any((m) => m.name.trim().isNotEmpty);

  void addMed({String name = '', bool aiSuggested = false}) {
    rxMedicines.add(Medicine(name: name, aiSuggested: aiSuggested));
    notifyListeners();
  }

  /// Inserts a fully-specified medicine (name/dosage/frequency/duration) —
  /// used by the Prescription Templates screen to drop a saved preset
  /// straight into the active Rx builder, replacing the lone blank row if
  /// nothing's been typed yet rather than leaving an empty row above it.
  void addMedFromTemplate(Medicine template) {
    final copy = Medicine(name: template.name, dosage: template.dosage, freq: template.freq, duration: template.duration, dosageForm: template.dosageForm);
    if (rxMedicines.length == 1 && rxMedicines.first.name.trim().isEmpty) {
      rxMedicines[0] = copy;
    } else {
      rxMedicines.add(copy);
    }
    notifyListeners();
  }

  void removeMed(int i) {
    rxMedicines.removeAt(i);
    notifyListeners();
  }

  void updateMedicineName(int index, String value) {
    final m = rxMedicines[index];
    m.name = value;
    // Editing an AI suggestion by hand means it's no longer AI-authored.
    m.aiSuggested = false;
    notifyListeners();
  }

  void updateMedicineDosage(int index, String value) {
    rxMedicines[index].dosage = value;
    notifyListeners();
  }

  void updateMedicineFreq(int index, String value) {
    rxMedicines[index].freq = value;
    notifyListeners();
  }

  void updateMedicineDuration(int index, String value) {
    rxMedicines[index].duration = value;
    notifyListeners();
  }

  void updateMedicineDosageForm(int index, String value) {
    rxMedicines[index].dosageForm = value;
    notifyListeners();
  }

  void setRxNotes(String v) {
    rxNotes = v;
    notifyListeners();
  }

  void setFollowUp(String v) {
    followUp = v;
    notifyListeners();
  }

  void setReferral(String v) {
    referral = v;
    notifyListeners();
  }

  void setRxError(String message) {
    rxError = message;
    notifyListeners();
  }

  /// `POST /ai/prescription` — AI-assisted prescription drafting. Suggested
  /// medicines are inserted marked `aiSuggested: true`; the doctor can edit
  /// or remove any of them before signing (editing a name clears the flag —
  /// see `updateMedicineName`). Always advisory: nothing here bypasses the
  /// sign/approve flow.
  Future<void> requestAiPrescriptionSuggestion() async {
    final patient = activePatient;
    if (patient == null || aiPrescriptionLoading) return;
    final diagnosis = selectedIcd?.desc ?? patient.chiefComplaint;
    if (diagnosis.trim().isEmpty) {
      _pushNotification('Select a diagnosis (ICD-10 code) before requesting an AI prescription suggestion.');
      return;
    }
    aiPrescriptionLoading = true;
    notifyListeners();
    try {
      final result = await Api.ai.prescription(
        diagnosis: diagnosis,
        patientProfile: {
          'age': patient.age,
          'gender': patient.gender == 'F' ? 'female' : (patient.gender == 'M' ? 'male' : 'other'),
          'allergies': patient.riskSummary.allergies,
          'current_medications': patient.currentMedications,
          'comorbidities': patient.riskSummary.comorbidities,
        },
      );
      final suggestions = result['suggested_medicines'];
      if (suggestions is List) {
        for (final item in suggestions) {
          if (item is! Map) continue;
          final medicine = Medicine(
            name: (item['name'] as String?) ?? '',
            dosage: (item['dosage'] as String?) ?? '',
            freq: (item['frequency'] as String?) ?? '',
            duration: (item['duration'] as String?) ?? '',
            aiSuggested: true,
          );
          if (rxMedicines.length == 1 && rxMedicines.first.name.trim().isEmpty) {
            rxMedicines[0] = medicine;
          } else {
            rxMedicines.add(medicine);
          }
        }
      }
      final allergyFlags = result['allergy_flags'];
      if (allergyFlags is List) {
        for (final flag in allergyFlags) {
          _pushNotification('AI prescription flag: $flag');
        }
      }
      logAuditEvent('AI prescription suggestions applied');
    } catch (e) {
      _pushNotification('Could not get AI prescription suggestions — ${_describeError(e)}');
      logAuditEvent('AI prescription request failed: ${_describeError(e)}');
    } finally {
      aiPrescriptionLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveAndSign() async {
    final hasNamed = rxMedicines.any((m) => m.name.trim().isNotEmpty);
    if (!hasNamed) {
      rxError = 'Add at least one named medicine before signing.';
      notifyListeners();
      return;
    }
    final patient = activePatient;
    if (patient == null) {
      rxError = 'No active patient for this consultation.';
      notifyListeners();
      return;
    }
    final patientRecordId = patient.patientRecordId;
    if (patientRecordId == null) {
      rxError = 'This patient has no backend record (a local walk-in) — cannot sign a prescription against the server.';
      notifyListeners();
      return;
    }
    if (_blockIfOffline('Signing this prescription')) return;

    rxError = '';
    prescriptionSending = true;
    consultationCompletionFailed = false;
    signingStep = 1; // POST draft
    logAuditEvent('Beginning prescription sign flow');
    notifyListeners();

    try {
      // If a previous attempt already created the draft (and only failed on
      // approve/complete), reuse it instead of creating a duplicate.
      String prescriptionId;
      if (_pendingPrescriptionId != null) {
        prescriptionId = _pendingPrescriptionId!;
      } else {
        final created = await Api.prescriptions.create({
          'patientId': patientRecordId,
          if (patient.consultationId != null) 'consultationId': patient.consultationId,
          'diagnosis': [if (selectedIcd != null) selectedIcd!.desc],
          'notes': rxNotes,
          'medicines': rxMedicines.where((m) => m.name.trim().isNotEmpty).map((m) {
            return {
              'name': m.name,
              'strength': m.dosage,
              'dosageForm': m.dosageForm,
              'frequency': {
                'timesPerDay': _parseTimesPerDay(m.freq),
                'times': <String>[],
                'instructions': m.freq,
              },
              'durationDays': int.tryParse(m.duration.trim()) ?? 0,
              'aiSuggested': m.aiSuggested,
            };
          }).toList(),
        });
        final id = created['_id'] as String?;
        if (id == null) {
          throw ApiException(message: 'Server did not return a prescription id.');
        }
        prescriptionId = id;
        _pendingPrescriptionId = prescriptionId;
      }

      // Step 2: Approve & generate PDF
      signingStep = 2;
      notifyListeners();
      final pdfUrl = await Api.prescriptions.approve(prescriptionId);
      signedPdfUrl = pdfUrl ?? '';

      // Step 3: Complete the consultation (pushes SOAP + marks the
      // appointment — and its linked consultation — completed server-side).
      // The prescription is already validly signed at this point regardless
      // of whether this step's server sync succeeds, so a failure here is
      // surfaced as a warning rather than treated as the whole flow failing
      // (which would otherwise let a retry re-create the prescription).
      signingStep = 3;
      notifyListeners();
      final completed = await completeConsultation();
      consultationCompletionFailed = !completed;

      patientHistory.insert(
        0,
        PatientHistory(
          id: patient.consultationId ?? prescriptionId,
          name: patient.name,
          age: patient.age,
          gender: patient.gender,
          mode: patient.mode,
          date: 'Today',
          diagnosis: [if (selectedIcd != null) selectedIcd!.desc],
          soap: SoapNote(
            subjective: soap.subjective,
            objective: soap.objective,
            assessment: soap.assessment,
            plan: soap.plan,
            subjectiveSource: soap.subjectiveSource,
            objectiveSource: soap.objectiveSource,
            assessmentSource: soap.assessmentSource,
            planSource: soap.planSource,
          ),
          transcript: List.from(activeTranscript),
          rx: Prescription(status: 'approved', medicines: List.from(rxMedicines), pdf: signedPdfUrl.isNotEmpty),
        ),
      );

      prescriptionSending = false;
      prescriptionSent = true;
      signingStep = 0;
      _pendingPrescriptionId = null;
      logAuditEvent(consultationCompletionFailed
          ? 'Prescription signed, but consultation completion failed to sync'
          : 'Prescription signed & consultation finalised');
    } catch (e) {
      prescriptionSending = false;
      signingStep = 0;
      rxError = 'API Error: ${_describeError(e)}';
      logAuditEvent('Prescription signing failed: ${_describeError(e)}');
    }
    notifyListeners();
  }

  void resetRx() {
    prescriptionSent = false;
    consultationCompletionFailed = false;
    rxMedicines = [Medicine()];
    notifyListeners();
  }

  // ---- patient history (Patients tab) ----

  /// Joins `GET /consultations/doctor` (no populated patient info) against
  /// `GET /doctors/me/patients` (full patient docs) for display names.
  Future<void> loadPatientHistory() async {
    if (_blockIfOffline('Loading patient history')) return;
    isLoadingHistory = true;
    notifyListeners();
    try {
      final patients = await Api.doctors.getMyPatients();
      _patientsById = {
        for (final p in patients)
          if (p['_id'] is String) p['_id'] as String: p,
      };
      final consultations = await Api.consultations.listMine();
      // Map each record independently — one malformed consultation
      // shouldn't blank out the doctor's entire patient history.
      _allPatientHistory = [
        for (final c in consultations)
          if (_tryMapConsultationToHistory(c) case final h?) h,
      ];
      patientHistory = List.from(_allPatientHistory);
      _ensureSelectedHistory();
      logAuditEvent('Patient history loaded from server');
    } catch (e) {
      logAuditEvent('Patient history load failed: ${_describeError(e)}');
      _pushNotification('Could not load patient history — ${_describeError(e)}');
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Wraps [_mapConsultationToHistory] so one record with an unexpected
  /// field type logs and is skipped instead of throwing out of the whole
  /// `.map()` and aborting the entire history refresh.
  PatientHistory? _tryMapConsultationToHistory(Map<String, dynamic> c) {
    try {
      return _mapConsultationToHistory(c);
    } catch (e) {
      logAuditEvent('Skipped a malformed consultation record: ${_describeError(e)}');
      return null;
    }
  }

  PatientHistory _mapConsultationToHistory(Map<String, dynamic> c) {
    final rawPatientId = c['patientId'];
    final matched = rawPatientId is String ? _patientsById[rawPatientId] : null;
    final name = matched != null ? _fullName(matched) : 'Unknown patient';

    final soapNote = c['soapNote'];
    final isDoctorApproved = soapNote is Map && soapNote['doctorApproved'] == true;
    final soapForHistory = soapNote is Map
        ? SoapNote(
            subjective: (soapNote['subjective'] as String?) ?? '',
            objective: (soapNote['objective'] as String?) ?? '',
            assessment: (soapNote['assessment'] as String?) ?? '',
            plan: (soapNote['plan'] as String?) ?? '',
            subjectiveSource: isDoctorApproved ? 'doctor' : 'ai',
            objectiveSource: isDoctorApproved ? 'doctor' : 'ai',
            assessmentSource: isDoctorApproved ? 'doctor' : 'ai',
            planSource: isDoctorApproved ? 'doctor' : 'ai',
          )
        : SoapNote();

    final diagnosisRaw = c['diagnosis'];
    final diagnosis = diagnosisRaw is List
        ? diagnosisRaw.whereType<Map>().map((d) => (d['description'] as String?) ?? '').where((s) => s.isNotEmpty).toList()
        : <String>[];

    final transcriptMap = c['transcript'];
    final diarization = transcriptMap is Map ? transcriptMap['speakerDiarization'] : null;
    final transcript = diarization is List
        ? diarization
            .whereType<Map>()
            .map((t) => TranscriptLine(speaker: (t['speaker'] as String?) ?? 'doctor', text: (t['text'] as String?) ?? ''))
            .toList()
        : <TranscriptLine>[];

    return PatientHistory(
      id: (c['_id'] as String?) ?? '',
      name: name,
      age: matched != null ? _ageFromDob(matched['dateOfBirth'] as String?) : 0,
      gender: matched != null ? _shortGender(matched['gender'] as String?) : '-',
      // Consultation docs don't carry `mode` — that's on the linked
      // Appointment, which this list endpoint doesn't join in.
      mode: 'Consultation',
      date: _formatShortDate(c['createdAt'] as String?),
      createdAt: DateTime.tryParse((c['createdAt'] as String?) ?? ''),
      diagnosis: diagnosis,
      soap: soapForHistory,
      transcript: transcript,
    );
  }

  Future<void> searchHistory(String query) async {
    isLoadingHistory = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 150));
    if (query.trim().isEmpty) {
      patientHistory = List.from(_allPatientHistory);
    } else {
      final lq = query.toLowerCase();
      patientHistory = _allPatientHistory.where((p) {
        return p.name.toLowerCase().contains(lq) || p.diagnosis.any((d) => d.toLowerCase().contains(lq));
      }).toList();
    }
    _ensureSelectedHistory();
    isLoadingHistory = false;
    notifyListeners();
  }

  void selectHistory(String id) {
    selectedHistoryId = id;
    notifyListeners();
    final matches = patientHistory.where((h) => h.id == id);
    if (matches.isEmpty) return;
    final record = matches.first;
    if (record.rx != null) return;
    unawaited(_hydratePrescriptionForHistory(record));
  }

  /// Prescriptions are fetched lazily, one consultation at a time, only when
  /// the doctor opens that history item — not eagerly for the whole list.
  Future<void> _hydratePrescriptionForHistory(PatientHistory record) async {
    try {
      final list = await Api.prescriptions.getByConsultation(record.id);
      if (list.isEmpty) return;
      final p = list.first;
      final medicinesRaw = p['medicines'];
      final medicines = medicinesRaw is List
          ? medicinesRaw
              .whereType<Map>()
              .map((m) => Medicine(
                    name: (m['name'] as String?) ?? '',
                    dosage: (m['strength'] as String?) ?? '',
                    freq: (m['frequency'] is Map ? (m['frequency']['instructions'] as String?) : null) ?? '',
                    duration: (m['durationDays'] as num?)?.toString() ?? '',
                    dosageForm: (m['dosageForm'] as String?) ?? 'tablet',
                    aiSuggested: m['aiSuggested'] == true,
                  ))
              .toList()
          : <Medicine>[];
      record.rx = Prescription(
        status: (p['status'] as String?) ?? 'draft',
        medicines: medicines,
        pdf: (p['pdfUrl'] as String?)?.isNotEmpty == true,
      );
      notifyListeners();
    } catch (e) {
      logAuditEvent('Could not load prescription for consultation ${record.id}: ${_describeError(e)}');
    }
  }

  // ---- notifications ----

  Future<void> loadNotifications() async {
    // Fetched independently so the unread-count call failing (or vice
    // versa) doesn't discard the notification list that already succeeded.
    try {
      final items = await Api.notifications.list(limit: 30);
      inAppNotifications = items.map((n) {
        final title = (n['title'] as String?) ?? '';
        final body = (n['body'] as String?) ?? '';
        return [title, body].where((s) => s.isNotEmpty).join(' — ');
      }).toList();
      notifyListeners();
    } catch (e) {
      logAuditEvent('Notifications load failed: ${_describeError(e)}');
    }
    try {
      unreadNotificationCount = await Api.notifications.unreadCount();
      notifyListeners();
    } catch (e) {
      logAuditEvent('Unread notification count load failed: ${_describeError(e)}');
    }
  }

  void clearNotifications() {
    inAppNotifications.clear();
    unreadNotificationCount = 0;
    notifyListeners();
    unawaited(Api.notifications.markAllRead().catchError((e) {
      logAuditEvent('Mark-all-read failed: ${_describeError(e)}');
    }));
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    unawaited(_roomListener?.dispose());
    unawaited(_room?.disconnect());
    _consultationSocket?.disconnect();
    unawaited(_fcmTokenRefreshSub?.cancel());
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// ---- backend JSON → UI model mapping helpers ----

/// Best-effort extraction of a numeric "times per day" from a freeform
/// frequency/instructions string (e.g. "Twice daily", "1-0-1", "TDS after
/// meals"). Falls back to 0 (unknown) rather than fabricating a value —
/// callers should treat 0 as "doctor's written instructions are the source
/// of truth" (`instructions` always carries the original text regardless).
int _parseTimesPerDay(String freq) {
  final f = freq.toLowerCase().trim();
  if (f.isEmpty) return 0;

  // "1-0-1" / "1-1-1" style dosing schedules: count non-zero slots.
  final dashParts = f.split(RegExp(r'[-+]')).map((s) => s.trim()).toList();
  if (dashParts.length >= 2 && dashParts.every((p) => RegExp(r'^\d+(\.\d+)?$').hasMatch(p))) {
    final count = dashParts.where((p) => (double.tryParse(p) ?? 0) > 0).length;
    if (count > 0) return count;
  }

  const keywordCounts = {
    'once': 1, 'od ': 1, ' od': 1, 'qd': 1, 'daily': 1,
    'twice': 2, 'bd ': 2, ' bd': 2, 'bid': 2,
    'thrice': 3, 'tds': 3, 'tid': 3, 'three times': 3,
    'four times': 4, 'qid': 4,
  };
  for (final entry in keywordCounts.entries) {
    if (f.contains(entry.key)) return entry.value;
  }
  return 0;
}

String _fullName(Map person) {
  final first = (person['firstName'] as String?) ?? '';
  final last = (person['lastName'] as String?) ?? '';
  return '$first $last'.trim();
}

String _shortGender(String? gender) {
  switch (gender) {
    case 'male':
      return 'M';
    case 'female':
      return 'F';
    default:
      return 'O';
  }
}

int _ageFromDob(String? iso) {
  if (iso == null) return 0;
  final dob = DateTime.tryParse(iso);
  if (dob == null) return 0;
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
  return age < 0 ? 0 : age;
}

const _monthAbbrev = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatShortDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return '${d.day} ${_monthAbbrev[d.month - 1]}';
}

String _formatTime(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${hour12.toString().padLeft(2, '0')}:$minute $period';
}

ConsultStatus _mapAppointmentStatus(String? status) {
  switch (status) {
    case 'confirmed':
      return ConsultStatus.confirmed;
    case 'checked_in':
    case 'waiting':
      return ConsultStatus.waiting;
    case 'in_progress':
      return ConsultStatus.inProgress;
    case 'completed':
      return ConsultStatus.completed;
    case 'no_show':
      return ConsultStatus.noShow;
    case 'cancelled':
      return ConsultStatus.cancelled;
    case 'scheduled':
    case 'rescheduled':
    default:
      return ConsultStatus.scheduled;
  }
}

String _mapMode(String? mode) => mode == 'online' ? 'Video Consultation' : 'Consultation';

QueuePriority _mapPriority(String? urgencyTier) {
  switch (urgencyTier) {
    case 'red':
    case 'emergency':
      return QueuePriority.high;
    case 'yellow':
      return QueuePriority.medium;
    default:
      return QueuePriority.normal;
  }
}

QueuePatient _mapAppointmentToQueuePatient(Map<String, dynamic> json) {
  final rawPatient = json['patientId'];
  final patientMap = rawPatient is Map ? rawPatient : const {};
  final patientRecordId = rawPatient is Map ? rawPatient['_id'] as String? : (rawPatient is String ? rawPatient : null);

  final aiSymptomSummary = json['aiSymptomSummary'];
  final symptoms = aiSymptomSummary is Map ? aiSymptomSummary['symptoms'] : null;
  final chiefComplaint = symptoms is List && symptoms.isNotEmpty ? symptoms.join(', ') : ((json['notes'] as String?) ?? '');
  final urgencyTier = aiSymptomSummary is Map ? aiSymptomSummary['urgencyTier'] as String? : null;

  return QueuePatient(
    id: (json['_id'] as String?) ?? '',
    name: patientMap.isNotEmpty ? _fullName(patientMap) : 'Unknown patient',
    age: patientMap.isNotEmpty ? _ageFromDob(patientMap['dateOfBirth'] as String?) : 0,
    gender: patientMap.isNotEmpty ? _shortGender(patientMap['gender'] as String?) : '-',
    mode: _mapMode(json['mode'] as String?),
    time: _formatTime(json['scheduledAt'] as String?),
    status: _mapAppointmentStatus(json['status'] as String?),
    priority: _mapPriority(urgencyTier),
    chiefComplaint: chiefComplaint,
    // The appointment list endpoint doesn't return allergies/comorbidities/
    // vitals trend (that lives on the full Patient/HealthRecord docs, which
    // would mean an extra call per queue row) — left empty rather than
    // fabricated. The UI already hides these sections when empty/null.
    riskSummary: const RiskSummary(tags: [], allergies: [], comorbidities: [], recentLabAbnormalities: 'None'),
    vitals: const VitalsSeries(bp: [], bpDates: [], hr: [], hrDates: []),
    patientRecordId: patientRecordId,
    consultationId: json['consultationId'] as String?,
  );
}
