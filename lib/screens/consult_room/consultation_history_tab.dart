import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

/// History tab within the Consult Room — this patient's past consultation
/// records, so the doctor doesn't have to leave the active session to
/// check what happened last time.
class ConsultationHistoryTab extends StatelessWidget {
  const ConsultationHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.activePatient;
    if (patient == null) return const SizedBox.shrink();
    final records = app.patientHistory.where((h) => h.name == patient.name).toList();

    if (records.isEmpty) {
      return Center(child: Text('No past consultations recorded for ${patient.name}.', style: AppText.body(size: 12.5, color: AppColors.ink400)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: records.length,
      itemBuilder: (context, i) {
        final r = records[i];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(100)),
                    child: Text(r.date, style: AppText.mono(size: 10.5, weight: FontWeight.w700, color: AppColors.blue700)),
                  ),
                  if (r.diagnosis.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.diagnosis.first,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 11, color: AppColors.ink600),
                      ),
                    ),
                  ],
                ],
              ),
              if (r.soap.assessment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(r.soap.assessment, style: AppText.body(size: 12)),
              ],
            ],
          ),
        ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
      },
    );
  }
}
