import 'package:flutter/material.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/treasury_entry_item.dart';
import '../../services/pdf_service.dart';

class CollectionPdfActions extends StatefulWidget {
  const CollectionPdfActions({
    super.key,
    required this.entry,
    this.clientPhone,
    this.compact = false,
  });

  final TreasuryEntryItem entry;
  final String? clientPhone;
  final bool compact;

  @override
  State<CollectionPdfActions> createState() => _CollectionPdfActionsState();
}

class _CollectionPdfActionsState extends State<CollectionPdfActions> {
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
      () => pdfService.downloadCollectionPdf(widget.entry),
      successMessage: context.l10n.pdfSaved,
    );
  }

  Future<void> _shareWhatsApp() async {
    await _runPdfAction(
      () => pdfService.shareCollectionViaWhatsApp(
        widget.entry,
        clientPhone: widget.clientPhone ?? widget.entry.clientPhone,
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

    return Column(
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
    );
  }
}

Future<void> showCollectionShareDialog({
  required BuildContext context,
  required TreasuryEntryItem entry,
  String? clientPhone,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.shareInvoice),
      content: SingleChildScrollView(
        child: CollectionPdfActions(
          entry: entry,
          clientPhone: clientPhone,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ],
    ),
  );
}
