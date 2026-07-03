import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small trend line with a highlighted last point, ported from the
/// `sparkline(vals)` helper.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 32});

  final List<num> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _SparklinePainter(values)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);
  final List<num> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    // Copy into a concrete List<double> first: reducing `values` directly
    // fails at runtime when it's actually a List<int> passed in as
    // List<num> — the combine closure's inferred (num, num) type doesn't
    // match the (int, int) required by List<int>.reduce.
    final vals = values.map((v) => v.toDouble()).toList();
    final min = vals.reduce((a, b) => a < b ? a : b);
    final max = vals.reduce((a, b) => a > b ? a : b);
    const pad = 6.0;
    final sx = size.width / 100;
    final sy = size.height / 32;
    final range = (max - min) == 0 ? 1 : (max - min);

    final points = <Offset>[];
    if (vals.length == 1) {
      points.add(Offset(size.width / 2, size.height / 2));
    } else {
      for (var i = 0; i < vals.length; i++) {
        final x = (pad + i * ((100 - 2 * pad) / (vals.length - 1))) * sx;
        final y = (28 - ((vals[i] - min) / range) * 22 - 2) * sy;
        points.add(Offset(x, y));
      }
    }

    final paint = Paint()
      ..color = AppColors.blue600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.isNotEmpty) {
      if (points.length > 1) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
      canvas.drawCircle(points.last, 2.6, Paint()..color = AppColors.blue600);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.values != values;
}
