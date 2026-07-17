import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/prescription_pdf.dart';
import '../../widgets/app_button.dart';
import '../../widgets/synced_text_field.dart';
import '../more/prescription_templates_screen.dart';

class PrescriptionTab extends StatelessWidget {
  const PrescriptionTab({super.key});

  Future<void> _insertFromTemplate(BuildContext context, AppState app) async {
    final templates = await loadPrescriptionTemplates();
    if (!context.mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved templates yet — add one from More → Prescription Templates.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<PrescriptionTemplate>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: templates
            .map((t) => ListTile(
                  title: Text(t.medicine.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                  subtitle: Text('${t.medicine.dosage} · ${t.medicine.freq} · ${t.medicine.duration}', style: AppText.body(size: 11, color: AppColors.ink600)),
                  onTap: () => Navigator.pop(ctx, t),
                ))
            .toList(),
      ),
    );
    if (picked != null) app.addMedFromTemplate(picked.medicine);
  }

  Future<void> _confirmSign(BuildContext context, AppState app) async {
    if (!app.hasValidMedicine) {
      app.setRxError('Add at least one named medicine before signing.');
      return;
    }
    app.setRxError('');

    final patient = app.activePatient;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Prescription?'),
        content: Text(
          'Do you authorize applying your digital signature to this prescription for ${patient?.name ?? "the patient"}? This action is legally binding and cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Prescription', style: AppText.body(weight: FontWeight.bold, color: AppColors.green600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.approveAndSign();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.prescriptionSent) return const _SignedOverlay();

    final interactions = app.getDrugInteractions();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.blue100, borderRadius: BorderRadius.circular(AppRadius.sm)),
                    child: const Icon(Icons.medication_outlined, size: 16, color: AppColors.blue700),
                  ),
                  const SizedBox(width: 8),
                  Text('Prescription Builder', style: AppText.display(size: 13.5)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TagButton(
                    label: '+ Template',
                    color: AppColors.blue700,
                    background: AppColors.blue100,
                    onPressed: () => _insertFromTemplate(context, app),
                  ),
                  const SizedBox(width: 8),
                  _TagButton(
                    label: app.aiPrescriptionLoading ? 'Suggesting…' : '+ AI Suggestion',
                    color: AppColors.tealDark,
                    background: AppColors.teal100,
                    loading: app.aiPrescriptionLoading,
                    onPressed: app.aiPrescriptionLoading ? null : app.requestAiPrescriptionSuggestion,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medicine Rows
          for (var i = 0; i < app.rxMedicines.length; i++)
            _MedRow(index: i)
                .animate(delay: (i * 40).ms)
                .fadeIn(duration: 220.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),

          AppButton(
            label: 'Add Medicine',
            variant: AppButtonVariant.ghost,
            icon: const Icon(Icons.add),
            block: true,
            onPressed: () => app.addMed(),
          ),
          const SizedBox(height: 16),

          // Drug Interactions Box
          if (interactions.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red100,
                border: Border.all(color: AppColors.red600.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadow.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.report_problem_rounded, size: 15, color: AppColors.red600),
                      const SizedBox(width: 6),
                      Text(
                        'DRUG INTERACTIONS DETECTED',
                        style: AppText.mono(size: 10, color: AppColors.red600, weight: FontWeight.bold).copyWith(letterSpacing: .3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: interactions
                        .map((i) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.55),
                                border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                i,
                                style: AppText.body(size: 11.5, color: AppColors.red600, weight: FontWeight.bold),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 220.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 12),
          ],

          Text('ADVISORY NOTE TO PATIENT',
              style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)
                  .copyWith(letterSpacing: .3)),
          const SizedBox(height: 4),
          SyncedTextField(
            value: app.rxNotes,
            hintText: 'Instructions for the patient…',
            minLines: 2,
            maxLines: 4,
            onChanged: app.setRxNotes,
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FollowUpDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _ReferralDropdown()),
            ],
          ),
          const SizedBox(height: 16),

          // Multi-step progress indicator
          if (app.prescriptionSending) ...[
            _SigningProgressIndicator(step: app.signingStep)
                .animate()
                .fadeIn(duration: 200.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 16),
          ],

          if (app.rxError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  border: Border.all(color: AppColors.red600.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [BoxShadow(color: AppColors.red600.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 15, color: AppColors.red600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(app.rxError, style: AppText.body(size: 11.5, color: AppColors.red600, weight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 180.ms).shake(hz: 3, curve: Curves.easeInOut),

          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Preview',
                  variant: AppButtonVariant.ghost,
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  onPressed: app.hasValidMedicine ? () => _previewPrescription(context, app) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Save Draft',
                  variant: AppButtonVariant.subtle,
                  icon: const Icon(Icons.save_outlined, size: 15),
                  onPressed: () {
                    app.logAuditEvent('Prescription draft saved');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Draft saved', style: AppText.body(size: 12.5, color: Colors.white, weight: FontWeight.bold)), backgroundColor: AppColors.blue700),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: app.prescriptionSending ? 'Signing...' : 'Sign & Send',
            variant: AppButtonVariant.success,
            icon: app.prescriptionSending ? null : const Icon(Icons.check_circle_outline),
            loading: app.prescriptionSending,
            block: true,
            onPressed: app.prescriptionSending ? null : () => _confirmSign(context, app),
          ),
        ],
      ),
    );
  }

  Future<void> _previewPrescription(BuildContext context, AppState app) async {
    final patient = app.activePatient;
    try {
      await PrescriptionPdf.openAndShare(
        doctorName: app.doctorDisplayName,
        nmcNumber: app.doctorNmcNumber,
        signature: app.digitalSignature.isNotEmpty ? app.digitalSignature : app.doctorDisplayName,
        patientName: patient?.name ?? 'Patient',
        patientAge: patient?.age ?? 0,
        patientGender: patient?.gender ?? '-',
        date: DateTime.now().toLocal().toString().split(' ').first,
        medicines: app.rxMedicines,
        advisoryNote: app.rxNotes,
        followUp: app.followUp,
        referral: app.referral,
        diagnosis: app.selectedIcd?.desc,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not preview the prescription PDF — ${app.describeError(e)}'), backgroundColor: AppColors.red600));
      }
    }
  }
}

/// Small pill-shaped action tag used for the "+ Template" / "+ AI
/// Suggestion" affordances above the medicine list — a tinted rounded
/// chip reads as an action shortcut more clearly than a bare TextButton.
class _TagButton extends StatelessWidget {
  const _TagButton({
    required this.label,
    required this.color,
    required this.background,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null && !loading ? .55 : 1,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.6, color: color)),
                  const SizedBox(width: 6),
                ],
                Text(label, style: AppText.mono(size: 10, weight: FontWeight.w700, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedRow extends StatelessWidget {
  const _MedRow({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final Medicine m = app.rxMedicines[index];

    final allergyWarnings = app.getWarningsForMed(m.name);
    final hasWarning = allergyWarnings.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: m.aiSuggested ? AppColors.teal100.withValues(alpha: 0.4) : AppColors.white,
        border: Border.all(
          color: hasWarning ? AppColors.red600 : (m.aiSuggested ? AppColors.teal500 : AppColors.line),
          width: m.aiSuggested || hasWarning ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: hasWarning
            ? [BoxShadow(color: AppColors.red600.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 4))]
            : AppShadow.sm,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Medicine name'),
              SyncedTextField(
                value: m.name,
                hintText: 'Drug name',
                onChanged: (v) => app.updateMedicineName(index, v),
              ),

              // Allergy warnings
              if (hasWarning)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.red100,
                    border: Border.all(color: AppColors.red600.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: allergyWarnings
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning, color: AppColors.red600, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      w,
                                      style: AppText.body(size: 11, color: AppColors.red600, weight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Dosage'),
                        SyncedTextField(
                          value: m.dosage,
                          hintText: 'e.g. 500mg',
                          onChanged: (v) => app.updateMedicineDosage(index, v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel('Duration (days)'),
                        SyncedTextField(
                          value: m.duration,
                          hintText: 'e.g. 7',
                          keyboardType: TextInputType.number,
                          onChanged: (v) => app.updateMedicineDuration(index, v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _fieldLabel('Dosage form'),
              DropdownButtonFormField<String>(
                initialValue: kDosageForms.contains(m.dosageForm) ? m.dosageForm : kDosageForms.first,
                isExpanded: true,
                items: kDosageForms
                    .map((f) => DropdownMenuItem(value: f, child: Text(f[0].toUpperCase() + f.substring(1))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) app.updateMedicineDosageForm(index, v);
                },
              ),
              const SizedBox(height: 8),
              _fieldLabel('Frequency / instructions'),
              SyncedTextField(
                value: m.freq,
                hintText: 'e.g. Twice daily after meals',
                onChanged: (v) => app.updateMedicineFreq(index, v),
              ),
            ],
          ),

          // AI badge label
          if (m.aiSuggested)
            Positioned(
              top: 0,
              right: app.rxMedicines.length > 1 ? 32 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.teal500,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [BoxShadow(color: AppColors.teal500.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 9, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      'AI SUGGESTION',
                      style: AppText.mono(size: 8, color: Colors.white, weight: FontWeight.bold).copyWith(letterSpacing: .2),
                    ),
                  ],
                ),
              ),
            ),

          if (app.rxMedicines.length > 1)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: AppColors.red100,
                borderRadius: BorderRadius.circular(100),
                child: InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: () => app.removeMed(index),
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(Icons.delete_outline, size: 15, color: AppColors.red600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text.toUpperCase(),
          style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)
              .copyWith(letterSpacing: .3),
        ),
      );
}

class _SigningProgressIndicator extends StatelessWidget {
  const _SigningProgressIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    String message = '';
    double value = 0.0;
    if (step == 1) {
      message = 'Transmitting draft prescription to server... [Step 1/3]';
      value = 0.33;
    } else if (step == 2) {
      message = 'Generating digitally signed PDF & ABDM reference... [Step 2/3]';
      value = 0.66;
    } else if (step == 3) {
      message = 'Completing consultation queue entry... [Step 3/3]';
      value = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blue100,
        border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var s = 1; s <= 3; s++) ...[
                _StepDot(active: s <= step),
                if (s != 3) Expanded(child: Container(height: 2, color: s < step ? AppColors.blue600 : AppColors.blue500.withValues(alpha: 0.25))),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppText.body(size: 11.5, weight: FontWeight.bold, color: AppColors.blue700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: value, minHeight: 6, color: AppColors.blue600, backgroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// One node in the sign/approve step tracker above the progress message.
class _StepDot extends StatelessWidget {
  const _StepDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.blue600 : Colors.white,
        border: Border.all(color: AppColors.blue600, width: active ? 0 : 1.4),
        boxShadow: active ? [BoxShadow(color: AppColors.blue600.withValues(alpha: 0.4), blurRadius: 4)] : null,
      ),
    );
  }
}

class _FollowUpDropdown extends StatelessWidget {
  static const options = ['7 Days', '14 Days', '1 Month', '3 Months', 'As needed'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return _LabeledDropdown(
      label: 'Follow-up',
      value: app.followUp,
      options: options,
      onChanged: app.setFollowUp,
    );
  }
}

class _ReferralDropdown extends StatelessWidget {
  static const options = [
    'None',
    'Cardiologist',
    'Neurologist',
    'Orthopaedician',
    'Dermatologist',
    'Psychiatrist',
    'ENT',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return _LabeledDropdown(
      label: 'Referral specialist',
      value: app.referral,
      options: options,
      onChanged: app.setReferral,
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label.toUpperCase(),
            style: AppText.body(size: 11, weight: FontWeight.w700, color: AppColors.ink600)
                .copyWith(letterSpacing: .3),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: AppText.body(size: 13, color: AppColors.ink900),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SignedOverlay extends StatelessWidget {
  const _SignedOverlay();

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final rnd = Random();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.md,
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.green100,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.green600.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.check_circle, size: 26, color: AppColors.green600),
                ),
                const SizedBox(height: 10),
                Text('Prescription signed', style: AppText.display(size: 16, color: AppColors.green600)),
                if (app.consultationCompletionFailed) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber100,
                      border: Border.all(color: AppColors.amberBorder),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.amberDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The prescription is signed, but marking the consultation complete did not sync with the server — check your connection and the queue status for this patient.',
                            style: AppText.body(size: 11, color: AppColors.amberDark, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // ABDM QR representation
                SizedBox(
                  width: 120,
                  height: 120,
                  child: GridView.count(
                    crossAxisCount: 10,
                    mainAxisSpacing: 1.5,
                    crossAxisSpacing: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(
                      100,
                      (_) => Container(
                        color: rnd.nextDouble() > 0.45 ? AppColors.blue900 : Colors.transparent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'ABDM-compliant digital signature token verified',
                  style: AppText.body(size: 10, color: AppColors.ink400, weight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Open Signed Prescription PDF',
                  variant: AppButtonVariant.ghost,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  block: true,
                  onPressed: () async {
                    final patient = app.activePatient;
                    try {
                      await PrescriptionPdf.openAndShare(
                        doctorName: app.doctorDisplayName,
                        nmcNumber: app.doctorNmcNumber,
                        signature: app.digitalSignature.isNotEmpty ? app.digitalSignature : app.doctorDisplayName,
                        patientName: patient?.name ?? 'Patient',
                        patientAge: patient?.age ?? 0,
                        patientGender: patient?.gender ?? '-',
                        date: DateTime.now().toLocal().toString().split(' ').first,
                        medicines: app.rxMedicines,
                        advisoryNote: app.rxNotes,
                        followUp: app.followUp,
                        referral: app.referral,
                        diagnosis: app.selectedIcd?.desc,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open the signed PDF — ${app.describeError(e)}'), backgroundColor: AppColors.red600),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Return to Queue',
            variant: AppButtonVariant.success,
            icon: const Icon(Icons.check_circle_outline),
            block: true,
            // Signing already completed the consultation (step 3 of
            // approveAndSign) — this just leaves the consult room.
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Issue New Prescription',
            variant: AppButtonVariant.subtle,
            block: true,
            onPressed: app.resetRx,
          ),
        ],
      ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
    );
  }
}
