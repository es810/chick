import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/invoice_model.dart';
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
  Future<InvoiceModel>? _invoiceFuture;

  Future<InvoiceModel> _loadInvoiceFuture() {
    return _invoiceFuture ??=
        ref.read(invoiceRepositoryProvider).getInvoice(widget.invoiceId);
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
        context.go('${widget.basePath}/invoices');
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
    final canManage = widget.basePath.contains('admin') || widget.basePath.contains('employee');
    final invoiceFuture = _loadInvoiceFuture();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.invoiceDetails),
        actions: [
          if (canManage && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteInvoice,
              onPressed: () async {
                final inv = await ref.read(invoiceRepositoryProvider).getInvoice(widget.invoiceId);
                if (mounted) await _confirmDelete(inv);
              },
            ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editInvoice,
              onPressed: _isDeleting
                  ? null
                  : () => context.go('${widget.basePath}/invoices/${widget.invoiceId}/edit'),
            ),
        ],
      ),
      body: FutureBuilder<InvoiceModel>(
        future: invoiceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isDeleting) {
            return const LoadingOverlay();
          }
          if (snapshot.hasError) {
            return Center(child: Text('${l10n.pdfError}: ${snapshot.error}'));
          }
          final invoice = snapshot.data!;

          return ListView(
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
                      Text(l10n.distributionReceipt, style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      if (invoice.chickenTypesLabel.isNotEmpty)
                        _detailRow('نوع الصنف', invoice.chickenTypesLabel),
                      _detailRow(l10n.itemCount, '${invoice.itemCount}'),
                      _detailRow(l10n.grossWeight, invoice.displayGrossWeight.toStringAsFixed(2)),
                      _detailRow(l10n.tareWeight, invoice.displayTareWeight.toStringAsFixed(2)),
                      _detailRow(l10n.netWeight, invoice.netWeight.toStringAsFixed(2)),
                      _detailRow(l10n.pricePerKg, invoice.pricePerKg.toStringAsFixed(2)),
                      _detailRow(l10n.mealTotal, context.formatCurrency(invoice.totalPrice)),
                      if (invoice.balanceBefore != null)
                        _detailRow(l10n.balanceBefore, context.formatCurrency(invoice.balanceBefore!)),
                      if (invoice.balanceAfter != null)
                        _detailRow(l10n.balanceAfter, context.formatCurrency(invoice.balanceAfter!)),
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
                      subtitle: Text('${item.quantity} × ${item.weight.toStringAsFixed(2)} kg'),
                      trailing: Text(context.formatCurrency(item.total)),
                    ),
                  ),
                ),
              ],
              InvoicePdfActions(
                invoice: invoice,
                clientPhone: invoice.clientPhone,
              ),
              if (canManage) ...[
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
          );
        },
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
