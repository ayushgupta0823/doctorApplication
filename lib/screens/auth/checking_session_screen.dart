import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';

/// Brief splash while [AppState] restores a saved session at launch
/// (`AuthStage.checkingSession`).
class CheckingSessionScreen extends StatelessWidget {
  const CheckingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(size: AppLogoSize.large),
            const SizedBox(height: 20),
            const CircularProgressIndicator(strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}
