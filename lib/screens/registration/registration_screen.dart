import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'doctor_registration_screen.dart';
import 'registration_data.dart';
import 'registration_success_screen.dart';
import 'welcome_screen.dart';

enum _Stage { welcome, wizard, success }

/// Hosts the pre-login flow: Welcome splash -> the 4-step Doctor
/// Registration wizard -> a success summary screen, shown by [RootShell]
/// whenever `AppState.isOnboarded` is false. Uses local state to switch
/// between the three rather than pushing Navigator routes, matching how the
/// old onboarding screen managed its own internal steps.
///
/// `AppState.completeRegistration` (the call that actually flips
/// `isOnboarded` and swaps [RootShell] over to the main app) is deferred
/// until the success screen finishes — so the doctor sees the summary
/// before landing on the dashboard, instead of the app switching out from
/// under the wizard the instant "Submit Application" is tapped.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  _Stage _stage = _Stage.welcome;
  RegistrationData? _submittedData;

  void _finish() {
    final data = _submittedData;
    if (data == null) return;
    context.read<AppState>().completeRegistration(
          firstName: data.firstName,
          middleName: data.middleName,
          lastName: data.lastName,
          dateOfBirth: data.dateOfBirth,
          gender: data.gender,
          contactPhone: data.contactPhone,
          officialEmail: data.officialEmail,
          nmcRegistrationNumber: data.nmcRegistrationNumber,
          experienceYears: data.experienceYears,
          specialties: data.specialties,
          qualifications: data.qualifications,
          languages: data.languages,
          clinicLocation: data.clinicLocation,
          state: data.state,
          city: data.city,
          pincode: data.pincode,
          videoFee: data.videoFee,
          inPersonFee: data.inPersonFee,
          nmcCertificateFile: data.nmcCertificateFile,
          govIdFile: data.govIdFile,
          degreeCertificateFile: data.degreeCertificateFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_stage) {
      _Stage.welcome => WelcomeScreen(
          key: const ValueKey('welcome'),
          onCreateAccount: () => setState(() => _stage = _Stage.wizard),
        ),
      _Stage.wizard => DoctorRegistrationScreen(
          key: const ValueKey('wizard'),
          onBackToWelcome: () => setState(() => _stage = _Stage.welcome),
          onSubmitted: (data) => setState(() {
            _submittedData = data;
            _stage = _Stage.success;
          }),
        ),
      _Stage.success => RegistrationSuccessScreen(
          key: const ValueKey('success'),
          data: _submittedData!,
          onContinue: _finish,
        ),
    };

    return AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: child);
  }
}
