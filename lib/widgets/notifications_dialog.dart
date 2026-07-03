import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';

void showNotificationsDialog(BuildContext context, AppState app) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.blue600, size: 20),
          const SizedBox(width: 8),
          const Flexible(child: Text('Notifications Log', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: app.inAppNotifications.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No check-ins or incoming call alerts.',
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 12.5, color: AppColors.ink400),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: app.inAppNotifications.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.lineSoft),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      app.inAppNotifications[index],
                      style: AppText.body(size: 12.5),
                    ),
                  );
                },
              ),
      ),
      actions: [
        if (app.inAppNotifications.isNotEmpty)
          TextButton(
            onPressed: () {
              app.clearNotifications();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}
