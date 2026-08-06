import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/stock_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/role_hint_banner.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../stock/widgets/stock_entry_form.dart';

class SupplierStockScreen extends ConsumerWidget {
  const SupplierStockScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  final String supplierId;
  final String supplierName;

  bool _isAdmin(WidgetRef ref) => ref.watch(currentUserProvider)?.role == UserRole.admin;

  bool _canAddStock(WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    return role == UserRole.admin || role == UserRole.employee;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = _isAdmin(ref);
    final canAddStock = _canAddStock(ref);
    final stockAsync = ref.watch(supplierStockProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.supplierStock} — $supplierName'),
        actions: [
          if (canAddStock)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addSupplierStock,
              onPressed: () => _showAddStockDialog(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          RoleHintBanner(text: l10n.suppliersRoleHint),
          Expanded(
            child: stockAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(supplierStockProvider(supplierId)),
        ),
        data: (stock) {
          if (stock.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.inventory_2,
              title: l10n.noSupplierStockYet,
              action: canAddStock
                  ? ElevatedButton.icon(
                      onPressed: () => _showAddStockDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addSupplierStock),
                    )
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(supplierStockProvider(supplierId)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: stock.length,
              itemBuilder: (_, i) => _StockCard(
                item: stock[i],
                isAdmin: isAdmin,
                onEdit: isAdmin ? () => _showEditStockDialog(context, ref, stock[i]) : null,
                onDelete: isAdmin ? () => _confirmDelete(context, ref, stock[i]) : null,
              ),
            ),
          );
        },
            ),
          ),
        ],
      ),
      floatingActionButton: canAddStock
          ? FloatingActionButton(
              onPressed: () => _showAddStockDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showAddStockDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formKey = GlobalKey<StockEntryFormState>();
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.addSupplierStock),
          content: SingleChildScrollView(
            child: StockEntryForm(key: formKey),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final form = formKey.currentState;
                      if (form == null || !form.validate(context)) return;
                      setDialogState(() => submitting = true);
                      try {
                        await ref
                            .read(supplierStockRepositoryProvider)
                            .addStock(supplierId, form.toPayload());
                        ref.invalidate(supplierStockProvider(supplierId));
                        ref.invalidate(stockProvider);
                        ref.invalidate(suppliersProvider);
                        ref.invalidate(supplierStatementProvider(supplierId));
                        ref.invalidate(treasurySummaryProvider);
                        ref.invalidate(dashboardProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.supplierStockSynced)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(apiErrorMessage(e)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStockDialog(BuildContext context, WidgetRef ref, StockModel item) {
    final l10n = context.l10n;
    final formKey = GlobalKey<StockEntryFormState>();
    var submitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.editStock),
          content: SingleChildScrollView(
            child: StockEntryForm(
              key: formKey,
              initialLocation: item.location,
              initialType: item.chickenType,
              initialGross: item.grossWeight.toStringAsFixed(2),
              initialCount: '${item.quantity}',
              initialTare: item.tareWeight.toStringAsFixed(2),
              initialNet: item.netWeight.toStringAsFixed(2),
              initialPrice: item.pricePerKg.toStringAsFixed(2),
              typeReadOnly: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final form = formKey.currentState;
                      if (form == null || !form.validate(context)) return;
                      setDialogState(() => submitting = true);
                      try {
                        await ref
                            .read(supplierStockRepositoryProvider)
                            .updateStock(supplierId, item.id, form.toPayload());
                        ref.invalidate(supplierStockProvider(supplierId));
                        ref.invalidate(stockProvider);
                        ref.invalidate(suppliersProvider);
                        ref.invalidate(supplierStatementProvider(supplierId));
                        ref.invalidate(treasurySummaryProvider);
                        ref.invalidate(dashboardProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.stockUpdated),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(apiErrorMessage(e)),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, StockModel item) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(
          item.quantity > 0
              ? '${l10n.confirmDeleteStockWithQty}\n\n${item.chickenType} (${item.quantity})'
              : '${l10n.confirmDeleteStock}\n\n${item.chickenType}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(supplierStockRepositoryProvider).deleteStock(supplierId, item.id);
      ref.invalidate(supplierStockProvider(supplierId));
      ref.invalidate(stockProvider);
      ref.invalidate(suppliersProvider);
      ref.invalidate(supplierStatementProvider(supplierId));
      ref.invalidate(treasurySummaryProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.stockDeleted), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.item,
    required this.isAdmin,
    this.onEdit,
    this.onDelete,
  });

  final StockModel item;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${l10n.stockLocation}: ${item.location}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.chickenType,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (item.isLowStock)
                  StatusChip(label: l10n.lowStockBadge, color: AppColors.error),
                if (isAdmin) ...[
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: l10n.itemCount,
                    value: '${item.quantity}',
                    icon: Icons.numbers,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatCard(
                    title: l10n.stockPrice,
                    value: context.formatCurrency(item.pricePerKg),
                    icon: Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${l10n.grossWeight}: ${item.grossWeight.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text('${l10n.tareWeight}: ${item.tareWeight.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: Text('${l10n.netWeight}: ${item.netWeight.toStringAsFixed(2)}'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.stockTotal}: ${context.formatCurrency(item.displayTotal)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
