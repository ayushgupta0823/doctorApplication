import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// White rounded card with a soft shadow, ported from `.card`.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      // A plain Container isn't a Material ancestor, so any ListTile/InkWell
      // placed directly inside would paint its ink splashes underneath this
      // card's opaque background and never be visible. Interpose a
      // transparent Material so descendants like the Profile and More menu
      // settings rows get working tap feedback.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// Section heading row, ported from `.sectionTitle`.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text, this.icon});

  final String text;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 6)],
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(size: 13.5)),
          ),
        ],
      ),
    );
  }
}

/// Centered icon + message used for empty/error states across the "More"
/// feature screens, so a bare line of text never has to stand in for a
/// deliberately designed empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor = AppColors.blue700,
    this.iconBackground = AppColors.blue100,
    this.messageColor = AppColors.ink400,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
  });

  final IconData icon;
  final String message;
  final Color iconColor;
  final Color iconBackground;
  final Color messageColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppText.body(size: 12.5, color: messageColor)),
        ],
      ),
    );
  }
}

/// Small colored pill chip, ported from `.chip`.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.blue700)),
    );
  }
}
