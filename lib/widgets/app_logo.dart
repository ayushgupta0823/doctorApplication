import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared brand mark sizes — small (nav/app bars), medium (cards), large
/// (splash-style hero placement on Login/Onboarding).
enum AppLogoSize { small, medium, large }

double _dimensionFor(AppLogoSize size) {
  switch (size) {
    case AppLogoSize.small:
      return 34;
    case AppLogoSize.medium:
      return 56;
    case AppLogoSize.large:
      return 76;
  }
}

/// The icon-only brand mark: a gradient badge with a white heartbeat pulse
/// through the center — reuses the same visual language as [EkgLine]
/// elsewhere in the app so the mark reads as "this app", not a stock icon.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = AppLogoSize.medium});

  final AppLogoSize size;

  @override
  Widget build(BuildContext context) {
    final d = _dimensionFor(size);
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue600, AppColors.blue900],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.blue600.withValues(alpha: 0.32), blurRadius: d * 0.36, offset: Offset(0, d * 0.14)),
        ],
      ),
      child: CustomPaint(size: Size(d, d), painter: _LogoMarkPainter()),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final pulsePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final baseY = h * 0.58;
    final path = Path()
      ..moveTo(w * 0.10, baseY)
      ..lineTo(w * 0.32, baseY)
      ..lineTo(w * 0.42, baseY - h * 0.26)
      ..lineTo(w * 0.53, baseY + h * 0.30)
      ..lineTo(w * 0.62, baseY)
      ..lineTo(w * 0.90, baseY);
    canvas.drawPath(path, pulsePaint);

    // A small "live" dot at the wave's leading edge — reads as a heartbeat,
    // not just a static zigzag.
    canvas.drawCircle(Offset(w * 0.90, baseY), w * 0.05, Paint()..color = AppColors.teal500);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The full brand lockup: [AppLogoMark] plus the "MediConnectAI" wordmark.
/// Used on Login and Onboarding; pass `showWordmark: false` (or just use
/// [AppLogoMark] directly) for tight spaces like an app bar.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = AppLogoSize.large,
    this.axis = Axis.vertical,
    this.wordmarkColor = AppColors.blue900,
  });

  final AppLogoSize size;
  final Axis axis;
  final Color wordmarkColor;

  @override
  Widget build(BuildContext context) {
    final mark = AppLogoMark(size: size);
    final wordmark = Text(
      'MediConnectAI',
      style: AppText.display(size: size == AppLogoSize.small ? 14 : 22, color: wordmarkColor),
    );
    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [mark, const SizedBox(height: 12), wordmark],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [mark, const SizedBox(width: 10), wordmark],
    );
  }
}
