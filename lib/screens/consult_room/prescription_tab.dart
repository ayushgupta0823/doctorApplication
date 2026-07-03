import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/prescription_pdf.dart';
import '../../widgets/app_button.dart';
import '../../widgets/synced_text_field.dart';

class PrescriptionTab extends StatelessWidget {
  const PrescriptionTab({super.key});

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
                  const Icon(Icons.medication_outlined, size: 18, color: AppColors.ink900),
                  const SizedBox(width: 6),
                  Text('Prescription Builder', style: AppText.display(size: 13.5)),
                ],
              ),
              TextButton(
                onPressed: app.aiPrescriptionLoading ? null : app.requestAiPrescriptionSuggestion,
                child: Text(
                  app.aiPrescriptionLoading ? 'Suggesting…' : '+ AI Suggestion',
                  style: AppText.mono(size: 10, color: AppColors.tealDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Medicine Rows
          for (var i = 0; i < app.rxMedicines.length; i++) _MedRow(index: i),

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
            Text(
              'DRUG INTERACTIONS DETECTED',
              style: AppText.mono(size: 10, color: AppColors.red600, weight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Column(
              children: interactions
                  .map((i) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.red100,
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
            _SigningProgressIndicator(step: app.signingStep),
            const SizedBox(height: 16),
          ],

          if (app.rxError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  border: Border.all(color: AppColors.red600.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(app.rxError, style: AppText.body(size: 11.5, color: AppColors.red600, weight: FontWeight.bold)),
              ),
            ),

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not preview PDF: $e'), backgroundColor: AppColors.red600));
      }
    }
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.aiSuggested ? AppColors.teal100.withValues(alpha: 0.4) : AppColors.white,
        border: Border.all(
          color: allergyWarnings.isNotEmpty
              ? AppColors.red600
              : (m.aiSuggested ? AppColors.teal500 : AppColors.line),
          width: m.aiSuggested || allergyWarnings.isNotEmpty ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
              if (allergyWarnings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: allergyWarnings
                        .map((w) => Row(
                              children: [
                                const Icon(Icons.warning, color: AppColors.red600, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    w,
                                    style: AppText.body(size: 11, color: AppColors.red600, weight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
                          onChanged: (v) => app.updateMedicineDuration(index, v),
                        ),
                      ],
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal500,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI SUGGESTION',
                  style: AppText.mono(size: 8, color: Colors.white, weight: FontWeight.bold),
                ),
              ),
            ),

          if (app.rxMedicines.length > 1)
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: AppColors.red100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blue100,
        border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          LinearProgressIndicator(value: value, color: AppColors.blue600, backgroundColor: Colors.white),
        ],
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 20, color: AppColors.green600),
                    const SizedBox(width: 6),
                    Text('Prescription signed', style: AppText.display(size: 16, color: AppColors.green600)),
                  ],
                ),
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
                          SnackBar(content: Text('Could not open PDF: $e'), backgroundColor: AppColors.red600),
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
      ),
    );
  }
}
