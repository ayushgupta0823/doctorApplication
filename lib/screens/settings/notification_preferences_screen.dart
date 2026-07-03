import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

/// Shows the real, current OS permission state (not a fake settings
/// toggle) and links out to system settings to change it.
class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Notification Preferences', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                _PermissionStatusRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'New patient check-ins & queue alerts',
                  granted: app.notificationsGranted,
                ),
                const Divider(height: 1, color: AppColors.lineSoft),
                _PermissionStatusRow(
                  icon: Icons.videocam_outlined,
                  title: 'Camera & Microphone',
                  subtitle: 'Required for video consultations',
                  granted: app.cameraMicGranted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Open System Notification Settings',
            variant: AppButtonVariant.ghost,
            icon: const Icon(Icons.settings_outlined, size: 16),
            block: true,
            onPressed: () => openAppSettings(),
          ),
        ],
      ),
    );
  }
}

class _PermissionStatusRow extends StatelessWidget {
  const _PermissionStatusRow({required this.icon, required this.title, required this.subtitle, required this.granted});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: granted ? AppColors.green600 : AppColors.ink400),
      title: Text(title, style: AppText.body(size: 13, weight: FontWeight.bold)),
      subtitle: Text(subtitle, style: AppText.body(size: 11, color: AppColors.ink600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: granted ? AppColors.green100 : AppColors.red100, borderRadius: BorderRadius.circular(100)),
        child: Text(granted ? 'Granted' : 'Not granted', style: AppText.body(size: 10, weight: FontWeight.w700, color: granted ? AppColors.green600 : AppColors.red600)),
      ),
    );
  }
}
