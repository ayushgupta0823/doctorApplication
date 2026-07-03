import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/step_progress_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;
  final _nmcController = TextEditingController();
  final _sigController = TextEditingController();
  bool _verifyingNmc = false;
  bool _requestingNotifications = false;
  bool _requestingCameraMic = false;
  String _error = '';

  static const _stepIcons = [Icons.badge_outlined, Icons.draw_outlined, Icons.tune_outlined];

  @override
  void dispose() {
    _nmcController.dispose();
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission(AppState app) async {
    setState(() => _requestingNotifications = true);
    final status = await Permission.notification.request();
    if (!mounted) return;
    setState(() => _requestingNotifications = false);
    if (status.isGranted || status.isLimited) {
      app.grantNotificationPermission();
    } else {
      setState(() {
        _error = status.isPermanentlyDenied
            ? 'Notification permission was denied. Enable it from system settings to continue.'
            : 'Notification permission is required to alert you of new patient check-ins.';
      });
    }
  }

  Future<void> _requestCameraMicPermission(AppState app) async {
    setState(() => _requestingCameraMic = true);
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (!mounted) return;
    setState(() => _requestingCameraMic = false);
    final granted = statuses.values.every((s) => s.isGranted);
    if (granted) {
      app.grantCameraMicPermission();
    } else {
      final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
      setState(() {
        _error = permanentlyDenied
            ? 'Camera/microphone permission was denied. Enable it from system settings to continue.'
            : 'Camera and microphone access are required to conduct video consultations.';
      });
    }
  }

  void _verifyNmc(AppState app) async {
    final num = _nmcController.text.trim();
    if (num.isEmpty) {
      setState(() => _error = 'Please enter your NMC Registration Number.');
      return;
    }
    setState(() {
      _verifyingNmc = true;
      _error = '';
    });
    await app.verifyNmc(num);
    setState(() {
      _verifyingNmc = false;
      _currentStep = 1; // Move to signature step
    });
  }

  void _saveSignature(AppState app) {
    final sig = _sigController.text.trim();
    if (sig.isEmpty) {
      setState(() => _error = 'Please enter your full name to generate a signature.');
      return;
    }
    setState(() => _error = '');
    app.saveSignature(sig);
    setState(() => _currentStep = 2); // Move to permissions step
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink900),
                onPressed: () => setState(() => _currentStep -= 1),
              )
            : null,
        title: Text('Doctor Onboarding', style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            onPressed: app.logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepProgressIndicator(
              currentStep: _currentStep,
              totalSteps: 3,
              currentStepIcon: _stepIcons[_currentStep],
            ),
            const SizedBox(height: 28),

            if (_currentStep == 0) ...[
              // Step 1: NMC Verification
              _StepIconBadge(icon: Icons.badge_outlined),
              const SizedBox(height: 16),
              Text('Medical Council Verification', textAlign: TextAlign.center, style: AppText.display(size: 17)),
              const SizedBox(height: 6),
              Text(
                'Provide your National Medical Council (NMC) registration number. We verify this live against the national register.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12.5, color: AppColors.ink600),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'NMC Registration Number',
                      style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.ink600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nmcController,
                      decoration: const InputDecoration(hintText: 'e.g. NMC-2016-MH-08421'),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_error, style: AppText.body(size: 12, color: AppColors.red600)),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: _verifyingNmc ? 'Verifying...' : 'Verify NMC',
                      icon: _verifyingNmc ? null : const Icon(Icons.verified_user_outlined, size: 16),
                      loading: _verifyingNmc,
                      block: true,
                      onPressed: () => _verifyNmc(app),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _InfoFootnote(
                text: 'We never share your data with any third party.',
                color: AppColors.blue100,
                iconColor: AppColors.blue700,
                textColor: AppColors.blue700,
                icon: Icons.info_outline,
              ),
            ] else if (_currentStep == 1) ...[
              // Step 2: Digital Signature
              _StepIconBadge(icon: Icons.draw_outlined),
              const SizedBox(height: 16),
              Text('Configure Digital Signature', textAlign: TextAlign.center, style: AppText.display(size: 17)),
              const SizedBox(height: 6),
              Text(
                'Your digital signature is required before signing prescriptions. This signature is stored securely on your device.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12.5, color: AppColors.ink600),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Type Your Full Name for Signature',
                      style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.ink600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _sigController,
                      decoration: const InputDecoration(hintText: 'e.g. Dr. Rhea Kulkarni'),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(_error, style: AppText.body(size: 12, color: AppColors.red600)),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Save & Continue',
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      block: true,
                      onPressed: () => _saveSignature(app),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Back',
                      variant: AppButtonVariant.ghost,
                      block: true,
                      onPressed: () => setState(() => _currentStep = 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _InfoFootnote(
                text: 'Your signature is encrypted and never leaves your device.',
                color: AppColors.green100,
                iconColor: AppColors.green600,
                textColor: AppColors.green600,
                icon: Icons.lock_outline,
              ),
            ] else ...[
              // Step 3: Permissions & Finish
              _StepIconBadge(icon: Icons.tune_outlined),
              const SizedBox(height: 16),
              Text('Grant Permissions', textAlign: TextAlign.center, style: AppText.display(size: 17)),
              const SizedBox(height: 6),
              Text(
                'MediConnectAI requires access to system utilities to notify you of patient check-ins and conduct video consultations.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12.5, color: AppColors.ink600),
              ),
              const SizedBox(height: 22),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PermissionRow(
                      title: 'Notification Alerting',
                      subtitle: 'Get notified when a patient joins your queue',
                      granted: app.notificationsGranted,
                      loading: _requestingNotifications,
                      icon: Icons.notifications_active_outlined,
                      onTap: () => _requestNotificationPermission(app),
                    ),
                    const SizedBox(height: 16),
                    _PermissionRow(
                      title: 'Camera & Microphone',
                      subtitle: 'For conducting telemedicine calls with patients',
                      granted: app.cameraMicGranted,
                      loading: _requestingCameraMic,
                      icon: Icons.videocam_outlined,
                      onTap: () => _requestCameraMicPermission(app),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_error, style: AppText.body(size: 12, color: AppColors.red600)),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Complete Onboarding',
                      icon: const Icon(Icons.check, size: 16),
                      variant: AppButtonVariant.success,
                      block: true,
                      onPressed: (app.notificationsGranted && app.cameraMicGranted)
                          ? app.completeOnboarding
                          : null,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Back',
                      variant: AppButtonVariant.ghost,
                      block: true,
                      onPressed: () => setState(() => _currentStep = 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepIconBadge extends StatelessWidget {
  const _StepIconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blue100, AppColors.teal100],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 32, color: AppColors.blue700),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.green600,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(BorderSide(color: AppColors.blue50, width: 3)),
              ),
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoFootnote extends StatelessWidget {
  const _InfoFootnote({
    required this.text,
    required this.color,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });

  final String text;
  final Color color;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body(size: 11.5, color: textColor, weight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String title;
  final String subtitle;
  final bool granted;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (granted || loading) ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: granted ? AppColors.green100.withValues(alpha: 0.5) : AppColors.white,
          border: Border.all(color: granted ? AppColors.green600.withValues(alpha: 0.3) : AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: granted ? AppColors.green600 : AppColors.blue600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(size: 13, weight: FontWeight.bold)),
                  Text(subtitle, style: AppText.body(size: 11, color: AppColors.ink600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (granted)
              const Icon(Icons.check_circle, color: AppColors.green600, size: 20)
            else
              Text(
                'Grant',
                style: AppText.body(size: 12, color: AppColors.blue600, weight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
