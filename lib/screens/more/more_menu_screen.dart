import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../profile_screen.dart';
import '../reports_analytics_screen.dart';
import 'simple_info_screen.dart';

class _MoreItem {
  const _MoreItem(this.icon, this.label, this.builder);
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// The More tab: grid of secondary features plus app-level settings.
/// Screens without a bespoke design in this pass render as an honest,
/// functional [SimpleInfoScreen] rather than a fake dead-end button.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  static final List<_MoreItem> _items = [
    _MoreItem(Icons.description_outlined, 'Documents',
        (_) => const SimpleInfoScreen(title: 'Documents', icon: Icons.description_outlined, description: 'Upload and review patient documents and scanned reports.')),
    _MoreItem(Icons.biotech_outlined, 'Lab Orders',
        (_) => const SimpleInfoScreen(title: 'Lab Orders', icon: Icons.biotech_outlined, description: 'Lab tests ordered from active consultations appear here.')),
    _MoreItem(Icons.event_repeat_outlined, 'Follow-ups',
        (_) => const SimpleInfoScreen(title: 'Follow-ups', icon: Icons.event_repeat_outlined, description: 'Patients flagged for a follow-up visit.')),
    _MoreItem(Icons.notifications_active_outlined, 'Reminders',
        (_) => const SimpleInfoScreen(title: 'Reminders', icon: Icons.notifications_active_outlined, description: 'Personal reminders and task follow-ups.')),
    _MoreItem(Icons.local_pharmacy_outlined, 'Pharmacy',
        (_) => const SimpleInfoScreen(title: 'Pharmacy', icon: Icons.local_pharmacy_outlined, description: 'Partner pharmacy directory for e-prescription fulfilment.')),
    _MoreItem(Icons.article_outlined, 'Templates',
        (_) => const SimpleInfoScreen(title: 'Templates', icon: Icons.article_outlined, description: 'Reusable SOAP note and prescription templates.')),
    _MoreItem(Icons.health_and_safety_outlined, 'Health Tips',
        (_) => const SimpleInfoScreen(
              title: 'Health Tips',
              icon: Icons.health_and_safety_outlined,
              description: 'Shareable patient education material.',
              items: ['Managing seasonal allergies', 'Blood pressure home monitoring', 'Asthma inhaler technique'],
            )),
    _MoreItem(Icons.chat_bubble_outline, 'Chat Interaction',
        (_) => const SimpleInfoScreen(title: 'Chat Interaction', icon: Icons.chat_bubble_outline, description: 'Secure in-app messaging with your patients.')),
    _MoreItem(Icons.mic_none_outlined, 'Voice Notes',
        (_) => const SimpleInfoScreen(title: 'Voice Notes', icon: Icons.mic_none_outlined, description: 'Dictated notes recorded during or after a consultation.')),
    _MoreItem(Icons.auto_awesome_outlined, 'AI Assistant',
        (_) => const SimpleInfoScreen(title: 'AI Assistant', icon: Icons.auto_awesome_outlined, description: 'Ask the clinical assistant for suggestions across your patient panel.')),
    _MoreItem(Icons.feedback_outlined, 'Feedback',
        (_) => const SimpleInfoScreen(title: 'Feedback', icon: Icons.feedback_outlined, description: "Tell us what's working and what isn't.")),
    _MoreItem(Icons.help_outline, 'Help & Support',
        (_) => const SimpleInfoScreen(
              title: 'Help & Support',
              icon: Icons.help_outline,
              description: 'FAQs, chat support, and product guides.',
              items: ['How do I sign a prescription?', 'How is my digital signature stored?', 'Contact support'],
            )),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('More', style: AppText.display(size: 20, color: AppColors.blue900)),
            const SizedBox(height: 4),
            Text('Everything else you need, in one place', style: AppText.body(size: 12.5, color: AppColors.ink600)),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(4),
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.blue700),
                title: Text('Profile & Settings', style: AppText.body(size: 13, weight: FontWeight.bold)),
                subtitle: Text('Clinic details, fees, qualifications', style: AppText.body(size: 11, color: AppColors.ink600)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.all(4),
              child: ListTile(
                leading: const Icon(Icons.bar_chart_outlined, color: AppColors.blue700),
                title: Text('Reports & Analytics', style: AppText.body(size: 13, weight: FontWeight.bold)),
                subtitle: Text('Weekly performance and top conditions', style: AppText.body(size: 11, color: AppColors.ink600)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportsAnalyticsScreen())),
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.78),
              itemBuilder: (context, i) {
                final item = _items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: item.builder)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                        child: Icon(item.icon, size: 21, color: AppColors.blue700),
                      ),
                      const SizedBox(height: 6),
                      Text(item.label, textAlign: TextAlign.center, style: AppText.body(size: 10, weight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('APP SETTINGS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: app.isDarkMode,
                    onChanged: app.setDarkMode,
                    activeThumbColor: AppColors.green600,
                    title: Text('Dark Mode', style: AppText.body(size: 13, weight: FontWeight.w600)),
                    secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.blue700),
                  ),
                  const Divider(height: 1, color: AppColors.lineSoft),
                  ListTile(
                    leading: const Icon(Icons.language_outlined, color: AppColors.blue700),
                    title: Text('Language', style: AppText.body(size: 13, weight: FontWeight.w600)),
                    trailing: DropdownButton<String>(
                      value: app.selectedLanguage,
                      underline: const SizedBox.shrink(),
                      items: const ['English', 'Hindi', 'Marathi'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                      onChanged: (v) {
                        if (v != null) app.setLanguage(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
