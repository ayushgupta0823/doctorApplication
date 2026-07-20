import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/report_pdf.dart';
import '../widgets/app_card.dart';
import '../widgets/sparkline_painter.dart';

/// Reports & Analytics: a weekly/monthly performance snapshot computed
/// entirely from real consultation history (`createdAt`-backed) — no
/// separate analytics backend, and no hardcoded trend numbers: a period
/// with nothing to compare against honestly shows "New" instead of a
/// fabricated percentage.
class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

/// Honest week/month-over-week trend: `null` when there's no prior-period
/// data to compare against (a brand-new doctor's first week, say) rather
/// than a fabricated percentage.
(String, bool)? _trendLabel(int current, int previous) {
  if (previous == 0) return current == 0 ? null : ('New', true);
  final pct = ((current - previous) / previous * 100).round();
  if (pct == 0) return ('No change', true);
  return ('${pct > 0 ? '+' : ''}$pct% vs last period', pct > 0);
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  String _range = 'This Week';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final periodDays = _range == 'This Week' ? 7 : 30;
    final now = DateTime.now();
    final periodStart = now.subtract(Duration(days: periodDays));
    final previousPeriodStart = now.subtract(Duration(days: periodDays * 2));

    bool inCurrentPeriod(PatientHistory h) => h.createdAt != null && h.createdAt!.isAfter(periodStart);
    bool inPreviousPeriod(PatientHistory h) => h.createdAt != null && h.createdAt!.isAfter(previousPeriodStart) && !h.createdAt!.isAfter(periodStart);

    final current = app.patientHistory.where(inCurrentPeriod).toList();
    final previous = app.patientHistory.where(inPreviousPeriod).toList();

    final patientsSeen = current.map((h) => h.name).toSet().length;
    final patientsSeenPrev = previous.map((h) => h.name).toSet().length;
    final consultations = current.length;
    final consultationsPrev = previous.length;
    final prescriptionsGenerated = current.where((p) => p.rx != null).length;
    final prescriptionsGeneratedPrev = previous.where((p) => p.rx != null).length;
    final noShowsToday = app.queue.where((p) => p.status == ConsultStatus.noShow).length;

    // Daily consultation counts across the period, most-recent last — a
    // genuine trend line rather than an arbitrary literal series.
    final bucketCount = periodDays == 7 ? 7 : 10;
    final bucketSpan = Duration(days: (periodDays / bucketCount).ceil());
    final dailySeries = List<num>.generate(bucketCount, (i) {
      final bucketEnd = now.subtract(bucketSpan * (bucketCount - 1 - i));
      final bucketStart = bucketEnd.subtract(bucketSpan);
      return current.where((h) => h.createdAt != null && h.createdAt!.isAfter(bucketStart) && !h.createdAt!.isAfter(bucketEnd)).length;
    });

    // Case-mix is no longer shown on-screen (matches the website dropping its
    // "Patient Case-Mix" widget) but the breakdown is still useful in the
    // exported PDF report, so the computation stays.
    final conditionCounts = <String, int>{};
    for (final h in current) {
      for (final d in h.diagnosis) {
        conditionCounts[d] = (conditionCounts[d] ?? 0) + 1;
      }
    }
    final topConditions = conditionCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Consultation mode split — real data already on each history record's
    // `mode` (set from the linked appointment's actual mode, not a guess).
    final videoCount = current.where((h) => h.mode == 'Video Consultation').length;
    final inPersonCount = current.length - videoCount;

    // Estimated earnings — the doctor's own configured consultation fee
    // (Profile › Consultation Settings) × completed consultations in this
    // period. Explicitly "estimated": there's no real billing/payout
    // backend behind this yet, so it must never be presented as an invoice.
    final feeRaw = app.doctorProfile?['consultationFeeInPerson'];
    final fee = feeRaw is num ? feeRaw.toDouble() : null;
    final estimatedEarnings = fee == null ? null : fee * consultations;

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Reports & Analytics', style: AppText.display(size: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Export as PDF',
            icon: const Icon(Icons.ios_share, size: 19),
            onPressed: () => _exportReport(
              app: app,
              patientsSeen: patientsSeen,
              consultations: consultations,
              prescriptionsGenerated: prescriptionsGenerated,
              noShowsToday: noShowsToday,
              videoCount: videoCount,
              inPersonCount: inPersonCount,
              estimatedEarnings: estimatedEarnings,
              topConditions: topConditions,
            ),
          ),
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
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // A fixed row height (rather than an aspect ratio) so a wrapped
            // 2-line label ("Prescriptions Generated") never pushes the
            // sparkline past the cell's bottom edge — that mismatch was
            // exactly what caused the reported overflow.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 140,
            ),
            children: [
              _StatCard(label: 'Patients Seen', value: '$patientsSeen', trend: _trendLabel(patientsSeen, patientsSeenPrev), spark: dailySeries),
              _StatCard(label: 'Consultations', value: '$consultations', trend: _trendLabel(consultations, consultationsPrev), spark: dailySeries),
              _StatCard(label: 'Prescriptions Generated', value: '$prescriptionsGenerated', trend: _trendLabel(prescriptionsGenerated, prescriptionsGeneratedPrev), spark: dailySeries),
              _StatCard(label: 'No-Shows Today', value: '$noShowsToday', trend: null, spark: null),
            ].animate(interval: 60.ms).fadeIn(duration: 260.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          ),
          const SizedBox(height: 20),

          Text('ESTIMATED EARNINGS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: fee == null
                ? Text(
                    'Set your consultation fee in Profile › Consultation Settings to see an earnings estimate.',
                    style: AppText.body(size: 12.5, color: AppColors.ink400),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹${estimatedEarnings!.toStringAsFixed(0)}', style: AppText.display(size: 22, color: AppColors.green600)),
                            const SizedBox(height: 2),
                            Text('$consultations consultation${consultations == 1 ? '' : 's'} × ₹${fee.toStringAsFixed(0)} fee', style: AppText.body(size: 11, color: AppColors.ink600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(100)),
                        child: Text('ESTIMATE', style: AppText.mono(size: 9, weight: FontWeight.bold, color: AppColors.amber600)),
                      ),
                    ],
                  ),
          ).animate().fadeIn(delay: 200.ms, duration: 280.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _exportReport({
    required AppState app,
    required int patientsSeen,
    required int consultations,
    required int prescriptionsGenerated,
    required int noShowsToday,
    required int videoCount,
    required int inPersonCount,
    required double? estimatedEarnings,
    required List<MapEntry<String, int>> topConditions,
  }) async {
    await ReportPdf.shareSummary(
      doctorName: app.doctorDisplayName,
      periodLabel: _range,
      stats: {
        'Patients Seen': '$patientsSeen',
        'Consultations': '$consultations',
        'Prescriptions Generated': '$prescriptionsGenerated',
        'No-Shows Today': '$noShowsToday',
        'Video Consultations': '$videoCount',
        'In-Person Consultations': '$inPersonCount',
        if (estimatedEarnings != null) 'Estimated Earnings': '₹${estimatedEarnings.toStringAsFixed(0)} (estimate)',
      },
      topConditions: topConditions,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.trend, required this.spark});
  final String label;
  final String value;
  /// `(label, isUp)` — null when there's no genuine trend to report yet.
  final (String, bool)? trend;
  final List<num>? spark;

  @override
  Widget build(BuildContext context) {
    final trendColor = trend == null ? AppColors.ink400 : (trend!.$2 ? AppColors.green600 : AppColors.red600);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadow.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(size: 9.5, weight: FontWeight.w700, color: AppColors.ink600)),
          const SizedBox(height: 4),
          Text(value, style: AppText.display(size: 18, color: AppColors.blue900)),
          const SizedBox(height: 2),
          Row(
            children: [
              if (trend != null) ...[
                Icon(trend!.$2 ? Icons.trending_up : Icons.trending_down, size: 12, color: trendColor),
                const SizedBox(width: 3),
              ],
              Expanded(
                child: Text(
                  trend?.$1 ?? 'Not enough data yet',
                  maxLines: 1,
                  style: AppText.body(size: 9, color: trendColor, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (spark != null) ...[
            const Spacer(),
            SizedBox(height: 22, child: Sparkline(values: spark!)),
          ],
        ],
      ),
    );
  }
}
