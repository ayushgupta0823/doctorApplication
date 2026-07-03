import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';

/// Builds a real, locally-rendered PDF for a signed prescription and opens
/// the system print/share sheet so the doctor can view, save, or send it.
///
/// This does not talk to a server — there's no backend issuing a signed
/// document URL yet — but the PDF itself is a genuine file generated on
/// the device, not a placeholder.
class PrescriptionPdf {
  PrescriptionPdf._();

  static Future<void> openAndShare({
    required String doctorName,
    required String nmcNumber,
    required String signature,
    required String patientName,
    required int patientAge,
    required String patientGender,
    required String date,
    required List<Medicine> medicines,
    required String advisoryNote,
    required String followUp,
    required String referral,
    String? diagnosis,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MediConnectAI',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Digital Prescription', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                  pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 1.2),
              pw.SizedBox(height: 8),
              pw.Text('Doctor', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(doctorName, style: const pw.TextStyle(fontSize: 12)),
              pw.Text('NMC Reg. No: $nmcNumber', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Text('Patient', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('$patientName  ($patientAge yrs, $patientGender)',
                  style: const pw.TextStyle(fontSize: 12)),
              if (diagnosis != null && diagnosis.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('Diagnosis', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(diagnosis, style: const pw.TextStyle(fontSize: 12)),
              ],
              pw.SizedBox(height: 16),
              pw.Text('Rx', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(2.5),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Medicine', bold: true),
                      _cell('Dosage', bold: true),
                      _cell('Frequency', bold: true),
                      _cell('Duration', bold: true),
                    ],
                  ),
                  for (final m in medicines)
                    pw.TableRow(children: [
                      _cell(m.name + (m.aiSuggested ? ' (AI-suggested)' : '')),
                      _cell(m.dosage),
                      _cell(m.freq),
                      _cell(m.duration.isEmpty ? '-' : '${m.duration} days'),
                    ]),
                ],
              ),
              if (advisoryNote.trim().isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text('Advisory Note', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text(advisoryNote, style: const pw.TextStyle(fontSize: 11)),
              ],
              pw.SizedBox(height: 10),
              pw.Text('Follow-up: $followUp', style: const pw.TextStyle(fontSize: 11)),
              if (referral != 'None') pw.Text('Referral: $referral', style: const pw.TextStyle(fontSize: 11)),
              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ABDM reference: pending backend integration',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(signature,
                          style: pw.TextStyle(fontSize: 16, fontStyle: pw.FontStyle.italic)),
                      pw.Text('Digitally signed', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }
}
