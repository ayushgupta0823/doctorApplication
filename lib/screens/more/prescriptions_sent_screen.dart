import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/prescription_pdf.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';

/// A real list of prescriptions this doctor has already signed, with
/// working PDF links — there's no backend endpoint for a pharmacy
/// directory (only a `hospital.type == 'pharmacy'` field exists, no list
/// route), so this replaces that placeholder with something genuinely
/// backed by data the app already has.
class PrescriptionsSentScreen extends StatelessWidget {
  const PrescriptionsSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final withRx = app.patientHistory.where((p) => p.rx != null).toList();

    return Scaffold(
      backgroundColor: AppColors.blue50,
      appBar: AppBar(
        backgroundColor: AppColors.blue50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.ink900), onPressed: () => Navigator.pop(context)),
        title: Text('Prescriptions Sent', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: withRx.isEmpty
          ? Center(child: EmptyState(icon: Icons.receipt_long_outlined, message: 'No prescriptions signed yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: withRx.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = withRx[i];
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      InitialsAvatar(name: p.name, size: 38, fontSize: 13),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                            Text('${p.date} · ${p.rx!.medicines.length} medicine(s)', style: AppText.body(size: 11, color: AppColors.ink600)),
                          ],
                        ),
                      ),
                      if (p.rx!.pdf)
                        IconButton(
                          tooltip: 'Open PDF',
                          icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.blue700),
                          onPressed: () => _openPdf(context, app, p),
                        )
                      else
                        Text('No PDF', style: AppText.body(size: 10.5, color: AppColors.ink400)),
                    ],
                  ),
                ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
              },
            ),
    );
  }

  Future<void> _openPdf(BuildContext context, AppState app, PatientHistory p) async {
    try {
      await PrescriptionPdf.openAndShare(
        doctorName: app.doctorDisplayName,
        nmcNumber: app.doctorNmcNumber,
        signature: app.digitalSignature.isNotEmpty ? app.digitalSignature : app.doctorDisplayName,
        patientName: p.name,
        patientAge: p.age,
        patientGender: p.gender,
        date: p.date,
        medicines: p.rx!.medicines,
        advisoryNote: '',
        followUp: '-',
        referral: 'None',
        diagnosis: p.diagnosis.isNotEmpty ? p.diagnosis.first : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the prescription PDF — ${app.describeError(e)}'), backgroundColor: AppColors.red600),
        );
      }
    }
  }
}
