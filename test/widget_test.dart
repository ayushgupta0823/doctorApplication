// Smoke tests for the 5-tab IA (Home/Queue/Patients/Calendar/More) with
// Consultation, Patient Details, Profile, Appointments, and Reports as
// pushed routes. Covers the Welcome -> Doctor Registration wizard, tab
// navigation, queue actions, the consult room (video call, AI scribe,
// ICD-10 lookup, prescription signing), patient details, calendar, profile
// settings, appointments, reports, and the more menu.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediconnect_doctor_app/main.dart';
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

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 3500));
    tester.view.physicalSize = const Size(500, 3500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Helper to drive Welcome -> the 4-step Doctor Registration wizard and
  // land on the Home tab. Every text field is addressed by its position in
  // the widget tree (documented inline) since several steps reuse hint
  // text/labels across fields.
  Future<void> registerAndOnboard(WidgetTester tester) async {
    // Welcome screen.
    await tester.tap(find.text('Registration Profile'));
    await tester.pumpAndSettle();

    // ---- Step 1: Personal Details ----
    // TextField order: First Name(0), Middle Name(1), Last Name(2),
    // Contact Phone(3), Official Email(4), Password(5), Confirm Password(6).
    await tester.enterText(find.byType(TextField).at(0), 'Ayush');
    await tester.enterText(find.byType(TextField).at(2), 'Gupta');

    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Gender is the only dropdown on this step.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Male').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(3), '9876543210');
    await tester.enterText(find.byType(TextField).at(4), 'ayush@clinic.com');
    await tester.enterText(find.byType(TextField).at(5), 'secret123');
    await tester.enterText(find.byType(TextField).at(6), 'secret123');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ---- Step 2: Credentials ----
    // TextField order: NMC Number(0), Experience(1), specialty search(2),
    // Languages(3).
    await tester.enterText(find.byType(TextField).at(0), 'NMC-2016-MH-08421');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.tap(find.text('Cardiology'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), 'English, Hindi');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ---- Step 3: Practice Details ----
    // TextField order: Clinic Location(0), Pincode(1), Video Fee(2),
    // In-person Fee(3) — the fee fields default to "500" so they're left as-is.
    await tester.enterText(find.byType(TextField).at(0), 'Sunrise Clinic, MG Road');

    // State and City are the only two dropdowns on this step (State first).
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maharashtra').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mumbai').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '400069');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ---- Step 4: Documents ----
    // Only the first (required NMC/State Council Certificate) upload is
    // needed to unlock Submit Application.
    await tester.tap(find.text('Click to upload').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Application'));
    // Not pumpAndSettle here: the success screen below runs a
    // Timer.periodic for its auto-continue countdown, which never
    // "settles" on its own. Pump just enough real time for the wizard's
    // own 400ms submit delay and the stage cross-fade to resolve instead.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Registration Submitted!'), findsOneWidget);
    await tester.tap(find.textContaining('Continue to Dashboard'));
    await tester.pumpAndSettle();

    // Home is a permanent bottom-nav tab now, not a one-time landing
    // screen — continuing from the success summary lands directly on it.
  }

  testWidgets('App boots on the Welcome screen, completes registration, and lands on the Home tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Registration Profile'), findsOneWidget);

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

    await tester.tap(find.text('Join Call'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100)); // wait for token
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

    expect(find.text('TOP CONDITIONS'), findsOneWidget);
  });
}
