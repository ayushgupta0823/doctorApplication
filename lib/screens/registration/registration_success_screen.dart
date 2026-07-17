import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'registration_data.dart';

/// Shown once the 4-step wizard is submitted — a summary of what was sent
/// plus what happens next, before automatically continuing into the app.
/// [onContinue] is called either when the doctor taps "Continue to
/// Dashboard" or when the countdown reaches zero, whichever comes first.
class RegistrationSuccessScreen extends StatefulWidget {
  const RegistrationSuccessScreen({super.key, required this.data, required this.onContinue});

  final RegistrationData data;
  final VoidCallback onContinue;

  @override
  State<RegistrationSuccessScreen> createState() => _RegistrationSuccessScreenState();
}

class _RegistrationSuccessScreenState extends State<RegistrationSuccessScreen> {
  static const _autoContinueSeconds = 6;
  int _secondsLeft = _autoContinueSeconds;
  Timer? _timer;
  bool _continued = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _continue();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (_continued) return;
    _continued = true;
    _timer?.cancel();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final documentsProvided = [
      if (data.nmcCertificateFile != null) 'NMC / State Council Certificate',
      if (data.govIdFile != null) 'Government ID Proof',
      if (data.degreeCertificateFile != null) 'Degree Certificate',
    ];

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: AppColors.green100, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.green600, size: 52),
                ).animate().scale(begin: const Offset(0.6, 0.6), curve: Curves.easeOutBack, duration: 450.ms).fadeIn(duration: 300.ms),
              ),
              const SizedBox(height: 20),
              Text(
                'Registration Submitted!',
                textAlign: TextAlign.center,
                style: AppText.display(size: 21),
              ),
              const SizedBox(height: 6),
              Text(
                'Thank you, Dr. ${data.fullName}. Your application has been received and is now in our verification queue.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 13, color: AppColors.ink600).copyWith(height: 1.4),
              ),
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Application Summary', style: AppText.display(size: 14)),
                    const SizedBox(height: 12),
                    _SummaryRow(icon: Icons.badge_outlined, label: 'NMC Registration', value: data.nmcRegistrationNumber),
                    _SummaryRow(icon: Icons.workspace_premium_outlined, label: 'Experience', value: '${data.experienceYears} years'),
                    _SummaryRow(icon: Icons.medical_information_outlined, label: 'Specialties', value: data.specialties.join(', ')),
                    _SummaryRow(icon: Icons.location_on_outlined, label: 'Practice Location', value: '${data.city}, ${data.state}'),
                    _SummaryRow(icon: Icons.mail_outline, label: 'Official Email', value: data.officialEmail),
                    _SummaryRow(
                      icon: Icons.description_outlined,
                      label: 'Documents',
                      value: documentsProvided.isEmpty ? 'None uploaded' : documentsProvided.join(', '),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('What happens next', style: AppText.display(size: 14)),
                    const SizedBox(height: 10),
                    _NoteRow(text: 'Our team verifies your NMC registration and uploaded documents within 24-48 hours.'),
                    _NoteRow(text: "You'll get a confirmation email at ${data.officialEmail} once your profile is approved."),
                    _NoteRow(text: 'You can explore the app and finish setting up your profile while verification is in progress.'),
                    _NoteRow(text: 'Your listing goes live for patient bookings right after approval.', isLast: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Continue to Dashboard ($_secondsLeft s)',
                icon: const Icon(Icons.arrow_forward, size: 16),
                variant: AppButtonVariant.success,
                block: true,
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label, required this.value, this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.blue700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.ink600)),
                Text(value.isEmpty ? '—' : value, style: AppText.body(size: 13, weight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.text, this.isLast = false});
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline, size: 14, color: AppColors.green600),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body(size: 12.5, color: AppColors.ink600).copyWith(height: 1.35))),
        ],
      ),
    );
  }
}
