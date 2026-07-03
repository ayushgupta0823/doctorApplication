import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular initials avatar, ported from `.avatar`.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 42, this.fontSize = 14.5});

  final String name;
  final double size;
  final double fontSize;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.blue100, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: AppText.display(size: fontSize, color: AppColors.blue700),
      ),
    );
  }
}
