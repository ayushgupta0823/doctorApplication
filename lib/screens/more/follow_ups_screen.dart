import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../patient_details_screen.dart';

/// Patients from today's queue who need a follow-up: flagged risk tags or
/// a recent lab abnormality — the same real fields the Home dashboard's
/// "follow-up" count already reads, just given their own destination
/// instead of only summing to a number.
class FollowUpsScreen extends StatelessWidget {
  const FollowUpsScreen({super.key});

  bool _needsFollowUp(QueuePatient p) => p.riskSummary.tags.isNotEmpty || p.riskSummary.recentLabAbnormalities != 'None';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patients = app.queue.where((p) => p.status != ConsultStatus.completed && p.status != ConsultStatus.noShow && p.status != ConsultStatus.cancelled).where(_needsFollowUp).toList();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Follow-ups', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: patients.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.event_available_outlined,
                message: 'No patients in today\'s queue are flagged for a follow-up right now.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = patients[i];
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PatientDetailsScreen(patientId: p.id))),
                    child: Row(
                      children: [
                        InitialsAvatar(name: p.name, size: 40, fontSize: 13),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              if (p.riskSummary.recentLabAbnormalities != 'None')
                                Text('Lab: ${p.riskSummary.recentLabAbnormalities}', style: AppText.body(size: 11, color: AppColors.amberDark)),
                              if (p.riskSummary.tags.isNotEmpty)
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 4,
                                  children: p.riskSummary.tags
                                      .map((t) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(100)),
                                            child: Text(t, style: AppText.body(size: 9.5, weight: FontWeight.w700, color: AppColors.red600)),
                                          ))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
                      ],
                    ),
                  ),
                ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
              },
            ),
    );
  }
}
