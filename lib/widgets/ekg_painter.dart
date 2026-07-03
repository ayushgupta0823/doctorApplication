import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Decorative heartbeat line, ported from the `ekg()` inline SVG helper.
class EkgLine extends StatelessWidget {
  const EkgLine({super.key, this.height = 14});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _EkgPainter()),
    );
  }
}

class _EkgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blue500.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Coordinates scaled from the original 300x14 viewBox path:
    // M0 7 H60 L68 2 L76 12 L84 7 H300
    final sx = size.width / 300;
    final sy = size.height / 14;
    final path = Path()
      ..moveTo(0, 7 * sy)
      ..lineTo(60 * sx, 7 * sy)
      ..lineTo(68 * sx, 2 * sy)
      ..lineTo(76 * sx, 12 * sy)
      ..lineTo(84 * sx, 7 * sy)
      ..lineTo(size.width, 7 * sy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
