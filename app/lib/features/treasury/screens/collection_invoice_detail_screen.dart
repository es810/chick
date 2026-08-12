import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/treasury_entry_item.dart';
import '../../../shared/widgets/collection_pdf_actions.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../widgets/collection_invoice_form.dart';

class CollectionInvoiceDetailScreen extends ConsumerStatefulWidget {
  const CollectionInvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.basePath = '/admin',
  });

  final String invoiceId;
  final String basePath;

  @override
  ConsumerState<CollectionInvoiceDetailScreen> createState() =>
      _CollectionInvoiceDetailScreenState();
}

class _CollectionInvoiceDetailScreenState
    extends ConsumerState<CollectionInvoiceDetailScreen> {
  TreasuryEntryItem? _entry;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entry =
          await ref.read(collectionRepositoryProvider).getInvoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _entry = entry;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _refreshRelated() async {
    ref.invalidate(treasurySummaryProvider);
    ref.invalidate(clientsProvider);
    ref.invalidate(dashboardProvider);
    if (_entry?.clientId != null) {
      ref.invalidate(clientStatementProvider(_entry!.clientId!));
    }
  }

  Future<void> _edit() async {
    final existing = _entry;
    if (existing == null || _busy) return;
    final l10n = context.l10n;
    final saved = await showCollectionInvoiceDialog(
      context: context,
      ref: ref,
      existing: existing,
    );
    if (saved == null || !mounted) return;
    setState(() => _entry = saved);
    await _refreshRelated();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.entryUpdated), backgroundColor: AppColors.success),
    );
  }

  Future<void> _confirmDelete() async {
    final entry = _entry;
    if (entry == null || _busy) return;
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteTreasuryEntry),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(collectionRepositoryProvider).deleteInvoice(entry.id);
      await _refreshRelated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.entryDeleted), backgroundColor: AppColors.success),
      );
      context.go('${widget.basePath}/collection-invoices');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = _entry;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.collectionInvoice),
        actions: [
          if (entry != null && !_busy) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _confirmDelete,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editEntry,
              onPressed: _edit,
            ),
          ],
        ],
      ),
      body: _loading || _busy
          ? const LoadingOverlay()
          : _error != null
              ? ErrorStateWidget(message: _error!, onRetry: _load)
              : entry == null
                  ? Center(child: Text(l10n.noCollectionInvoices))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.collectionInvoice,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text('${l10n.client}: ${entry.clientName ?? '—'}'),
                                Text('${l10n.collectorEmployee}: ${entry.employeeName ?? '—'}'),
                                if (entry.collectionDate != null)
                                  Text(
                                    '${l10n.date}: ${DateFormat.yMMMd().format(entry.collectionDate!)}',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.invoiceDetails,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(),
                                _detailRow(
                                  l10n.balanceBeforePayment,
                                  context.formatCurrency(entry.balanceBefore ?? 0),
                                ),
                                _detailRow(
                                  l10n.amountPaid,
                                  context.formatCurrency(entry.amountPaid ?? entry.amount),
                                ),
                                _detailRow(
                                  l10n.amountDeducted,
                                  context.formatCurrency(entry.amountDeducted ?? 0),
                                ),
                                _detailRow(
                                  l10n.balanceAfterPayment,
                                  context.formatCurrency(entry.balanceAfter ?? 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        CollectionPdfActions(
                          entry: entry,
                          clientPhone: entry.clientPhone,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.editEntry),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _confirmDelete,
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          label: Text(l10n.delete),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
