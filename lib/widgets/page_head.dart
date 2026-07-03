import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ekg_painter.dart';

/// Screen header block, ported from `.pageHead`.
class PageHead extends StatelessWidget {
  const PageHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.showEkg = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool showEkg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppText.mono(size: 11, weight: FontWeight.w600, color: AppColors.blue600)
                .copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 2),
          Text(title, style: AppText.display(size: 23)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: AppText.body(size: 12.5, color: AppColors.ink600)),
          ],
          if (showEkg) ...[
            const SizedBox(height: 8),
            const EkgLine(),
          ],
        ],
      ),
    );
  }
}
