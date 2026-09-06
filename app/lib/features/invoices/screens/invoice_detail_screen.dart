import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/invoice_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/invoice_pdf_actions.dart';
import '../../../shared/widgets/loading_widget.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId, this.basePath = '/admin'});

  final String invoiceId;
  final String basePath;

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isDeleting = false;
  bool _loading = true;
  String? _error;
  InvoiceModel? _invoice;

  bool get _canManage =>
      widget.basePath.contains('admin') || widget.basePath.contains('employee');

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
      final invoice =
          await ref.read(invoiceRepositoryProvider).getInvoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, fallback: context.l10n.serverError);
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete(InvoiceModel invoice) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteInvoice),
        content: Text('${l10n.confirmDeleteInvoice}\n\n${invoice.invoiceNumber}'),
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

    setState(() => _isDeleting = true);
    try {
      await ref.read(invoiceRepositoryProvider).deleteInvoice(widget.invoiceId);
      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(treasurySummaryProvider);
      ref.invalidate(stockProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invoiceDeleted), backgroundColor: AppColors.success),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('${widget.basePath}/invoices');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: l10n.serverError)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceDetails),
        actions: [
          if (_canManage && invoice != null && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteInvoice,
              onPressed: () => _confirmDelete(invoice),
            ),
          if (_canManage && invoice != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editInvoice,
              onPressed: _isDeleting
                  ? null
                  : () => context.push('${widget.basePath}/invoices/${widget.invoiceId}/edit'),
            ),
        ],
      ),
      body: _loading || _isDeleting
          ? const LoadingOverlay()
          : _error != null
              ? ErrorStateWidget(
                  message: _error!,
                  onRetry: _load,
                )
              : invoice == null
                  ? EmptyStateWidget(
                      icon: Icons.receipt_long,
                      title: l10n.noInvoicesFound,
                    )
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
                                  invoice.invoiceNumber,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text('${l10n.client}: ${invoice.clientName ?? "N/A"}'),
                                Text('${l10n.employee}: ${invoice.employeeName ?? "N/A"}'),
                                if (invoice.createdAt != null)
                                  Text(
                                    '${l10n.date}: ${DateFormat.yMMMd().add_jm().format(invoice.createdAt!)}',
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
                                  l10n.distributionReceipt,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(),
                                if (invoice.chickenTypesLabel.isNotEmpty)
                                  _detailRow('نوع الصنف', invoice.chickenTypesLabel),
                                _detailRow(l10n.itemCount, '${invoice.itemCount}'),
                                _detailRow(
                                  l10n.grossWeight,
                                  invoice.displayGrossWeight.toStringAsFixed(2),
                                ),
                                _detailRow(
                                  l10n.tareWeight,
                                  invoice.displayTareWeight.toStringAsFixed(2),
                                ),
                                _detailRow(l10n.netWeight, invoice.netWeight.toStringAsFixed(2)),
                                _detailRow(
                                  l10n.pricePerKg,
                                  invoice.pricePerKg.toStringAsFixed(2),
                                ),
                                _detailRow(
                                  l10n.mealTotal,
                                  context.formatCurrency(invoice.totalPrice),
                                ),
                                if (invoice.balanceBefore != null)
                                  _detailRow(
                                    l10n.balanceBefore,
                                    context.formatCurrency(invoice.balanceBefore!),
                                  ),
                                if (invoice.balanceAfter != null)
                                  _detailRow(
                                    l10n.balanceAfter,
                                    context.formatCurrency(invoice.balanceAfter!),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (invoice.items.length > 1) ...[
                          const SizedBox(height: 16),
                          Text(l10n.chickenType, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ...invoice.items.map(
                            (item) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item.chickenType),
                                subtitle: Text(
                                  '${item.quantity} × ${item.weight.toStringAsFixed(2)} kg',
                                ),
                                trailing: Text(context.formatCurrency(item.total)),
                              ),
                            ),
                          ),
                        ],
                        InvoicePdfActions(
                          invoice: invoice,
                          clientPhone: invoice.clientPhone,
                        ),
                        if (_canManage) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isDeleting ? null : () => _confirmDelete(invoice),
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            label: Text(l10n.deleteInvoice),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
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
