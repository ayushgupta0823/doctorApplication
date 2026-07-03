import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Pill-shaped status badge, ported from the `.badge.*` CSS classes.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ConsultStatus status;

  ({Color bg, Color fg}) get _colors {
    switch (status) {
      case ConsultStatus.scheduled:
        return (bg: AppColors.blue100, fg: AppColors.blue700);
      case ConsultStatus.confirmed:
        return (bg: AppColors.teal100, fg: AppColors.teal500);
      case ConsultStatus.waiting:
        return (bg: AppColors.amber100, fg: AppColors.amber600);
      case ConsultStatus.inProgress:
        return (bg: const Color(0xFFFDEBD6), fg: const Color(0xFFC25A00));
      case ConsultStatus.completed:
        return (bg: AppColors.green100, fg: AppColors.green600);
      case ConsultStatus.noShow:
      case ConsultStatus.cancelled:
        return (bg: AppColors.red100, fg: AppColors.red600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        status.label.toUpperCase(),
        style: AppText.mono(size: 10, weight: FontWeight.w700, color: c.fg)
            .copyWith(letterSpacing: .3),
      ),
    );
  }
}
