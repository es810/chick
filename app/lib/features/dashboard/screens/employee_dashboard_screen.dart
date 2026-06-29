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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    final stockAsync = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeeDashboard)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'collection',
            onPressed: () => context.go('/employee/collection-invoices'),
            backgroundColor: const Color(0xFF2E7D32),
            icon: const Icon(Icons.payments),
            label: Text(l10n.collectionInvoice),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'distribution',
            onPressed: () => context.go('/employee/invoices/create'),
            icon: const Icon(Icons.add),
            label: Text(l10n.distributionReceipt),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authProvider.notifier).refreshUser();
          ref.invalidate(invoicesProvider);
          ref.invalidate(stockProvider);
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
            Text(l10n.stock, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            stockAsync.when(
              loading: () => const LoadingShimmerColumn(itemCount: 2, itemHeight: 100),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(stockProvider),
              ),
              data: (stock) {
                final lowStock = stock.where((s) => s.isLowStock).length;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    StatCard(
                      title: l10n.stockTypes,
                      value: '${stock.length}',
                      icon: Icons.inventory_2,
                      color: AppColors.primaryGreen,
                    ),
                    StatCard(
                      title: l10n.lowStock,
                      value: '$lowStock',
                      icon: Icons.warning,
                      color: lowStock > 0 ? AppColors.error : AppColors.success,
                    ),
                  ],
                );
              },
            ),
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
                        onTap: () => context.go('/employee/invoices/${invoice.id}'),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
