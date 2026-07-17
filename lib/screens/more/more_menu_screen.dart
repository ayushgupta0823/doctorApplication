import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../profile_screen.dart';
import '../reports_analytics_screen.dart';
import 'ai_assistant_screen.dart';
import 'chat_screen.dart';
import 'documents_screen.dart';
import 'feedback_screen.dart';
import 'follow_ups_screen.dart';
import 'health_tips_screen.dart';
import 'help_support_screen.dart';
import 'lab_orders_screen.dart';
import 'prescription_templates_screen.dart';
import 'prescriptions_sent_screen.dart';
import 'reminders_screen.dart';
import 'voice_notes_screen.dart';

class _MoreItem {
  const _MoreItem(this.icon, this.label, this.builder);
  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// The More tab: grid of secondary features plus app-level settings. Every
/// destination here is a genuinely working screen — either backed by a
/// real endpoint, derived from real app data, or an honest on-device
/// feature — none render as a dead "Nothing here yet" placeholder.
class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  static final List<_MoreItem> _items = [
    _MoreItem(Icons.description_outlined, 'Documents', (_) => const DocumentsScreen()),
    _MoreItem(Icons.biotech_outlined, 'Lab Orders', (_) => const LabOrdersScreen()),
    _MoreItem(Icons.event_repeat_outlined, 'Follow-ups', (_) => const FollowUpsScreen()),
    _MoreItem(Icons.notifications_active_outlined, 'Reminders', (_) => const RemindersScreen()),
    _MoreItem(Icons.receipt_long_outlined, 'Prescriptions Sent', (_) => const PrescriptionsSentScreen()),
    _MoreItem(Icons.article_outlined, 'Templates', (_) => const PrescriptionTemplatesScreen()),
    _MoreItem(Icons.health_and_safety_outlined, 'Health Tips', (_) => const HealthTipsScreen()),
    _MoreItem(Icons.chat_bubble_outline, 'Chat Interaction', (_) => const ChatListScreen()),
    _MoreItem(Icons.mic_none_outlined, 'Voice Notes', (_) => const VoiceNotesScreen()),
    _MoreItem(Icons.auto_awesome_outlined, 'AI Assistant', (_) => const AiAssistantScreen()),
    _MoreItem(Icons.feedback_outlined, 'Feedback', (_) => const FeedbackScreen()),
    _MoreItem(Icons.help_outline, 'Help & Support', (_) => const HelpSupportScreen()),
  ];

  // Soft per-tile color tint, cycled across the grid so the icons read as
  // categorized at a glance rather than a wall of identical white circles.
  static const _tileTints = [
    (bg: AppColors.blue100, fg: AppColors.blue700),
    (bg: AppColors.teal100, fg: AppColors.tealDark),
    (bg: AppColors.green100, fg: AppColors.green600),
    (bg: AppColors.amber100, fg: AppColors.amberDark),
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
            ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
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
            ).animate(delay: 40.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              // Fewer, wider columns on narrow phones so each 48dp icon +
              // 2-line label isn't squeezed.
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 380 ? 3 : 4,
                mainAxisSpacing: 14,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, i) {
                final item = _items[i];
                final tint = _tileTints[i % _tileTints.length];
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: item.builder)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: tint.bg, shape: BoxShape.circle, boxShadow: AppShadow.sm),
                        child: Icon(item.icon, size: 21, color: tint.fg),
                      ),
                      const SizedBox(height: 6),
                      Text(item.label, textAlign: TextAlign.center, style: AppText.body(size: 10, weight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ).animate(delay: (i * 30).ms).fadeIn(duration: 220.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
              },
            ),
            const SizedBox(height: 20),
            Text('APP SETTINGS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
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
