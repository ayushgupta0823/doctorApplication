import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular initials avatar, ported from `.avatar`. When [imageUrl] is a
/// real, loadable image it's shown instead — falling back to initials on a
/// missing URL or a failed load, never a broken-image icon.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 42, this.fontSize = 14.5, this.imageUrl});

  final String name;
  final double size;
  final double fontSize;
  final String? imageUrl;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letters = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join();
    return letters.toUpperCase();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: AppColors.blue100,
      alignment: Alignment.center,
      child: Text(
        _initials,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppText.display(size: fontSize, color: AppColors.blue700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipOval(
      child: (url == null || url.isEmpty)
          ? _fallback()
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
              loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(),
            ),
    );
  }
}
