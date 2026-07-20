import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

/// Shown once a doctor application has been submitted (self-apply or
/// hospital-invite) but not yet approved — `AuthStage.pendingReview`.
/// "Check Status" re-resolves the session so an approval that happened while
/// this screen was open takes effect without needing to log out/in again.
class PendingReviewScreen extends StatefulWidget {
  const PendingReviewScreen({super.key});

  @override
  State<PendingReviewScreen> createState() => _PendingReviewScreenState();
}

class _PendingReviewScreenState extends State<PendingReviewScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    await context.read<AppState>().refreshSessionStage();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: AppColors.amber100, shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.amber600, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Application Under Review', textAlign: TextAlign.center, style: AppText.display(size: 19)),
              const SizedBox(height: 8),
              Text(
                "Thanks for applying! Our team is verifying your credentials and documents. You'll be notified once your profile is approved — usually within 24-48 hours.",
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.ink600).copyWith(height: 1.4),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: AppButton(
                  label: _checking ? 'Checking...' : 'Check Status',
                  icon: const Icon(Icons.refresh, size: 16),
                  variant: AppButtonVariant.subtle,
                  block: true,
                  loading: _checking,
                  onPressed: _checking ? null : _checkStatus,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.read<AppState>().logout(),
                child: Text('Log Out', style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
