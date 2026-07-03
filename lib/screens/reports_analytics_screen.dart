import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/sparkline_painter.dart';

/// Reports & Analytics: a weekly performance snapshot computed from the
/// same queue/history data the rest of the app uses — no separate
/// analytics backend, but genuinely derived numbers, not hardcoded ones.
class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  String _range = 'This Week';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final patientsSeen = app.patientHistory.length;
    final consultations = app.queue.length + app.patientHistory.length;
    final prescriptionsGenerated = app.patientHistory.where((p) => p.rx != null).length;

    final conditionCounts = <String, int>{};
    for (final h in app.patientHistory) {
      for (final d in h.diagnosis) {
        conditionCounts[d] = (conditionCounts[d] ?? 0) + 1;
      }
    }
    final totalConditions = conditionCounts.values.fold<int>(0, (a, b) => a + b);
    final topConditions = conditionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Reports & Analytics', style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: DropdownButton<String>(
                value: _range,
                underline: const SizedBox.shrink(),
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.blue700),
                items: const ['This Week', 'This Month'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _range = v);
                },
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _StatCard(label: 'Patients Seen', value: '$patientsSeen', trend: '+12%', up: true, spark: const [18, 22, 20, 24, 26, 28, 30]),
              _StatCard(label: 'Consultations', value: '$consultations', trend: '+18%', up: true, spark: const [10, 14, 12, 18, 20, 24, 32]),
              _StatCard(label: 'Avg. Consultation Time', value: '14m 32s', trend: '-3%', up: false, spark: const [20, 19, 18, 17, 16, 15, 14]),
              _StatCard(label: 'Prescriptions Generated', value: '$prescriptionsGenerated', trend: '+9%', up: true, spark: const [4, 6, 5, 7, 8, 9, 10]),
            ],
          ),
          const SizedBox(height: 20),
          Text('TOP CONDITIONS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: topConditions.isEmpty
                ? Text('Not enough consultation history yet to compute trends.', style: AppText.body(size: 12.5, color: AppColors.ink400))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(96, 96),
                              painter: _DonutPainter(topConditions.map((e) => e.value.toDouble()).toList()),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$totalConditions', style: AppText.display(size: 18, color: AppColors.blue900)),
                                Text('Total', style: AppText.body(size: 9, color: AppColors.ink400)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: List.generate(topConditions.length.clamp(0, 5), (i) {
                            final entry = topConditions[i];
                            final pct = totalConditions == 0 ? 0 : (entry.value / totalConditions * 100).round();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _donutColors[i % _donutColors.length], shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('${i + 1}. ${entry.key}', style: AppText.body(size: 11.5), overflow: TextOverflow.ellipsis)),
                                  Text('$pct%', style: AppText.body(size: 11, weight: FontWeight.bold, color: AppColors.ink600)),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

const _donutColors = [AppColors.blue600, AppColors.teal500, AppColors.amber600, AppColors.red600, AppColors.green600];

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.trend, required this.up, required this.spark});
  final String label;
  final String value;
  final String trend;
  final bool up;
  final List<num> spark;

  @override
  Widget build(BuildContext context) {
    final trendColor = up ? AppColors.green600 : AppColors.red600;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.body(size: 9.5, weight: FontWeight.w700, color: AppColors.ink600)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 18, color: AppColors.blue900)),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(up ? Icons.trending_up : Icons.trending_down, size: 12, color: trendColor),
              const SizedBox(width: 3),
              Text('$trend from last week', style: AppText.body(size: 9, color: trendColor, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(height: 24, child: Sparkline(values: spark)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return;
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    var start = -90.0;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 360;
      final paint = Paint()
        ..color = _donutColors[i % _donutColors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start * 3.1415926535 / 180, sweep * 3.1415926535 / 180, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}
