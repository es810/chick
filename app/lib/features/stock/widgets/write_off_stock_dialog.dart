import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/stock_model.dart';

/// Manual هلك for leftover stock still on the books.
/// Prefills [item] so the admin writes off from the stock card itself.
Future<bool> showWriteOffStockDialog({
  required BuildContext context,
  required WidgetRef ref,
  required StockModel item,
}) async {
  final l10n = context.l10n;
  if (item.usableQuantity <= 0 && item.usableNetWeight <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.noStockLeftToWriteOff)),
    );
    return false;
  }

  final quantityController = TextEditingController();
  final weightController = TextEditingController();
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(l10n.writeOffStockTitle),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.chickenType,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.remainingStockLabel,
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.onHandStock}: ${item.usableQuantity}',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${l10n.netWeight}: ${item.usableNetWeight.toStringAsFixed(2)} kg',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.itemCount,
                    helperText: '${l10n.maxLabel}: ${item.usableQuantity}',
                  ),
                  validator: (v) {
                    final raw = v?.trim() ?? '';
                    if (raw.isEmpty) return null;
                    final qty = int.tryParse(raw);
                    if (qty == null || qty < 0) return l10n.invalidAmount;
                    if (qty > item.usableQuantity) {
                      return l10n.insufficientStock(item.chickenType);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.damagedWeightKg,
                    helperText:
                        '${l10n.maxLabel}: ${item.usableNetWeight.toStringAsFixed(2)} kg',
                  ),
                  validator: (v) {
                    final raw = v?.trim() ?? '';
                    final qtyRaw = quantityController.text.trim();
                    if (raw.isEmpty && qtyRaw.isEmpty) {
                      return l10n.fieldRequired;
                    }
                    if (raw.isEmpty) return null;
                    final w = double.tryParse(raw.replaceAll(',', ''));
                    if (w == null || w <= 0) return l10n.invalidAmount;
                    if (w > item.usableNetWeight + 0.001) {
                      return l10n.weightExceedsStock;
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
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: submitting
                ? null
                : () async {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setDialogState(() => submitting = true);
                    try {
                      final qty = int.tryParse(quantityController.text.trim()) ?? 0;
                      final weight = double.tryParse(
                        weightController.text.trim().replaceAll(',', ''),
                      );
                      await ref.read(damagedStockRepositoryProvider).record(
                            stockId: item.id,
                            quantity: qty,
                            netWeight: weight,
                            reason: reasonController.text,
                          );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setDialogState(() => submitting = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(apiErrorMessage(e)),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.confirmWriteOff),
          ),
        ],
      ),
    ),
  );

  quantityController.dispose();
  weightController.dispose();
  reasonController.dispose();

  if (ok == true) {
    ref.invalidate(damagedStockProvider);
    ref.invalidate(stockLoadsProvider);
    ref.invalidate(stockProvider);
    ref.invalidate(dashboardProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.damagedStockRecorded),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return true;
  }
  return false;
}
