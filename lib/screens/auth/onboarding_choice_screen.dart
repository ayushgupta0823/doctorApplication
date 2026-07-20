import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../registration/registration_screen.dart';
import 'invite_entry_screen.dart';

/// Shown right after a successful OTP login for an account with no doctor
/// application yet (`AuthStage.needsOnboarding`) — mirrors the website's two
/// separate onboarding paths (`/register/doctor` self-apply vs
/// `/invite/accept` hospital invite).
class OnboardingChoiceScreen extends StatelessWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        title: Text('Set Up Your Doctor Profile', style: AppText.display(size: 16)),
        actions: [
          TextButton(
            onPressed: () => context.read<AppState>().logout(),
            child: Text('Log Out', style: AppText.body(size: 12.5, weight: FontWeight.w600, color: AppColors.ink600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "You're logged in — now let's get your doctor profile set up so patients can find and book you.",
                style: AppText.body(size: 13, color: AppColors.ink600).copyWith(height: 1.4),
              ),
              const SizedBox(height: 20),
              _ChoiceCard(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Apply as an independent doctor',
                subtitle: 'Solo practice — submit your credentials for platform verification.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen())),
              ),
              const SizedBox(height: 14),
              _ChoiceCard(
                icon: Icons.local_hospital_outlined,
                title: 'I have an invite from a hospital',
                subtitle: "A hospital admin invited you — enter your invite link or code to continue.",
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteEntryScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.blue700, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.display(size: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppText.body(size: 11.5, color: AppColors.ink600).copyWith(height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}
