import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/prescription_pdf.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/avatar.dart';
import '../widgets/page_head.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_badge.dart';

/// Ported from `renderPatients()` — completed consultation history.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  int _visibleCount = 3; // Start with 3 items, reveal more on demand

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<AppState>().searchHistory(_searchController.text);
  }

  // The full history list is already loaded client-side (see
  // AppState.loadPatientHistory) — revealing more of it is instant, so this
  // doesn't fake a network round-trip with an artificial spinner.
  void _loadMore() => setState(() => _visibleCount += 3);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sel = app.selectedHistory;

    final historyList = app.patientHistory;
    final displayedList = historyList.take(_visibleCount).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        PageHead(
          eyebrow: 'History',
          title: 'My Patients',
          subtitle: '${app.patientHistory.length} completed consultations',
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by patient name or diagnosis...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (app.isLoadingHistory)
          const _HistorySkeleton()
        else if (displayedList.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No matching patient history found.',
                style: AppText.body(size: 13, color: AppColors.ink400),
              ),
            ),
          )
        else ...[
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line), bottom: BorderSide(color: AppColors.line)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < displayedList.length; i++)
                  _HistoryItem(patient: displayedList[i], active: displayedList[i].id == app.selectedHistoryId)
                      .animate(delay: (i * 40).ms)
                      .fadeIn(duration: 220.ms)
                      .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
              ],
            ),
          ),

          // Lazy load button
          if (historyList.length > _visibleCount)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: AppButton(
                label: 'Load More History',
                variant: AppButtonVariant.ghost,
                small: true,
                block: true,
                onPressed: _loadMore,
              ),
            ),
        ],

        if (sel == null)
          const SizedBox.shrink()
        else if (sel.diagnosis.isEmpty && !sel.soap.hasContent)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Center(
              child: Text(
                'No SOAP notes or transcript recorded for this session.',
                textAlign: TextAlign.center,
                style: AppText.body(size: 12.5, color: AppColors.ink400),
              ),
            ),
          )
        else
          _HistoryDetail(patient: sel),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.lineSoft))),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Row(
              children: [
                const SkeletonBox(width: 36, height: 36, shape: BoxShape.circle),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 130, height: 13),
                      SizedBox(height: 6),
                      SkeletonBox(width: 170, height: 11),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.patient, required this.active});
  final PatientHistory patient;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Material(
      color: active ? AppColors.blue50 : Colors.transparent,
      child: InkWell(
        onTap: () => app.selectHistory(patient.id),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(color: AppColors.lineSoft),
              left: BorderSide(color: active ? AppColors.blue600 : Colors.transparent, width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Row(
            children: [
              InitialsAvatar(name: patient.name, size: 36, fontSize: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                    Text(
                      '${patient.age} · ${patient.gender} · ${patient.mode} · ${patient.date}',
                      style: AppText.body(size: 11, color: AppColors.ink600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({required this.patient});
  final PatientHistory patient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(text: 'Diagnosis'),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: patient.diagnosis.isEmpty
                ? Text('No diagnosis code selected', style: AppText.body(size: 12, color: AppColors.ink400))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: patient.diagnosis.map((d) => AppChip(label: d)).toList(),
                  ),
          ),
          const SectionTitle(text: 'SOAP Notes'),
          _SoapView(label: 'Subjective', value: patient.soap.subjective, source: patient.soap.subjectiveSource),
          _SoapView(label: 'Objective', value: patient.soap.objective, source: patient.soap.objectiveSource),
          _SoapView(label: 'Assessment', value: patient.soap.assessment, source: patient.soap.assessmentSource),
          _SoapView(label: 'Plan', value: patient.soap.plan, source: patient.soap.planSource),
          const SizedBox(height: 4),
          const SectionTitle(text: 'Session Transcript'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: patient.transcript.isEmpty
                  ? Text('No transcript recorded.',
                      style: AppText.body(size: 11.5, color: AppColors.ink400))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: patient.transcript
                            .map((t) => _TranscriptLine(speaker: t.speaker, text: t.text))
                            .toList(),
                      ),
                    ),
            ),
          ),
          if (patient.rx != null) ...[
            const SizedBox(height: 14),
            const SectionTitle(text: 'Prescription Issued'),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const StatusBadge(status: ConsultStatus.completed),
                      if (patient.rx!.pdf)
                        AppButton(
                          label: 'PDF',
                          variant: AppButtonVariant.ghost,
                          small: true,
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            final app = context.read<AppState>();
                            try {
                              await PrescriptionPdf.openAndShare(
                                doctorName: app.doctorDisplayName,
                                nmcNumber: app.doctorNmcNumber,
                                signature: app.digitalSignature.isNotEmpty ? app.digitalSignature : app.doctorDisplayName,
                                patientName: patient.name,
                                patientAge: patient.age,
                                patientGender: patient.gender,
                                date: patient.date,
                                medicines: patient.rx!.medicines,
                                advisoryNote: '',
                                followUp: '-',
                                referral: 'None',
                                diagnosis: patient.diagnosis.isNotEmpty ? patient.diagnosis.first : null,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not open the prescription PDF — ${app.describeError(e)}'), backgroundColor: AppColors.red600),
                                );
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final m in patient.rx!.medicines)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.lineSoft)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: AppText.body(size: 12, color: AppColors.ink900),
                                children: [
                                  TextSpan(text: m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  TextSpan(text: ' · ${m.dosage} · ${m.freq}'),
                                ],
                              ),
                            ),
                          ),
                          if (m.aiSuggested)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.teal100, borderRadius: BorderRadius.circular(AppRadius.xs)),
                              child: Text('AI Suggestion', style: AppText.mono(size: 7.5, color: AppColors.tealDark, weight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoapView extends StatelessWidget {
  const _SoapView({required this.label, required this.value, required this.source});
  final String label;
  final String value;
  final String source;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final isAi = source == 'ai';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppText.mono(size: 10, weight: FontWeight.w700, color: AppColors.blue700)
                    .copyWith(letterSpacing: .3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isAi ? AppColors.teal100 : AppColors.green100,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  isAi ? 'AI Scribe' : 'Edited',
                  style: AppText.mono(size: 7.5, weight: FontWeight.bold, color: isAi ? AppColors.tealDark : AppColors.green600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: AppText.body(size: 12.5, color: AppColors.ink900)),
        ],
      ),
    );
  }
}

class _TranscriptLine extends StatelessWidget {
  const _TranscriptLine({required this.speaker, required this.text});
  final String speaker;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = speaker == 'doctor' ? AppColors.teal500 : AppColors.blue600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text.rich(
        TextSpan(
          style: AppText.body(size: 12, color: AppColors.ink900),
          children: [
            TextSpan(
              text: '${speaker.toUpperCase()}  ',
              style: AppText.mono(size: 10, weight: FontWeight.w600, color: color),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
