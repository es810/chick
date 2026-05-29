import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/currency_formatter.dart';
import '../models/invoice_model.dart';

class PdfInvoiceResult {
  const PdfInvoiceResult({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

class PdfService {
  static const whatsAppGreen = 0xFF25D366;

  Future<PdfInvoiceResult> buildInvoicePdf(InvoiceModel invoice) async {
    final bytes = await generateInvoicePdf(invoice);
    final filename = '${invoice.invoiceNumber}.pdf';
    return PdfInvoiceResult(bytes: bytes, filename: filename);
  }

  Future<Uint8List> generateInvoicePdf(InvoiceModel invoice) async {
    final arabicRegular = await PdfGoogleFonts.notoSansArabicRegular();
    final arabicBold = await PdfGoogleFonts.notoSansArabicBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: arabicRegular,
        bold: arabicBold,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'إيصال توزيع',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'العميل: ${invoice.clientName ?? '—'}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'التاريخ: ${_formatDate(invoice.createdAt ?? DateTime.now())}',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 24),
              _receiptTable(invoice),
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'تم إنشاء هذا الإيصال تلقائياً بواسطة النظام',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ),
              if (invoice.invoiceNumber.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    invoice.invoiceNumber,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _receiptTable(InvoiceModel invoice) {
    final gross = invoice.displayGrossWeight;
    final tare = invoice.displayTareWeight;
    final net = invoice.netWeight;
    final price = invoice.pricePerKg;
    final mealTotal = invoice.totalPrice;
    final before = invoice.balanceBefore;
    final after = invoice.balanceAfter;

    final rows = <(String, String)>[
      ('العدد', '${invoice.itemCount}'),
      ('وزن القائم (كجم)', _num(gross)),
      ('الوزن الفارغ (كجم)', _num(tare)),
      ('الوزن الصافي (كجم)', _num(net)),
      ('السعر (ج.م / كجم)', _num(price)),
      ('حساب الوجبة (ج.م)', _num(mealTotal)),
    ];

    if (before != null) {
      rows.add(('المستحق القديم قبل الفاتورة (ج.م)', _num(before)));
    }
    if (after != null) {
      rows.add(('المستحق الجديد بعد الفاتورة (ج.م)', _num(after)));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableCell('البيان', bold: true),
            _tableCell('القيمة', bold: true),
          ],
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: [
              _tableCell(row.$1),
              _tableCell(row.$2, align: pw.TextAlign.left),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.right}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: pw.Align(
        alignment: align == pw.TextAlign.left ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _num(double value) => value.toStringAsFixed(2);

  /// Opens system share / save dialog (works on mobile & desktop).
  Future<void> downloadPdf(InvoiceModel invoice) async {
    final result = await buildInvoicePdf(invoice);
    await Printing.sharePdf(bytes: result.bytes, filename: result.filename);
  }

  Future<String> savePdfToDevice(InvoiceModel invoice) async {
    final result = await buildInvoicePdf(invoice);
    final directory = await _pdfDirectory();
    final file = File('${directory.path}/${result.filename}');
    await file.writeAsBytes(result.bytes, flush: true);
    return file.path;
  }

  Future<void> sharePdf(InvoiceModel invoice) async {
    final result = await buildInvoicePdf(invoice);
    final message = _shareMessage(invoice);
    await Share.shareXFiles(
      [
        XFile.fromData(
          result.bytes,
          mimeType: 'application/pdf',
          name: result.filename,
        ),
      ],
      text: message,
      subject: result.filename,
    );
  }

  Future<void> shareViaWhatsApp(InvoiceModel invoice, {String? clientPhone}) async {
    final result = await buildInvoicePdf(invoice);
    final message = _shareMessage(invoice);
    final file = XFile.fromData(
      result.bytes,
      mimeType: 'application/pdf',
      name: result.filename,
    );

    if (!kIsWeb && clientPhone != null && clientPhone.trim().isNotEmpty) {
      final phone = clientPhone.replaceAll(RegExp(r'\D'), '');
      final waTextUri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(waTextUri)) {
        await Share.shareXFiles([file], text: message, subject: result.filename);
        return;
      }
    }

    await Share.shareXFiles(
      [file],
      text: message,
      subject: result.filename,
    );
  }

  Future<Directory> _pdfDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      final downloads = await getExternalStorageDirectory();
      if (downloads != null) {
        final invoicesDir = Directory('${downloads.path}/invoices');
        if (!await invoicesDir.exists()) {
          await invoicesDir.create(recursive: true);
        }
        return invoicesDir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${docs.path}/invoices');
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }
    return invoicesDir;
  }

  String _shareMessage(InvoiceModel invoice) {
    final total = CurrencyFormatter.format(invoice.totalPrice, languageCode: 'ar');
    return 'إيصال توزيع ${invoice.invoiceNumber}\n'
        'العميل: ${invoice.clientName ?? ''}\n'
        'حساب الوجبة: $total';
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

final pdfService = PdfService();
