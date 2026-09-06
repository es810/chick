import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/employee_ledger_section.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  Future<void> _showAddExpenseDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final amountController = TextEditingController();
    final descController = TextEditingController();
    var submitting = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.addExpense),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.amount,
                    prefixIcon: const Icon(Icons.payments),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    hintText: l10n.expenseDescriptionHint,
                    prefixIcon: const Icon(Icons.description_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deductedFromMainTreasury,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
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
                      final amount = double.tryParse(
                        amountController.text.trim().replaceAll(',', ''),
                      );
                      final description = descController.text.trim();
                      if (amount == null || amount <= 0 || description.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.invalidAmount),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await ref
                            .read(employeeRepositoryProvider)
                            .addMyExpense(amount, description);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (context.mounted) {
                          final msg = e.toString().contains('Insufficient')
                              ? l10n.insufficientTreasury
                              : '$e';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
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

    amountController.dispose();
    descController.dispose();

    if (ok == true && context.mounted) {
      ref.invalidate(myLedgerProvider);
      ref.invalidate(myTreasuryProvider);
      ref.invalidate(myTreasuryStatementProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.expenseRecorded),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeeDashboard)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'expense',
            onPressed: () => _showAddExpenseDialog(context, ref),
            backgroundColor: const Color(0xFFE65100),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long),
            label: Text(l10n.addExpense),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'collection',
            onPressed: () => context.go('/employee/collection-invoices'),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.payments),
            label: Text(l10n.collectionInvoice),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'distribution',
            onPressed: () => context.push('/employee/invoices/create'),
            icon: const Icon(Icons.add),
            label: Text(l10n.distributionReceipt),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshUser();
          ref.invalidate(invoicesProvider);
          ref.invalidate(myLedgerProvider);
          ref.invalidate(myTreasuryProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            StatCard(
              title: l10n.mySalary,
              value: context.formatCurrency(user?.salary ?? 0),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),
            const EmployeeLedgerSection(),
            const SizedBox(height: 24),
            Text(l10n.collectionInvoices, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.payments, color: Color(0xFF2E7D32)),
                title: Text(l10n.collectionInvoice),
                subtitle: Text(l10n.manageCollectionInvoices),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/employee/collection-invoices'),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.myInvoices, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            invoicesAsync.when(
              loading: () => const LoadingShimmerColumn(itemCount: 3),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (result) {
                if (result.invoices.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.receipt_long,
                    title: l10n.noInvoicesYet,
                    subtitle: l10n.createFirstInvoice,
                  );
                }
                return Column(
                  children: result.invoices.take(10).map((invoice) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => context.push('/employee/invoices/${invoice.id}'),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                          child: const Icon(Icons.receipt, color: AppColors.primaryGreen),
                        ),
                        title: Text(invoice.invoiceNumber),
                        subtitle: Text(invoice.clientName ?? l10n.client),
                        trailing: Text(
                          context.formatCurrency(invoice.totalPrice),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 160),
          ],
        ),
      ),
    );
  }
}
