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
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(15, 27, 45, 0.06), blurRadius: 2, offset: Offset(0, 1)),
        ],
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
          Text(text, style: AppText.display(size: 13.5)),
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
