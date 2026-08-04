import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/damaged_stock_model.dart';
import '../../../models/stock_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

class DamagedStockScreen extends ConsumerWidget {
  const DamagedStockScreen({super.key});

  Future<void> _showRecordDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final stock = await ref.read(stockProvider.future);
    if (!context.mounted) return;
    if (stock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noStockItems)),
      );
      return;
    }

    StockModel? selected = stock.first;
    final quantityController = TextEditingController();
    final weightController = TextEditingController();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.recordDamagedStock),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<StockModel>(
                    initialValue: selected,
                    decoration: InputDecoration(labelText: l10n.stockTypeLabel),
                    items: stock
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.chickenType} (${s.usableQuantity} — ${s.usableNetWeight.toStringAsFixed(1)} kg)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selected = v),
                    validator: (v) => v == null ? l10n.selectStockType : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.itemCount),
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return null;
                      final qty = int.tryParse(raw);
                      if (qty == null || qty < 0) return l10n.invalidAmount;
                      if (selected != null && qty > selected!.quantity) {
                        return l10n.insufficientStock(selected!.chickenType);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.damagedWeightKg),
                    validator: (v) {
                      final raw = v?.trim() ?? '';
                      final qtyRaw = quantityController.text.trim();
                      if (raw.isEmpty && qtyRaw.isEmpty) {
                        return l10n.fieldRequired;
                      }
                      if (raw.isEmpty) return null;
                      final w = double.tryParse(raw);
                      if (w == null || w <= 0) return l10n.invalidAmount;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(labelText: l10n.damagedStockReason),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true || selected == null || !context.mounted) {
      quantityController.dispose();
      weightController.dispose();
      reasonController.dispose();
      return;
    }

    try {
      final qty = int.tryParse(quantityController.text.trim()) ?? 0;
      final weight = double.tryParse(weightController.text.trim());
      await ref.read(damagedStockRepositoryProvider).record(
            stockId: selected!.id,
            quantity: qty,
            netWeight: weight,
            reason: reasonController.text,
          );
      quantityController.dispose();
      weightController.dispose();
      reasonController.dispose();
      ref.invalidate(damagedStockProvider);
      ref.invalidate(stockProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.damagedStockRecorded), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      quantityController.dispose();
      weightController.dispose();
      reasonController.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final damagedAsync = ref.watch(damagedStockProvider);
    final isAdmin = ref.watch(currentUserProvider)?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
        ),
        title: Text(l10n.damagedStock),
      ),
      body: damagedAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(e),
          onRetry: () => ref.invalidate(damagedStockProvider),
        ),
        data: (result) {
          if (result.entries.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.delete_sweep_outlined,
              title: l10n.noDamagedStock,
              subtitle: l10n.damagedStockTreasuryNote,
              action: isAdmin
                  ? ElevatedButton.icon(
                      onPressed: () => _showRecordDialog(context, ref),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.recordDamagedStock),
                    )
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(damagedStockProvider);
              ref.invalidate(stockProvider);
              ref.invalidate(dashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.error.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.damagedStockTreasuryNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        if (result.totalNetWeight > 0)
                          Text(
                            '${l10n.damagedWeightKg}: ${result.totalNetWeight.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                          ),
                        if (result.totalQuantity > 0)
                          Text(
                            '${l10n.itemCount}: ${result.totalQuantity}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...result.entries.map(
                  (entry) => _DamagedEntryCard(
                    entry: entry,
                    isAdmin: isAdmin,
                    onWriteOff: isAdmin && entry.isOpenSurplus
                        ? () => _writeOff(context, ref, entry)
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showRecordDialog(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _writeOff(
    BuildContext context,
    WidgetRef ref,
    DamagedStockEntry entry,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmWriteOffSurplus),
        content: Text(
          '${entry.chickenType}\n'
          '${entry.quantity > 0 ? '${l10n.itemCount}: ${entry.quantity}\n' : ''}'
          '${entry.netWeight > 0 ? '${l10n.damagedWeightKg}: ${entry.netWeight.toStringAsFixed(1)}\n' : ''}'
          '${l10n.pendingSurplusOpen}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmWriteOffSurplus),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(damagedStockRepositoryProvider).writeOff(entry.id);
      ref.invalidate(damagedStockProvider);
      ref.invalidate(stockProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.writeOffSurplusDone),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _DamagedEntryCard extends StatelessWidget {
  const _DamagedEntryCard({
    required this.entry,
    required this.isAdmin,
    this.onWriteOff,
  });

  final DamagedStockEntry entry;
  final bool isAdmin;
  final VoidCallback? onWriteOff;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: (entry.isOpenSurplus ? AppColors.warning : AppColors.error)
                .withValues(alpha: 0.12),
            child: Icon(
              entry.isDistributionSurplus ? Icons.scale : Icons.delete_sweep_outlined,
              color: entry.isOpenSurplus ? AppColors.warning : AppColors.error,
            ),
          ),
          title: Text(entry.chickenType),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.isDistributionSurplus)
                Text(
                  entry.isOpenSurplus
                      ? l10n.pendingSurplusOpen
                      : '${l10n.distributionWeightSurplus} — ${l10n.surplusAlreadyWrittenOff}',
                  style: TextStyle(
                    color: entry.isOpenSurplus ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: Theme.of(context).textTheme.bodySmall?.fontSize,
                  ),
                ),
              if (entry.netWeight > 0)
                Text('${l10n.damagedWeightKg}: ${entry.netWeight.toStringAsFixed(1)}'),
              if (entry.quantity > 0) Text('${l10n.itemCount}: ${entry.quantity}'),
              if (entry.reason.isNotEmpty) Text(entry.reason),
              if (entry.createdAt != null)
                Text(DateFormat.yMMMd().add_jm().format(entry.createdAt!)),
              if (onWriteOff != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onWriteOff,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l10n.confirmWriteOffSurplus),
                  ),
                ),
              ],
            ],
          ),
          trailing: entry.recordedByName != null
              ? Text(entry.recordedByName!, style: Theme.of(context).textTheme.bodySmall)
              : null,
        ),
      ),
    );
  }
}
