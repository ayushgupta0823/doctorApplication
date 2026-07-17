import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import 'consultation_settings_screen.dart';

/// Payment & Earnings: replaces the dead "Nothing here yet" placeholder.
/// There's no billing/payout backend behind this app yet, so rather than
/// fake one, this derives an honest *estimate* from real data already on
/// hand — the doctor's own configured consultation fee and their real
/// completed-consultation history (`AppState.patientHistory`) — the same
/// "derive from real data, label honestly" approach `ReportsAnalyticsScreen`
/// already uses for its estimated-earnings tile.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final feeRaw = app.doctorProfile?['consultationFeeInPerson'];
    final fee = feeRaw is num ? feeRaw.toDouble() : null;

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = now.subtract(const Duration(days: 30));
    final withDate = app.patientHistory.where((h) => h.createdAt != null);
    final thisWeek = withDate.where((h) => h.createdAt!.isAfter(weekStart)).length;
    final thisMonth = withDate.where((h) => h.createdAt!.isAfter(monthStart)).length;
    final allTime = app.patientHistory.length;

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Payment & Earnings', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR CONSULTATION FEE', style: AppText.mono(size: 9.5, color: AppColors.ink600, weight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(fee == null ? 'Not set' : '₹${fee.toStringAsFixed(0)}', style: AppText.display(size: 20, color: AppColors.blue900)),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Edit Fee',
                  variant: AppButtonVariant.ghost,
                  small: true,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConsultationSettingsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('ESTIMATED EARNINGS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(100)),
                child: Text('NOT BILLING DATA', style: AppText.mono(size: 8, weight: FontWeight.bold, color: AppColors.amber600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (fee == null)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Text('Set your consultation fee above to see earnings estimates.', style: AppText.body(size: 12.5, color: AppColors.ink400)),
            )
          else
            Row(
              children: [
                Expanded(child: _EarningsTile(label: 'This Week', count: thisWeek, fee: fee)),
                const SizedBox(width: 10),
                Expanded(child: _EarningsTile(label: 'This Month', count: thisMonth, fee: fee)),
                const SizedBox(width: 10),
                Expanded(child: _EarningsTile(label: 'All Time', count: allTime, fee: fee)),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppColors.blue700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is an estimate (fee × completed consultations) — real payouts and invoicing are not yet connected.',
                    style: AppText.body(size: 11, color: AppColors.blue700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.label, required this.count, required this.fee});
  final String label;
  final int count;
  final double fee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadow.sm),
      child: Column(
        children: [
          Text('₹${(fee * count).toStringAsFixed(0)}', style: AppText.mono(size: 15, weight: FontWeight.bold, color: AppColors.green600)),
          const SizedBox(height: 4),
          Text(label, style: AppText.body(size: 9.5, color: AppColors.ink600, weight: FontWeight.bold), textAlign: TextAlign.center),
          Text('$count consult${count == 1 ? '' : 's'}', style: AppText.body(size: 8.5, color: AppColors.ink400)),
        ],
      ),
    );
  }
}
