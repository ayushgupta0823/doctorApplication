import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import 'more/simple_info_screen.dart';
import 'settings/clinic_information_screen.dart';
import 'settings/consultation_settings_screen.dart';
import 'settings/notification_preferences_screen.dart';
import 'settings/security_privacy_screen.dart';

class _SettingsRow {
  const _SettingsRow(this.icon, this.label, this.subtitle, this.builder);
  final IconData icon;
  final String label;
  final String subtitle;
  final WidgetBuilder builder;
}

/// My Profile: a settings-list landing page (doctor card + NMC status +
/// navigable rows) rather than one long edit form — each row's actual
/// fields now live on their own destination screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final List<_SettingsRow> _rows = [
    _SettingsRow(Icons.storefront_outlined, 'Clinic Information', 'Personal details, specialties, location', (_) => const ClinicInformationScreen()),
    _SettingsRow(Icons.schedule_outlined, 'Working Hours', 'Set your weekly availability', (_) => const SimpleInfoScreen(title: 'Working Hours', icon: Icons.schedule_outlined, description: 'Configure the hours you take consultations each day of the week.')),
    _SettingsRow(Icons.tune_outlined, 'Consultation Settings', 'Fees, default follow-up period', (_) => const ConsultationSettingsScreen()),
    _SettingsRow(Icons.notifications_outlined, 'Notification Preferences', 'Push, camera & microphone access', (_) => const NotificationPreferencesScreen()),
    _SettingsRow(Icons.shield_outlined, 'Security & Privacy', 'Digital signature, app lock', (_) => const SecurityPrivacyScreen()),
    _SettingsRow(Icons.payments_outlined, 'Payment & Earnings', 'Consultation earnings and payouts', (_) => const SimpleInfoScreen(title: 'Payment & Earnings', icon: Icons.payments_outlined, description: 'Payout history and earnings summary will appear here once billing is connected.')),
    _SettingsRow(Icons.info_outline, 'About MediConnectAI', 'Version, licenses, credits', (_) => const SimpleInfoScreen(title: 'About MediConnectAI', icon: Icons.info_outline, description: 'MediConnectAI Doctor App · Version 1.0.0', items: ['Terms of Service', 'Privacy Policy', 'Open-source licenses'])),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('My Profile', style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.settings_outlined, size: 20), onPressed: () {})],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.blue700, AppColors.blue900], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('DR', style: AppText.display(size: 18, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. Rhea Kulkarni', style: AppText.display(size: 15, color: Colors.white)),
                      Text('MBBS, MD (Medicine)', style: AppText.body(size: 11.5, color: AppColors.blue100)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(app.isOnline ? 'Available' : 'Offline', style: AppText.body(size: 10.5, weight: FontWeight.w600, color: Colors.white)),
                    Switch(value: app.isOnline, activeThumbColor: AppColors.green600, onChanged: app.setAvailability),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                Text('NMC Registration', style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.blue700)),
                const SizedBox(width: 6),
                Expanded(child: Text(app.nmcNumber.isNotEmpty ? app.nmcNumber : 'NMC-2016-MH-08421', style: AppText.mono(size: 11.5, color: AppColors.blue700))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.green100, borderRadius: BorderRadius.circular(100)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified, size: 10, color: AppColors.green600),
                    const SizedBox(width: 3),
                    Text('Verified', style: AppText.body(size: 9, weight: FontWeight.w700, color: AppColors.green600)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: List.generate(_rows.length, (i) {
                final row = _rows[i];
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(row.icon, color: AppColors.blue700),
                      title: Text(row.label, style: AppText.body(size: 13, weight: FontWeight.bold)),
                      subtitle: Text(row.subtitle, style: AppText.body(size: 11, color: AppColors.ink600)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: row.builder)),
                    ),
                    if (i != _rows.length - 1) const Divider(height: 1, color: AppColors.lineSoft),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(label: 'Log Out', variant: AppButtonVariant.danger, icon: const Icon(Icons.logout, size: 16), block: true, onPressed: app.logout),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
