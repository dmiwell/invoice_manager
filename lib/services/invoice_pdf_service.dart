import 'dart:io';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../repositories/app_repository.dart';
import 'markdown_pdf_builder.dart';

class InvoicePdfService {
  static Future<void> exportInvoicePdf(Invoice invoice, AppRepository repo) async {
    final bytes = await generatePdfBytes(invoice);

    if (kIsWeb) {
      await _savePdfWeb(bytes, invoice.displayId);
    } else {
      await _savePdfDesktop(bytes, invoice.id);
    }
  }

  static Future<Uint8List> generatePdfBytes(Invoice invoice) async {
    final pdf = await _generatePdfDocument(invoice);
    return pdf.save();
  }

  static Future<pw.Document> _generatePdfDocument(Invoice invoice) async {
    final pdf = pw.Document();

    final contract = invoice.contract;
    final contractor = contract.contractor;
    final company = contract.company;

    final dateFormat = DateFormat('dd MMMM yyyy', contract.locale);

    const tableCornerRadius = 8.0;

    final currencyPrefix = company.currencyPrefix ?? '\$';
    final currencyFormat = NumberFormat.currency(
      symbol: currencyPrefix,
      decimalDigits: 2,
    );

    pw.Widget infoRow(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              '$label: ',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.Text(value, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ],
        ),
      );
    }

    pw.Widget card({required String title, required List<pw.Widget> children}) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              title,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
          ],
        ),
      );
    }

    final itemColumnWidths = <int, pw.TableColumnWidth>{};
    {
      var col = 0;
      itemColumnWidths[col++] = const pw.FlexColumnWidth(3);
      if (contract.showPeriod) itemColumnWidths[col++] = const pw.FlexColumnWidth(1.2);
      if (!contract.fixed) {
        itemColumnWidths[col++] = const pw.FlexColumnWidth(0.75);
        itemColumnWidths[col++] = const pw.FlexColumnWidth(0.9);
      }
      itemColumnWidths[col] = const pw.FlexColumnWidth(1.3);
    }

    var myTheme = pw.ThemeData.withFont(
      base: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf')),
      italic: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Italic.ttf')),
      boldItalic: pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-BoldItalic.ttf')),
    );

    pdf.addPage(
      pw.Page(
        theme: myTheme,
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header — mirrors the invoice details panel layout
              pw.Text(
                contract.invoiceTitleOrDefault,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              infoRow(contract.invoiceIdLabelOrDefault, invoice.displayId),
              infoRow(contract.dateLabelOrDefault, dateFormat.format(invoice.date)),
              infoRow(contract.dueDateLabelOrDefault, dateFormat.format(invoice.dueDate)),
              infoRow('Contract', contract.reference(dateFormat)),
              pw.SizedBox(height: 24),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: card(
                      title: contract.contractorRoleSublabelOrDefault,
                      children: [
                        pw.Text(
                          contractor.fullName,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        if (contract.description != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(contract.description!),
                        ],
                        pw.SizedBox(height: 12),
                        MarkdownPdfBuilder(
                          text: contractor.contractorInfo ?? '',
                          linkColor: PdfColors.blue700,
                        ).build(),
                        if (contractor.signature != null) ...[
                          pw.SizedBox(height: 12),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Signature: ',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Image(
                                pw.MemoryImage(contractor.signature!),
                                height: 36,
                                fit: pw.BoxFit.contain,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: card(
                      title: 'Client',
                      children: [
                        pw.Text(
                          company.name,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 12),
                        MarkdownPdfBuilder(
                          text: company.companyInfo ?? '',
                          linkColor: PdfColors.blue700,
                        ).build(),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(tableCornerRadius)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey300, width: 1),
                  ),
                  columnWidths: itemColumnWidths,
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: const pw.BorderRadius.only(
                          topLeft: const pw.Radius.circular(tableCornerRadius),
                          topRight: const pw.Radius.circular(tableCornerRadius),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            contract.descriptionLabelOrDefault,
                            style: pw.TextStyle(fontWeight: .bold),
                          ),
                        ),
                        if (contract.showPeriod)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              contract.periodLabelOrDefault,
                              style: pw.TextStyle(fontWeight: .bold),
                            ),
                          ),
                        if (!contract.fixed) ...[
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              contract.qtyLabelOrDefault,
                              style: pw.TextStyle(fontWeight: .bold),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              contract.priceLabelOrDefault,
                              style: pw.TextStyle(fontWeight: .bold),
                            ),
                          ),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            contract.amountLabelOrDefault,
                            style: pw.TextStyle(fontWeight: .bold),
                          ),
                        ),
                      ],
                    ),
                    ...invoice.items.map((item) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              item.description,
                            ),
                          ),
                          if (contract.showPeriod)
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                item.period ?? '',
                              ),
                            ),
                          if (!contract.fixed) ...[
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                item.quantityDisplay,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                currencyFormat.format(item.price),
                              ),
                            ),
                          ],
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              currencyFormat.format(item.totalAmount),
                            ),
                          ),
                        ],
                      );
                    }),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: const pw.BorderRadius.only(
                          bottomLeft: const pw.Radius.circular(tableCornerRadius),
                          bottomRight: const pw.Radius.circular(tableCornerRadius),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            contract.totalLabelOrDefault,
                            style: pw.TextStyle(fontWeight: .bold),
                          ),
                        ),
                        if (contract.showPeriod)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(''),
                          ),
                        if (!contract.fixed) ...[
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(''),
                          ),
                        ],
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            currencyFormat.format(invoice.totalAmount),
                            style: pw.TextStyle(fontWeight: .bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              MarkdownPdfBuilder(
                text: contractor.paymentInfo ?? '',
                linkColor: PdfColors.blue700,
              ).build(),
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 8),
              MarkdownPdfBuilder(
                fontSize: 10,
                text: contract.footnoteOrDefault,
                linkColor: PdfColors.blue700,
              ).build(),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> _savePdfWeb(Uint8List bytes, String invoiceId) async {
    await FileSaver.instance.saveFile(name: invoiceId, bytes: bytes, mimeType: MimeType.pdf);
  }

  static Future<void> _savePdfDesktop(Uint8List bytes, String invoiceId) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '$invoiceId.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
  }
}
