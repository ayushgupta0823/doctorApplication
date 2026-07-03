import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../data/api/api.dart';
import '../data/mock_data.dart';
import '../models/models.dart';

enum RootTab { home, queue, patients, calendar, more }

enum ConsultSubTab { notes, prescription, labTests, reports, history }

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
    hydrateSettingsCache();
    // Fire-and-forget: replace the mock seed above with real data. If these
    // fail (no dev auth token configured, network down), the mock/cached
    // data above stays on screen rather than leaving a blank UI — see
    // `_describeError`.
    unawaited(loadDoctorProfile());
    unawaited(refreshQueue());
    unawaited(loadPatientHistory());
    unawaited(loadNotifications());
  }

  // ---- connectivity & offline cache ----
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool isOffline = false;

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

  // ---- authentication & onboarding (still mocked — see ApiConfig) ----
  bool isLoggedIn = false;
  bool isOnboarded = false;
  String phoneOrEmail = '';
  String otpCode = '';
  String nmcNumber = '';
  bool isNmcVerified = false;
  String digitalSignature = '';
  bool notificationsGranted = false;
  bool cameraMicGranted = false;
  bool isOnline = true;
  bool isAppLocked = false;

  // ---- real doctor profile (GET /doctors/me/profile) ----
  Map<String, dynamic>? doctorProfile;

  String get doctorDisplayName {
    final p = doctorProfile;
    if (p == null) return 'Dr. Rhea Kulkarni'; // placeholder until the profile loads
    final name = _fullName(p);
    return name.isEmpty ? 'Doctor' : 'Dr. $name';
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

  // ---- navigation ----
  RootTab tab = RootTab.home;
  ConsultSubTab consultSubTab = ConsultSubTab.notes;

  // ---- queue ----
  late List<QueuePatient> queue;
  NoShowAlert? noShowAlert;
  String? activePatientId;
  bool isLoadingQueue = false;
  DateTime lastUpdatedQueue = DateTime.now();

  // ---- WebRTC call simulation ----
  // NOTE: video calling stays simulated in this pass — wiring real LiveKit
  // media requires the `livekit_client` package, device permission flows,
  // and track rendering, which is a separate substantial effort from the
  // REST data wiring done here. `POST /consultations/:id/video/token` is not
  // called yet.
  String rtcState = 'disconnected'; // disconnected, connecting, connected, reconnecting, failed
  int callSeconds = 0;
  Timer? _callTimer;
  Timer? _transcriptTimer;
  bool audioMuted = false;
  bool videoMuted = false;
  bool screenSharing = false;
  bool simulatePoorNetworkMode = false;

  // ---- AI scribe ----
  bool aiGenerating = false;
  bool aiGenerated = false;
  SoapNote soap = SoapNote();
  String aiSummary = '';
  String? aiError;
  String icdQuery = '';
  IcdCode? selectedIcd;
  List<TranscriptLine> activeTranscript = [];
  bool aiPrescriptionLoading = false;

  // ---- prescription ----
  List<Medicine> rxMedicines = [Medicine()];
  String rxNotes = '';
  String followUp = '7 Days';
  String referral = 'None';
  bool prescriptionSending = false;
  bool prescriptionSent = false;
  String rxError = '';
  int signingStep = 0; // 0: none, 1: POST draft, 2: Approve PDF, 3: Complete Appt
  String signedPdfUrl = '';

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

  /// Turns a caught error into a short, user-facing string. Special-cases
  /// 401/403 with no dev token configured, since that's the single most
  /// likely cause of every real call failing right now (see `ApiConfig`).
  String _describeError(Object e) {
    if (e is ApiException) {
      if (e.isUnauthorized && !ApiConfig.hasDevToken) {
        return 'No dev auth token configured — see ApiConfig / AGENTS.md.';
      }
      if (e.isUnauthorized) {
        return 'Session expired — the dev token needs refreshing.';
      }
      return e.message;
    }
    return e.toString();
  }

  void _pushNotification(String text) {
    inAppNotifications.insert(0, text);
    notifyListeners();
  }

  // ---- authentication actions (mocked — see ApiConfig doc comment) ----
  void sendOtp(String input) {
    phoneOrEmail = input;
    otpCode = '1234'; // Simulated OTP
    logAuditEvent('OTP sent to $input');
    notifyListeners();
  }

  bool verifyOtp(String enteredOtp) {
    if (enteredOtp == otpCode || enteredOtp == '1234') {
      isLoggedIn = true;
      logAuditEvent('User logged in via OTP');
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> verifyNmc(String number) async {
    nmcNumber = number;
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 600));
    isNmcVerified = true;
    logAuditEvent('NMC $number verified');
    notifyListeners();
  }

  void saveSignature(String sig) {
    digitalSignature = sig;
    logAuditEvent('Digital signature configured: $sig');
    notifyListeners();
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

  void completeOnboarding() {
    isOnboarded = true;
    logAuditEvent('Onboarding completed');
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

  void logout() {
    isLoggedIn = false;
    isOnboarded = false;
    phoneOrEmail = '';
    otpCode = '';
    nmcNumber = '';
    isNmcVerified = false;
    digitalSignature = '';
    notificationsGranted = false;
    cameraMicGranted = false;
    isAppLocked = false;
    _resetConsultDraft();
    logAuditEvent('User logged out');
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

  /// `GET /appointments/doctor` → today's queue. Local walk-ins (added via
  /// [addWalkInPatient], which have no backend appointment) survive a
  /// refresh; everything else is replaced wholesale by the server's view.
  Future<void> refreshQueue() async {
    isLoadingQueue = true;
    notifyListeners();
    try {
      final raw = await Api.appointments.listForDoctor();
      final mapped = raw.map(_mapAppointmentToQueuePatient).toList();
      final walkIns = queue.where((p) => p.isWalkIn).toList();
      queue = [...mapped, ...walkIns];
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

    unawaited(Api.appointments.confirm(id).catchError((e) {
      logAuditEvent('Confirm failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync confirmation with the server — ${_describeError(e)}');
      return <String, dynamic>{};
    }));
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
    consultSubTab = ConsultSubTab.notes;
    logAuditEvent('Consultation started for patient $id');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());

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
      }
    }());
  }

  void resumeConsult(String id) {
    activePatientId = id;
    logAuditEvent('Consultation resumed for patient $id');
    notifyListeners();
    final consultationId = _findQueue(id)?.consultationId;
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
        aiGenerated = soap.hasContent;
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
  /// to marking the linked consultation complete server-side too.
  Future<void> completeConsultation() async {
    if (rtcState != 'disconnected') endCall();
    final id = activePatientId;
    final p = id == null ? null : _findQueue(id);
    if (p == null || id == null) return;
    final consultationId = p.consultationId;
    p.status = ConsultStatus.completed;
    logAuditEvent('Consultation completed for patient $id');
    sortQueue();
    notifyListeners();
    unawaited(_persistQueueSnapshot());

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
    } catch (e) {
      logAuditEvent('Complete failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync completion with the server — ${_describeError(e)}');
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

    unawaited(Api.appointments.markNoShow(id).catchError((e) {
      logAuditEvent('No-show failed to sync: ${_describeError(e)}');
      _pushNotification('Could not sync no-show with the server — ${_describeError(e)}');
    }));
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

  QueuePatient? findQueueByName(String name) {
    for (final p in queue) {
      if (p.name == name) return p;
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
  bool isDarkMode = false;
  String selectedLanguage = 'English';

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', value);
    } catch (_) {}
  }

  void setLanguage(String value) {
    selectedLanguage = value;
    notifyListeners();
  }

  Future<void> hydrateSettingsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool('dark_mode') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  void _resetConsultDraft() {
    rtcState = 'disconnected';
    callSeconds = 0;
    _callTimer?.cancel();
    _callTimer = null;
    _transcriptTimer?.cancel();
    _transcriptTimer = null;
    audioMuted = false;
    videoMuted = false;
    screenSharing = false;
    aiGenerating = false;
    aiGenerated = false;
    aiError = null;
    aiPrescriptionLoading = false;
    soap = SoapNote();
    aiSummary = '';
    icdQuery = '';
    selectedIcd = null;
    rxMedicines = [Medicine()];
    rxNotes = '';
    followUp = '7 Days';
    referral = 'None';
    prescriptionSending = false;
    prescriptionSent = false;
    rxError = '';
    signingStep = 0;
    activeTranscript = [];
  }

  // ---- WebRTC call simulation actions ----
  void beginCall() {
    rtcState = 'connecting';
    notifyListeners();

    Timer(const Duration(milliseconds: 1000), () {
      rtcState = 'connected';
      callSeconds = 0;
      logAuditEvent('WebRTC connection established');

      _callTimer?.cancel();
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        callSeconds++;
        notifyListeners();
      });

      // Start streaming dialogue transcript
      _startTranscriptStreaming();
      notifyListeners();
    });
  }

  void triggerPoorNetwork() {
    if (rtcState == 'connected') {
      rtcState = 'reconnecting';
      logAuditEvent('WebRTC connection dropped: reconnecting...');
      notifyListeners();

      Timer(const Duration(seconds: 3), () {
        if (rtcState == 'reconnecting') {
          rtcState = 'connected';
          logAuditEvent('WebRTC connection recovered');
          notifyListeners();
        }
      });
    }
  }

  void endCall() {
    rtcState = 'disconnected';
    _callTimer?.cancel();
    _callTimer = null;
    _transcriptTimer?.cancel();
    _transcriptTimer = null;
    logAuditEvent('WebRTC call ended');
    notifyListeners();
  }

  void toggleMic() {
    audioMuted = !audioMuted;
    logAuditEvent('Microphone toggled to: ${audioMuted ? "Muted" : "Active"}');
    notifyListeners();
  }

  void toggleCam() {
    videoMuted = !videoMuted;
    logAuditEvent('Camera toggled to: ${videoMuted ? "Off" : "On"}');
    notifyListeners();
  }

  void toggleShare() {
    screenSharing = !screenSharing;
    logAuditEvent('Screen share toggled to: $screenSharing');
    notifyListeners();
  }

  // ---- AI transcript streaming (still simulated — see WebRTC note above) ----
  void _startTranscriptStreaming() {
    int index = 0;
    _transcriptTimer?.cancel();
    _transcriptTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (index < MockData.transcriptSeed.length) {
        activeTranscript.add(MockData.transcriptSeed[index]);
        index++;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  // ---- AI summary & SOAP note ----
  /// `POST /ai/summarize` (AI medical scribe). Feeds it the live transcript
  /// if there is one, else the patient's chief complaint, and maps the
  /// response's `{main_concerns, doctor_notes, follow_up}` onto
  /// Subjective/Assessment/Plan — the AI service doesn't produce an
  /// Objective/exam finding, so that field is left for the doctor.
  void generateSummary() {
    aiGenerating = true;
    aiError = null;
    notifyListeners();
    unawaited(_runGenerateSummary());
  }

  Future<void> _runGenerateSummary() async {
    final transcriptText = activeTranscript.map((t) => '${t.speaker}: ${t.text}').join('\n');
    final notes = transcriptText.isNotEmpty ? transcriptText : (activePatient?.chiefComplaint ?? '');
    try {
      final result = await Api.ai.summarize(notes.isEmpty ? 'No clinical notes recorded yet.' : notes);
      soap = SoapNote(
        subjective: (result['main_concerns'] as String?) ?? '',
        objective: '',
        assessment: (result['doctor_notes'] as String?) ?? '',
        plan: (result['follow_up'] as String?) ?? '',
        subjectiveSource: 'ai',
        objectiveSource: 'doctor',
        assessmentSource: 'ai',
        planSource: 'ai',
      );
      aiSummary = (result['main_concerns'] as String?) ?? '';
      aiGenerated = true;
      logAuditEvent('AI Summary and SOAP notes generated');
    } catch (e) {
      aiError = _describeError(e);
      aiSummary = '';
      aiGenerated = true;
      logAuditEvent('AI Summary generation failed: $aiError');
    } finally {
      aiGenerating = false;
      notifyListeners();
    }
  }

  void updateSoapSubjective(String text) {
    soap.subjective = text;
    soap.subjectiveSource = 'doctor';
    notifyListeners();
  }

  void updateSoapObjective(String text) {
    soap.objective = text;
    soap.objectiveSource = 'doctor';
    notifyListeners();
  }

  void updateSoapAssessment(String text) {
    soap.assessment = text;
    soap.assessmentSource = 'doctor';
    notifyListeners();
  }

  void updateSoapPlan(String text) {
    soap.plan = text;
    soap.planSource = 'doctor';
    notifyListeners();
  }

  void setIcdQuery(String v) {
    icdQuery = v;
    notifyListeners();
  }

  /// Selecting an ICD-10 code both updates local state and — if a
  /// consultation is already underway — appends it as a diagnosis entry via
  /// `PUT /consultations/:id/diagnosis` (fire-and-forget; a failure here
  /// just logs, it doesn't block the doctor from continuing the consult).
  void pickIcd(String code) {
    IcdCode? match;
    for (final c in MockData.icdDb) {
      if (c.code == code) {
        match = c;
        break;
      }
    }
    if (match == null) return;
    selectedIcd = match;
    icdQuery = '';
    logAuditEvent('ICD-10 code selected: $code');
    notifyListeners();

    final consultationId = activePatient?.consultationId;
    if (consultationId != null) {
      final icd = match;
      unawaited(
        Api.consultations.addDiagnosis(consultationId, icdCode: icd.code, description: icd.desc).catchError((e) {
          logAuditEvent('Could not save diagnosis to server: ${_describeError(e)}');
          return <Map<String, dynamic>>[];
        }),
      );
    }
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

    rxError = '';
    prescriptionSending = true;
    signingStep = 1; // POST draft
    logAuditEvent('Beginning prescription sign flow');
    notifyListeners();

    try {
      final created = await Api.prescriptions.create({
        'patientId': patientRecordId,
        if (patient.consultationId != null) 'consultationId': patient.consultationId,
        'diagnosis': [if (selectedIcd != null) selectedIcd!.desc],
        'notes': rxNotes,
        'medicines': rxMedicines.where((m) => m.name.trim().isNotEmpty).map((m) {
          return {
            'name': m.name,
            'strength': m.dosage,
            'dosageForm': 'tablet',
            'frequency': {'timesPerDay': 0, 'times': <String>[], 'instructions': m.freq},
            'durationDays': int.tryParse(m.duration.trim()) ?? 0,
            'aiSuggested': m.aiSuggested,
          };
        }).toList(),
      });
      final prescriptionId = created['_id'] as String?;
      if (prescriptionId == null) {
        throw ApiException(message: 'Server did not return a prescription id.');
      }

      // Step 2: Approve & generate PDF
      signingStep = 2;
      notifyListeners();
      final pdfUrl = await Api.prescriptions.approve(prescriptionId);
      signedPdfUrl = pdfUrl ?? '';

      // Step 3: Complete the consultation (pushes SOAP + marks the
      // appointment — and its linked consultation — completed server-side).
      signingStep = 3;
      notifyListeners();
      await completeConsultation();

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
      logAuditEvent('Prescription signed & consultation finalised');
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
    rxMedicines = [Medicine()];
    notifyListeners();
  }

  // ---- patient history (Patients tab) ----

  /// Joins `GET /consultations/doctor` (no populated patient info) against
  /// `GET /doctors/me/patients` (full patient docs) for display names.
  Future<void> loadPatientHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      final patients = await Api.doctors.getMyPatients();
      _patientsById = {
        for (final p in patients)
          if (p['_id'] is String) p['_id'] as String: p,
      };
      final consultations = await Api.consultations.listMine();
      _allPatientHistory = consultations.map(_mapConsultationToHistory).toList();
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
    try {
      final items = await Api.notifications.list(limit: 30);
      unreadNotificationCount = await Api.notifications.unreadCount();
      inAppNotifications = items.map((n) {
        final title = (n['title'] as String?) ?? '';
        final body = (n['body'] as String?) ?? '';
        return [title, body].where((s) => s.isNotEmpty).join(' — ');
      }).toList();
      notifyListeners();
    } catch (e) {
      logAuditEvent('Notifications load failed: ${_describeError(e)}');
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
    _transcriptTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}

// ---- backend JSON → UI model mapping helpers ----

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
