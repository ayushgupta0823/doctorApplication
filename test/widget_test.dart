// Smoke tests for the 5-tab IA (Home/Queue/Patients/Calendar/More) with
// Consultation, Patient Details, Profile, Appointments, and Reports as
// pushed routes. Covers onboarding, tab navigation, queue actions, the
// consult room (video call, AI scribe, ICD-10 lookup, prescription
// signing), patient details, calendar, profile settings, appointments,
// reports, and the more menu.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mediconnect_doctor_app/main.dart';
import 'package:mediconnect_doctor_app/widgets/app_card.dart';

void main() {
  // permission_handler's platform channel has no native implementation in
  // the widget-test sandbox, so calls to it never resolve. Left unmocked,
  // the onboarding screen's "Grant" buttons stay stuck in their loading
  // state (an indeterminate CircularProgressIndicator that animates
  // forever), which makes every pumpAndSettle() after that point time out.
  // Respond as if every permission is granted, matching what real Android
  // does when the user taps "Allow".
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

  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 3500));
    tester.view.physicalSize = const Size(500, 3500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  // Helper to bypass Login and Onboarding and land on the Home tab.
  Future<void> loginAndOnboard(WidgetTester tester) async {
    // 1. Enter email/phone
    await tester.enterText(find.byType(TextField).first, 'doctor@mediconnect.ai');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    // 2. OTP: there's no real SMS/email gateway behind this demo, so the
    // 4 boxes auto-fill with the mock code as soon as this screen appears
    // — no manual entry needed.
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    // 3. NMC Verification
    await tester.enterText(find.byType(TextField).first, 'NMC-2016-MH-08421');
    await tester.tap(find.text('Verify NMC'));
    await tester.pumpAndSettle();

    // 4. Digital Signature Setup
    await tester.enterText(find.byType(TextField).first, 'Dr. Rhea Kulkarni');
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();

    // 5. Grant Permissions (Notifications and Camera/Mic)
    await tester.tap(find.text('Grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grant').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Complete Onboarding'));
    await tester.pumpAndSettle();

    // Home is a permanent bottom-nav tab now, not a one-time landing
    // screen — onboarding completing lands directly on it.
  }

  testWidgets('App boots on login, completes onboarding, and lands on the Home tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();

    expect(find.text('Welcome Back, Doctor 👋'), findsOneWidget);
    expect(find.text('Mobile Number or Email'), findsOneWidget);

    await loginAndOnboard(tester);

    expect(find.text('Dr. Rhea Kulkarni'), findsOneWidget);
    expect(find.text('LIVE PATIENT QUEUE'), findsOneWidget);
    // All 5 bottom-nav destinations are present.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Patients'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('Login: OTP boxes auto-fill with the demo code so signing in never gets stuck',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'doctor@mediconnect.ai');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter OTP'), findsOneWidget);
    final otpFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(otpFields, hasLength(4));
    for (final field in otpFields) {
      expect(field.controller!.text, isNotEmpty);
    }

    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Medical Council Verification'), findsOneWidget);
  });

  testWidgets('Home: Start Consultation quick action opens the Consult Room for the next patient',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await loginAndOnboard(tester);

    // The queue is sorted in-progress-first, so Vikram Singh (already
    // in_progress in the mock data) is "next" and gets resumed rather
    // than started.
    await tester.tap(find.text('Start Consultation'));
    await tester.pumpAndSettle();

    expect(find.text('Vikram Singh'), findsWidgets);
    // The sub-tab row is horizontally scrollable, so only the first couple
    // of tabs (Notes, Prescription) are guaranteed to be laid out without
    // scrolling; the rest are exercised by other tests that tap them.
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Prescription'), findsOneWidget);
  });

  testWidgets('Queue: an in-progress patient shows Resume Consultation instead of Start',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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

  testWidgets('Consult Room: generate AI SOAP summary and search ICD-10 on the Notes tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await loginAndOnboard(tester);

    await tester.tap(find.text('Start Consultation'));
    await tester.pumpAndSettle();

    // Notes is the default sub-tab, showing the AI SOAP Scribe panel.
    await tester.tap(find.text('Generate SOAP'));
    await tester.pump(); // starts the 2200ms simulated request
    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('Re-generate'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Search condition or code…'), 'migraine');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 310)); // debouncing
    expect(find.textContaining('Migraine, unspecified'), findsOneWidget);
  });

  testWidgets('Consult Room: video call join/leave confirmation, then returning to the Queue tab',
      (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

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
    await loginAndOnboard(tester);

    await tester.tap(find.text('Dr. Rhea Kulkarni'));
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
    await loginAndOnboard(tester);

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

  testWidgets('More tab: renders the feature grid and toggles dark mode', (WidgetTester tester) async {
    await useTallSurface(tester);
    await tester.pumpWidget(const MediConnectDoctorApp());
    await tester.pump();
    await loginAndOnboard(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Everything else you need, in one place'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final toggled = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggled.value, isTrue);

    await tester.tap(find.text('Reports & Analytics'));
    await tester.pumpAndSettle();

    expect(find.text('TOP CONDITIONS'), findsOneWidget);
  });
}
