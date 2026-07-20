import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'doctor_registration_screen.dart';
import 'registration_data.dart';
import 'registration_success_screen.dart';
import 'welcome_screen.dart';

enum _Stage { welcome, wizard, success }

/// Hosts the solo self-apply flow: Welcome splash -> the 4-step Doctor
/// Registration wizard -> a success summary screen, shown by [RootShell]
/// whenever `AppState.authStage` is `AuthStage.needsOnboarding`. Uses local
/// state to switch between the three rather than pushing Navigator routes,
/// matching how the old onboarding screen managed its own internal steps.
///
/// The wizard's own "Submit Application" step already calls the real
/// `POST /doctors/apply` (via `AppState.submitDoctorApplication`) before
/// handing off to the success screen here — `_finish` just acknowledges that
/// and moves `authStage` to `pendingReview`, deferred until the success
/// screen finishes so the doctor sees the summary before the app navigates
/// away, instead of switching out from under the wizard.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  _Stage _stage = _Stage.welcome;
  RegistrationData? _submittedData;

  void _finish() {
    if (_submittedData == null) return;
    context.read<AppState>().acknowledgeApplicationSubmitted();
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
