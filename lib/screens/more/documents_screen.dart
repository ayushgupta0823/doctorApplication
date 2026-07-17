import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/prescription_pdf.dart';
import '../../widgets/app_card.dart';
import 'lab_orders_screen.dart';
import 'prescriptions_sent_screen.dart';

/// One place for everything already real elsewhere in the app — signed
/// prescription PDFs and shared lab reports — rather than a separate
/// document-upload flow the backend has no route for.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

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
        title: Text('Documents', style: AppText.display(size: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(4),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.blue700),
              title: Text('Signed Prescriptions', style: AppText.body(size: 13, weight: FontWeight.bold)),
              subtitle: Text('${withRx.length} PDF(s) on file', style: AppText.body(size: 11, color: AppColors.ink600)),
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrescriptionsSentScreen())),
            ),
          ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: ListTile(
              leading: const Icon(Icons.biotech_outlined, color: AppColors.blue700),
              title: Text('Shared Lab Reports', style: AppText.body(size: 13, weight: FontWeight.bold)),
              subtitle: Text('Per-patient reports shared with you', style: AppText.body(size: 11, color: AppColors.ink600)),
              trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LabOrdersScreen())),
            ),
          ).animate(delay: 40.ms).fadeIn(duration: 240.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 20),
          if (withRx.isNotEmpty) ...[
            Text('RECENT PRESCRIPTIONS', style: AppText.mono(size: 10, color: AppColors.ink600, weight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...withRx.take(3).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: AppText.body(size: 13, weight: FontWeight.w700)),
                            Text(p.date, style: AppText.body(size: 11, color: AppColors.ink600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.blue700),
                        onPressed: () async {
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
                                SnackBar(content: Text('Could not open the PDF — ${app.describeError(e)}'), backgroundColor: AppColors.red600),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ).animate(delay: (i * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
            }),
          ],
        ],
      ),
    );
  }
}
