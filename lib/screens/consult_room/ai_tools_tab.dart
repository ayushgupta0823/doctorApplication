import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/sparkline_painter.dart';
import '../../widgets/synced_text_field.dart';

class AiToolsTab extends StatefulWidget {
  const AiToolsTab({super.key});

  @override
  State<AiToolsTab> createState() => _AiToolsTabState();
}

class _RootWarningBox extends StatelessWidget {
  const _RootWarningBox({required this.allergies});
  final List<String> allergies;

  @override
  Widget build(BuildContext context) {
    if (allergies.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red100,
        border: Border.all(color: AppColors.red600, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_bad, color: AppColors.red600, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CRITICAL ALLERGY ALERT',
                  style: AppText.mono(size: 11, color: AppColors.red600, weight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Patient is allergic to: ${allergies.join(', ')}. Avoid prescribing these medications.',
                  style: AppText.body(size: 12.5, color: AppColors.ink900, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiToolsTabState extends State<AiToolsTab> {
  Timer? _debounce;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _searchController.text = app.icdQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, AppState app) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      app.setIcdQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final patient = app.activePatient;

    if (patient == null) {
      return const SizedBox.shrink();
    }

    final Iterable<IcdCode> icdMatches = app.icdQuery.trim().isEmpty
        ? const <IcdCode>[]
        : MockData.icdDb.where((c) =>
            c.desc.toLowerCase().contains(app.icdQuery.toLowerCase()) ||
            c.code.toLowerCase().contains(app.icdQuery.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // High visibility allergy alert box
        _RootWarningBox(allergies: patient.riskSummary.allergies),

        // AI SOAP panel
        Container(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.teal100,
            border: Border.all(color: AppColors.teal500),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppColors.tealDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'AI SOAP Scribe',
                      style: AppText.display(size: 14.5, color: AppColors.tealDark),
                    ),
                  ),
                  AppButton(
                    label: app.aiGenerating
                        ? 'Scribing...'
                        : (app.aiGenerated ? 'Re-generate' : 'Generate SOAP'),
                    small: true,
                    loading: app.aiGenerating,
                    variant: app.aiGenerated ? AppButtonVariant.ghost : AppButtonVariant.primary,
                    onPressed: app.aiGenerating ? null : app.generateSummary,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar if Scribing
              if (app.aiGenerating) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(color: AppColors.teal500, backgroundColor: Colors.white),
                ),
                const SizedBox(height: 6),
              ],

              // Failure text — real request failure, not a simulation
              if (!app.aiGenerating && app.aiError != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: AppColors.red100, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      Text(
                        '⚠️ SOAP scribe request failed: ${app.aiError}',
                        style: AppText.body(size: 11.5, color: AppColors.red600, weight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      AppButton(
                        label: 'Retry NLP Generation',
                        small: true,
                        block: true,
                        onPressed: app.generateSummary,
                      ),
                    ],
                  ),
                ),

              if (app.aiSummary.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    app.aiSummary,
                    style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.tealDark),
                  ),
                ),

              _SoapField(
                label: 'Subjective',
                source: app.soap.subjectiveSource,
                value: app.soap.subjective,
                hint: 'Patient-reported symptoms…',
                onChanged: app.updateSoapSubjective,
              ),
              _SoapField(
                label: 'Objective',
                source: app.soap.objectiveSource,
                value: app.soap.objective,
                hint: 'Clinical observations, vitals…',
                onChanged: app.updateSoapObjective,
              ),
              _SoapField(
                label: 'Assessment',
                source: app.soap.assessmentSource,
                value: app.soap.assessment,
                hint: 'Working diagnosis…',
                onChanged: app.updateSoapAssessment,
              ),
              _SoapField(
                label: 'Plan',
                source: app.soap.planSource,
                value: app.soap.plan,
                hint: 'Treatment steps, follow-up…',
                onChanged: app.updateSoapPlan,
              ),
            ],
          ),
        ),

        // Vitals Sparklines (Patient specific) — the appointment list doesn't
        // carry a vitals trend (that would need a separate per-patient lab
        // trends call), so this section only renders once there's data to
        // show rather than crashing on an empty series.
        if (patient.vitals.bp.isNotEmpty && patient.vitals.hr.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: _SparkCard(
                    label: 'BP Systolic',
                    value: '${patient.vitals.bp.last} mmHg',
                    values: patient.vitals.bp,
                    dates: patient.vitals.bpDates,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SparkCard(
                    label: 'Heart Rate',
                    value: '${patient.vitals.hr.last} bpm',
                    values: patient.vitals.hr,
                    dates: patient.vitals.hrDates,
                  ),
                ),
              ],
            ),
          ),

        // ICD-10 Search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, size: 16, color: AppColors.ink900),
                  const SizedBox(width: 6),
                  Text('ICD-10 Code Lookup', style: AppText.display(size: 13.5)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search condition or code…',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (v) => _onSearchChanged(v, app),
              ),
              const SizedBox(height: 6),

              // Match list
              if (app.icdQuery.isNotEmpty) ...[
                if (icdMatches.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'No matching ICD-10 codes found in database.',
                      style: AppText.body(size: 12, color: AppColors.ink400),
                    ),
                  )
                else
                  ...icdMatches.take(5).map((c) => Container(
                        margin: const EdgeInsets.only(top: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: () {
                              app.pickIcd(c.code);
                              _searchController.clear();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        style: AppText.body(size: 12, color: AppColors.ink900),
                                        children: [
                                          TextSpan(
                                            text: '${c.code}  ',
                                            style: AppText.mono(size: 12, weight: FontWeight.w600, color: AppColors.blue700),
                                          ),
                                          TextSpan(text: c.desc),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.add, size: 16, color: AppColors.blue600),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )),
              ],

              if (app.selectedIcd != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.blue100,
                      border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 14, color: AppColors.blue700),
                        const SizedBox(width: 6),
                        Text.rich(
                          TextSpan(
                            style: AppText.body(size: 11.5, weight: FontWeight.w600, color: AppColors.blue700),
                            children: [
                              TextSpan(
                                text: '${app.selectedIcd!.code}  ',
                                style: AppText.mono(size: 11.5, weight: FontWeight.w700, color: AppColors.blue700),
                              ),
                              TextSpan(text: app.selectedIcd!.desc),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Risk summary details
        AppCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_shared_outlined, size: 16, color: AppColors.ink900),
                  const SizedBox(width: 6),
                  Text('Patient History & Risks', style: AppText.display(size: 13.5)),
                ],
              ),
              const SizedBox(height: 8),
              _RiskRow(
                label: 'Risk tags',
                child: patient.riskSummary.tags.isEmpty
                    ? Text('No active flags', style: AppText.body(size: 12, color: AppColors.ink400))
                    : Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        alignment: WrapAlignment.end,
                        children: patient.riskSummary.tags.map((t) => _Tag(t, AppColors.red100, AppColors.red600)).toList(),
                      ),
              ),
              _RiskRow(
                label: 'Allergies',
                child: patient.riskSummary.allergies.isEmpty
                    ? Text('No known drug allergies', style: AppText.body(size: 12, color: AppColors.green600, weight: FontWeight.bold))
                    : Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        alignment: WrapAlignment.end,
                        children: patient.riskSummary.allergies
                            .map((t) => _Tag(t, AppColors.red100, AppColors.red600))
                            .toList(),
                      ),
              ),
              _RiskRow(
                label: 'Comorbidities',
                child: Text(
                  patient.riskSummary.comorbidities.isEmpty
                      ? 'None reported'
                      : patient.riskSummary.comorbidities.join(', '),
                  textAlign: TextAlign.right,
                  style: AppText.body(size: 12),
                ),
              ),
              _RiskRow(
                label: 'Recent lab abnormalities',
                child: Text(
                  patient.riskSummary.recentLabAbnormalities,
                  textAlign: TextAlign.right,
                  style: AppText.body(size: 12, color: patient.riskSummary.recentLabAbnormalities == 'None' ? AppColors.ink900 : AppColors.amberDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoapField extends StatelessWidget {
  const _SoapField({
    required this.label,
    required this.source,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final String source;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isAi = source == 'ai';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: AppText.mono(size: 10, weight: FontWeight.w700, color: AppColors.tealDark)
                    .copyWith(letterSpacing: .3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isAi ? AppColors.teal100 : AppColors.green100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isAi ? AppColors.teal500 : AppColors.green600, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAi ? Icons.auto_awesome : Icons.edit,
                      size: 9,
                      color: isAi ? AppColors.tealDark : AppColors.green600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isAi ? 'AI Scribe' : 'Edited',
                      style: AppText.mono(
                        size: 8,
                        weight: FontWeight.bold,
                        color: isAi ? AppColors.tealDark : AppColors.green600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SyncedTextField(
            value: value,
            minLines: 2,
            maxLines: 4,
            style: AppText.body(size: 12),
            hintText: hint,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SparkCard extends StatelessWidget {
  const _SparkCard({required this.label, required this.value, required this.values, required this.dates});
  final String label;
  final String value;
  final List<int> values;
  final List<String> dates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: AppText.body(size: 10.5, weight: FontWeight.w700, color: AppColors.ink600)),
          const SizedBox(height: 2),
          Text(value, style: AppText.mono(size: 14, weight: FontWeight.w600, color: AppColors.blue900)),
          const SizedBox(height: 6),
          Sparkline(values: values),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: dates
                .map((d) => Text(d, style: AppText.mono(size: 8, weight: FontWeight.w500, color: AppColors.ink400)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.ink600)),
          const Spacer(),
          Flexible(flex: 3, child: Align(alignment: Alignment.centerRight, child: child)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: AppText.body(size: 10, weight: FontWeight.w700, color: fg)),
    );
  }
}
