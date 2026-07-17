import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds a one-page PDF snapshot of the Reports & Analytics screen and
/// opens the system print/share sheet — the same on-device-only pattern
/// `PrescriptionPdf` already uses, reused here instead of a new approach.
class ReportPdf {
  ReportPdf._();

  static Future<void> shareSummary({
    required String doctorName,
    required String periodLabel,
    required Map<String, String> stats,
    required List<MapEntry<String, int>> topConditions,
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
              pw.Text('MediConnectAI', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text('Reports & Analytics — $periodLabel', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 2),
              pw.Text(doctorName, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1.2),
              pw.SizedBox(height: 10),
              pw.Text('Summary', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1.4)},
                children: [
                  for (final entry in stats.entries)
                    pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.key, style: const pw.TextStyle(fontSize: 10.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(entry.value, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold))),
                    ]),
                ],
              ),
              if (topConditions.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text('Top Conditions', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                for (final c in topConditions.take(5))
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Text('${c.key} — ${c.value}', style: const pw.TextStyle(fontSize: 11)),
                  ),
              ],
              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.Text(
                'Generated on-device from your consultation history. Not a billing document.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
