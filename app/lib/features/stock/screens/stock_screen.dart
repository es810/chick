import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/stock_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';
import '../widgets/stock_entry_form.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key, this.embedded = false});

  final bool embedded;

  bool _isAdmin(WidgetRef ref) => ref.watch(currentUserProvider)?.role == UserRole.admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isAdmin = _isAdmin(ref);
    final stockAsync = ref.watch(stockProvider);

    final body = Column(
        children: [
          if (!isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.viewOnlyStock,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: stockAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(stockProvider),
              ),
              data: (stock) {
                if (stock.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.inventory_2,
                    title: l10n.noStockItems,
                    action: isAdmin
                        ? ElevatedButton.icon(
                            onPressed: () => _showAddStockDialog(context, ref),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.addStock),
                          )
                        : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(stockProvider),
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, embedded && isAdmin ? 88 : 16),
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
    );

    if (embedded) {
      return ColoredBox(
        color: const Color(0xFF0D1B3E),
        child: Stack(
          children: [
            body,
            if (isAdmin)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddStockDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addStock),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(isAdmin ? l10n.stockManagement : l10n.stock),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddStockDialog(context, ref),
            ),
        ],
      ),
      body: body,
      floatingActionButton: isAdmin
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
          title: Text(l10n.addStockMovement),
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
                        final payload = form.toPayload();
                        payload['reason'] = 'Manual stock replenishment';
                        await ref.read(stockRepositoryProvider).addStock(payload);
                        ref.invalidate(stockProvider);
                        if (context.mounted) Navigator.pop(ctx);
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              final form = formKey.currentState;
              if (form == null || !form.validate(context)) return;
              try {
                final payload = form.toPayload();
                await ref.read(stockRepositoryProvider).updateStock(item.id, payload);
                ref.invalidate(stockProvider);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.stockUpdated), backgroundColor: AppColors.success),
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
            },
            child: Text(l10n.save),
          ),
        ],
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
      await ref.read(stockRepositoryProvider).deleteStock(item.id);
      ref.invalidate(stockProvider);
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
                    title: l10n.onHandStock,
                    value: '${item.usableQuantity}',
                    icon: Icons.inventory_2,
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
            if (item.hasPendingSurplus) ...[
              const SizedBox(height: 8),
              Text(
                '${l10n.pendingSurplusLabel}: '
                '${item.pendingSurplusQuantity > 0 ? '${item.pendingSurplusQuantity} ' : ''}'
                '${item.pendingSurplusNetWeight > 0 ? '${item.pendingSurplusNetWeight.toStringAsFixed(1)} kg' : ''}'
                .trim(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '${l10n.bookStockLabel}: ${item.quantity}'
                '${item.netWeight > 0 ? ' — ${item.netWeight.toStringAsFixed(2)} kg' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${l10n.netWeight}: ${item.usableNetWeight.toStringAsFixed(2)} kg'
              '${item.hasPendingSurplus ? ' (${l10n.onHandStock})' : ''}',
            ),
            const SizedBox(height: 4),
            Text('${l10n.grossWeight}: ${item.grossWeight.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text('${l10n.tareWeight}: ${item.tareWeight.toStringAsFixed(2)}'),
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
