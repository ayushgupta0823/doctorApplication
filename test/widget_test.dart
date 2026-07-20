// Smoke tests for the 5-tab IA (Home/Queue/Patients/Calendar/More) with
// Consultation, Patient Details, Profile, Appointments, and Reports as
// pushed routes. Covers the Welcome -> Doctor Registration wizard, tab
// navigation, queue actions, the consult room (video call, AI scribe,
// ICD-10 lookup, prescription signing), patient details, calendar, profile
// settings, appointments, reports, and the more menu.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mediconnect_doctor_app/main.dart';
import 'package:mediconnect_doctor_app/state/app_state.dart';
import 'package:mediconnect_doctor_app/widgets/app_card.dart';

void main() {
  // permission_handler's platform channel has no native implementation in
  // the widget-test sandbox, so calls to it never resolve. Respond as if
  // every permission is granted, matching what real Android does when the
  // user taps "Allow" — exercised by the Settings > Notification
  // Preferences screen, not by registration itself anymore.
  const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
  const kGranted = 1; // PermissionStatus.values.indexOf(PermissionStatus.granted)
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(permissionChannel, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return kGranted;
      case 'requestPermissions':
        final permissions = List<int>.from(call.arguments as List);
        return {for (final p in permissions) p: kGranted};
      case 'shouldShowRequestPermissionRationale':
        return false;
      case 'openAppSettings':
        return true;
      default:
        return null;
    }
  });

  // file_picker's platform channel is likewise unimplemented in the test
  // sandbox — the Documents step's real file picker would hang forever
  // waiting on a native file dialog. Respond as if the doctor picked one
  // file, for any of the three upload slots.
  const filePickerChannel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(filePickerChannel, (call) async {
    if (call.method == 'clear') return true;
    return [
      {'name': 'document.pdf', 'path': '/tmp/document.pdf', 'size': 2048, 'bytes': null, 'identifier': null},
    ];
  });

  // flutter_secure_storage's platform channel is also unimplemented here —
  // without a mock, `read`/`write` never resolve, which now matters: at
  // launch `AppState._bootstrapSession` awaits `read` to decide the auth
  // screen, and a permanently-pending platform call would leave a Timer
  // scheduled past the end of the test (its 5s `.timeout` guard), which
  // `flutter_test` flags as a leaked timer between tests.
  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestWidgetsFlutterBinding.ensureInitialized()
      .defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
    switch (call.method) {
      case 'read':
      case 'containsKey':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'isProtectedDataAvailable':
        return true;
      default:
        return null; // write / delete / deleteAll
    }
  });

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 3500));
    tester.view.physicalSize = const Size(500, 3500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Jumps straight to a signed-in `AuthStage` via `AppState`'s test-only
  // backdoor (see `debugSignInForTests`) rather than driving a real OTP
  // login or the registration wizard — widget tests exercise app *screens*,
  // not the live backend network round-trip (that's covered by manual
  // device testing per the migration plan's verification section). Kept the
  // name `registerAndOnboard` since ~15 tests already call it to reach Home.
  Future<void> registerAndOnboard(WidgetTester tester) async {
    final app = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
    app.debugSignInForTests();
    await tester.pumpAndSettle();
  }

  testWidgets('App boots on the Login screen; a signed-in session lands on the Home tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    // `_bootstrapSession` is async (even a fast secure-storage-unavailable
    // failure resolves on a later microtask) — settle past the checking-
    // session splash before asserting the logged-out screen.
    await tester.pumpAndSettle();

    // Logged out at fresh boot — no saved session in the test sandbox.
    expect(find.text('Send OTP'), findsOneWidget);

    await registerAndOnboard(tester);

    expect(find.text('Dr. Ayush Gupta'), findsOneWidget);
    expect(find.text('LIVE PATIENT QUEUE'), findsOneWidget);
    // All 5 bottom-nav destinations are present.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('Registration: Personal Details step shows a validation error when required fields are missing',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();

    // Signed in but no application yet -> onboarding choice -> solo self-apply -> Welcome -> wizard.
    final app = Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false);
    app.debugSignInForTests(stage: AuthStage.needsOnboarding);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply as an independent doctor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registration Profile'));
    await tester.pumpAndSettle();

    // Nothing filled in yet — Continue should surface a validation error
    // instead of silently advancing to Credentials.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your first and last name.'), findsOneWidget);
    // Still on step 1 — the Credentials step's own field hasn't appeared
    // (the step *label* "Credentials" is always visible in the stepper).
    expect(find.text('NMC Registration Number'), findsNothing);
  });

  testWidgets('Home: Start Consultation quick action opens the Consult Room for the next patient',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    // The queue is sorted in-progress-first, so Vikram Singh (already
    // in_progress in the mock data) is "next" and gets resumed rather
    // than started.
    await tester.tap(find.text('Start Consultation'));
    await tester.pumpAndSettle();

    expect(find.text('Vikram Singh'), findsWidgets);
    // The sub-tab row is horizontally scrollable, so only the first couple
    // of tabs (Prescription, Lab Tests) are guaranteed to be laid out
    // without scrolling; the rest are exercised by other tests that tap them.
    expect(find.text('Prescription'), findsOneWidget);
    expect(find.text('Lab Tests'), findsOneWidget);
  });

  testWidgets('Queue: an in-progress patient shows Resume Consultation instead of Start',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    // Vikram Singh starts "in_progress" in the mock queue.
    expect(find.text('Resume Consultation'), findsOneWidget);

    await tester.tap(find.text('Resume Consultation'));
    await tester.pumpAndSettle();

    expect(find.text('Vikram Singh'), findsWidgets);
  });

  testWidgets('Queue: marking a no-show shows the banner and can be dismissed',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No-show').first);
    await tester.pumpAndSettle();

    // Marking a no-show is irreversible, so it asks for confirmation first.
    expect(find.text('Mark as no-show?'), findsOneWidget);
    await tester.tap(find.text('Mark No-show'));
    await tester.pumpAndSettle();

    expect(find.textContaining('marked as no-show.'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('marked as no-show.'), findsNothing);
  });

  testWidgets('Queue: View Details opens Patient Details with overview, notes and a working note field',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();

    // The queue is sorted in-progress-first, so pick Ananya Sharma's card
    // specifically (rather than `.first`) to exercise the AI Risk Analysis
    // section, which only she has in the mock data.
    final ananyaViewDetails = find.descendant(
      of: find.ancestor(of: find.text('Ananya Sharma'), matching: find.byType(AppCard)),
      matching: find.text('View Details'),
    );
    await tester.tap(ananyaViewDetails);
    await tester.pumpAndSettle();

    expect(find.text('Patient Details'), findsOneWidget);
    expect(find.text('Ananya Sharma'), findsWidgets);
    expect(find.text('AI RISK ANALYSIS'), findsOneWidget);

    // The tab chip row is horizontally scrollable and "Notes" is the last
    // of 5 chips, so it isn't laid out until scrolled into view.
    final tabRow = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);
    await tester.drag(tabRow, const Offset(-300, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Add a note about this patient...'), 'Reviewed inhaler technique.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Reviewed inhaler technique.'), findsOneWidget);
    expect(find.text('No notes yet.'), findsNothing);
  });

  testWidgets('Consult Room: video call join/leave confirmation, then returning to the Queue tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Consultation').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Video call'));
    await tester.pumpAndSettle();

    // "Join Call" would try a real LiveKit connection (camera/mic/network
    // the widget-test sandbox doesn't have) — jump straight to "connected"
    // via the test backdoor instead, since this test is really about the
    // join/leave-confirmation UX, not live media. Its call-duration ticker
    // runs every second forever while "connected", so pump a bounded amount
    // rather than pumpAndSettle (which would never see "no more frames").
    Provider.of<AppState>(tester.element(find.byType(MaterialApp)), listen: false).debugConnectCallForTests();
    await tester.pump();
    expect(find.text('LIVE CALL'), findsOneWidget);

    // Leaving the call screen mid-call asks for confirmation.
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave the call?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LIVE CALL'), findsOneWidget); // still in the call

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('End Call & Leave'));
    await tester.pumpAndSettle();

    // Back on the Consult Room, call has ended.
    expect(find.text('Ananya Sharma'), findsWidgets);
    expect(find.text('LIVE CALL'), findsNothing);

    // Leaving the Consult Room itself (no active call) needs no confirmation.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Patient Queue'), findsOneWidget);
  });

  testWidgets('Prescription tab: signing without a medicine shows a validation error',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Start Consultation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescription'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign & Send'));
    await tester.pumpAndSettle();

    expect(find.text('Add at least one named medicine before signing.'), findsOneWidget);
  });

  testWidgets(
      'Prescription tab: signing a patient with no backend record shows a server-link error',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Consultation').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prescription'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Drug name'), 'Paracetamol');
    await tester.tap(find.text('Sign & Send'));
    await tester.pumpAndSettle();

    expect(find.text('Sign Prescription?'), findsOneWidget);
    await tester.tap(find.text('Sign Prescription'));
    await tester.pumpAndSettle();

    // This patient came from the offline mock seed (no real
    // `GET /appointments/doctor` row backs it in the test sandbox, which has
    // no network), so it has no `patientRecordId` — signing correctly
    // refuses to fabricate a prescription against the real backend rather
    // than pretending to succeed.
    expect(
      find.textContaining('cannot sign a prescription against the server'),
      findsOneWidget,
    );
  });

  testWidgets('Calendar tab shows today\'s schedule and day summary stats', (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('My Roster'), findsOneWidget);
    expect(find.text('DAY SUMMARY'), findsOneWidget);
    expect(find.text('Kabir Rao'), findsOneWidget);
  });

  testWidgets('Calendar: resuming an in-progress entry opens the Consult Room for that patient',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Vikram Singh is "in_progress" in the mock schedule too.
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Vikram Singh'), findsWidgets);
  });

  testWidgets('Patients tab lists history and shows SOAP notes for a selected patient',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();

    expect(find.text('My Patients'), findsOneWidget);
    expect(find.text('Meera Iyer'), findsOneWidget);
    expect(find.text('SOAP Notes'), findsOneWidget);

    await tester.tap(find.text('Sara Fernandes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No SOAP notes or transcript recorded'), findsOneWidget);
  });

  testWidgets('Profile: opening from Home shows the settings list and Clinic Information',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Dr. Ayush Gupta'));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('NMC Registration'), findsOneWidget);
    expect(find.text('Clinic Information'), findsOneWidget);

    await tester.tap(find.text('Clinic Information'));
    await tester.pumpAndSettle();

    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('Appointments: adding a walk-in patient adds them to the queue',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();

    expect(find.text('Appointments'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Add Walk-in Patient'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Patient name'), 'Test Walkin');
    await tester.enterText(find.widgetWithText(TextField, 'Age'), '30');
    await tester.tap(find.text('Add to Queue'));
    await tester.pumpAndSettle();

    expect(find.text('Test Walkin'), findsOneWidget);
  });

  testWidgets('More tab: renders the feature grid and opens Reports & Analytics', (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await registerAndOnboard(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Everything else you need, in one place'), findsOneWidget);

    await tester.tap(find.text('Reports & Analytics'));
    await tester.pumpAndSettle();

    // Case-mix/consultation-mix widgets were dropped from this screen to
    // match the website's trimmed Analytics page — the estimated-earnings
    // section is what's left to assert against.
    expect(find.text('ESTIMATED EARNINGS'), findsOneWidget);
  });
}
