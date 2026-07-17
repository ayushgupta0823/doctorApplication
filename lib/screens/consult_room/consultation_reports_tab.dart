import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

/// Reports tab within the Consult Room — the active patient's lab
/// abnormalities and ordered tests, at a glance during the visit.
class ConsultationReportsTab extends StatelessWidget {
  const ConsultationReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.activePatient;
    if (patient == null) return const SizedBox.shrink();
    final orders = app.labTestsFor(patient.id);
    final hasAbnormalities = patient.riskSummary.recentLabAbnormalities.isNotEmpty && patient.riskSummary.recentLabAbnormalities != 'None';

    if (!hasAbnormalities && orders.isEmpty) {
      return Center(child: Text('No reports on file for this consultation.', style: AppText.body(size: 12.5, color: AppColors.ink400)));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (hasAbnormalities)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.amber100, shape: BoxShape.circle),
                  child: const Icon(Icons.science_outlined, size: 18, color: AppColors.amber600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Lab Abnormalities', style: AppText.body(size: 12.5, weight: FontWeight.bold)),
                      Text(patient.riskSummary.recentLabAbnormalities, style: AppText.body(size: 12, color: AppColors.ink600)),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
        for (var i = 0; i < orders.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadow.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Icon(Icons.biotech_outlined, size: 15, color: AppColors.blue600),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(orders[i].name, style: AppText.body(size: 12.5, weight: FontWeight.w600))),
                Text(orders[i].status, style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.ink600)),
              ],
            ),
          ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
      ],
    );
  }
}
