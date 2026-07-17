import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

const _commonLabTests = [
  'Complete Blood Count (CBC)',
  'Blood Sugar (Fasting)',
  'Lipid Profile',
  'Liver Function Test',
  'Kidney Function Test',
  'Thyroid Profile (T3/T4/TSH)',
  'HbA1c',
  'Chest X-Ray',
];

class LabTestsTab extends StatelessWidget {
  const LabTestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.activePatient;
    if (patient == null) return const SizedBox.shrink();
    final orders = app.labTestsFor(patient.id);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.biotech_outlined, size: 16, color: AppColors.blue700),
              ),
              const SizedBox(width: 8),
              Text('Lab Tests', style: AppText.display(size: 13.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text('ORDER A TEST', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold).copyWith(letterSpacing: .3)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonLabTests
                .map((t) => ActionChip(
                      label: Text(t, style: AppText.body(size: 11)),
                      avatar: const Icon(Icons.add, size: 14, color: AppColors.blue600),
                      backgroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100), side: const BorderSide(color: AppColors.line)),
                      onPressed: () => app.orderLabTest(patient.id, t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 22),
          Text('ORDERED TESTS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold).copyWith(letterSpacing: .3)),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 18, color: AppColors.ink400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('No lab tests ordered for this consultation yet.', style: AppText.body(size: 12.5, color: AppColors.ink400)),
                  ),
                ],
              ),
            )
          else
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
                      decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Icon(Icons.science_outlined, size: 15, color: AppColors.amber600),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(orders[i].name, style: AppText.body(size: 12.5, weight: FontWeight.w600))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.amber100, borderRadius: BorderRadius.circular(100)),
                      child: Text(orders[i].status, style: AppText.body(size: 10, weight: FontWeight.w700, color: AppColors.amber600)),
                    ),
                  ],
                ),
              ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
        ],
      ),
    );
  }
}
