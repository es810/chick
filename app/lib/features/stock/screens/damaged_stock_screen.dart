import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/damaged_stock_model.dart';
import '../../../models/stock_model.dart';
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
                            child: Text('${s.chickenType} (${s.quantity})'),
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
                      final qty = int.tryParse(v?.trim() ?? '');
                      if (qty == null || qty <= 0) return l10n.invalidAmount;
                      if (selected != null && qty > selected!.quantity) {
                        return l10n.insufficientStock(selected!.chickenType);
                      }
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
      reasonController.dispose();
      return;
    }

    try {
      await ref.read(damagedStockRepositoryProvider).record(
            stockId: selected!.id,
            quantity: int.parse(quantityController.text.trim()),
            reason: reasonController.text,
          );
      quantityController.dispose();
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.damagedStock)),
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
              action: ElevatedButton.icon(
                onPressed: () => _showRecordDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.recordDamagedStock),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(damagedStockProvider);
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
                        Text(
                          '${l10n.itemCount}: ${result.totalQuantity}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...result.entries.map((entry) => _DamagedEntryCard(entry: entry)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DamagedEntryCard extends StatelessWidget {
  const _DamagedEntryCard({required this.entry});

  final DamagedStockEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.error.withValues(alpha: 0.12),
          child: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
        ),
        title: Text(entry.chickenType),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.itemCount}: ${entry.quantity}'),
            if (entry.reason.isNotEmpty) Text(entry.reason),
            if (entry.createdAt != null)
              Text(DateFormat.yMMMd().add_jm().format(entry.createdAt!)),
          ],
        ),
        trailing: entry.recordedByName != null
            ? Text(entry.recordedByName!, style: Theme.of(context).textTheme.bodySmall)
            : null,
      ),
    );
  }
}
