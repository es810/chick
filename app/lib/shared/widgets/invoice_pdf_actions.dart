import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/invoice_model.dart';
import '../../services/pdf_service.dart';

class InvoicePdfActions extends StatefulWidget {
  const InvoicePdfActions({
    super.key,
    required this.invoice,
    this.clientPhone,
    this.compact = false,
  });

  final InvoiceModel invoice;
  final String? clientPhone;
  final bool compact;

  @override
  State<InvoicePdfActions> createState() => _InvoicePdfActionsState();
}

class _InvoicePdfActionsState extends State<InvoicePdfActions> {
  bool _isLoading = false;

  Future<void> _runPdfAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.pdfError}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _download() async {
    await _runPdfAction(
      () => pdfService.downloadPdf(widget.invoice),
      successMessage: context.l10n.pdfSaved,
    );
  }

  Future<void> _shareWhatsApp() async {
    await _runPdfAction(
      () => pdfService.shareViaWhatsApp(
        widget.invoice,
        clientPhone: widget.clientPhone,
      ),
      successMessage: context.l10n.pdfShared,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.generatingPdf),
          ],
        ),
      );
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.downloadPdf,
            onPressed: _download,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: l10n.shareWhatsApp,
            onPressed: _shareWhatsApp,
            icon: const Icon(Icons.chat, color: Color(PdfService.whatsAppGreen)),
          ),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.shareInvoice,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded),
              label: Text(l10n.downloadPdf),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _shareWhatsApp,
              icon: const Icon(Icons.chat, color: Colors.white),
              label: Text(l10n.shareWhatsApp),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(PdfService.whatsAppGreen),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
