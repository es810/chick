import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/employee_ledger_model.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

class EmployeeLedgerSection extends ConsumerWidget {
  const EmployeeLedgerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final treasuryAsync = ref.watch(myTreasuryProvider);
    final ledgerAsync = ref.watch(myLedgerProvider);

    return treasuryAsync.when(
      loading: () => const LoadingShimmerColumn(itemCount: 2, itemHeight: 72),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${l10n.pdfError}: $e'),
        ),
      ),
      data: (treasury) {
        return ledgerAsync.when(
          loading: () => const LoadingShimmerColumn(itemCount: 2, itemHeight: 72),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${l10n.pdfError}: $e'),
            ),
          ),
          data: (ledger) {
            final expenses = ledger.entries.where((e) => e.isExpense).toList();
            final treasuryColor =
                treasury.balance >= 0 ? AppColors.primaryGreen : AppColors.error;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatCard(
                  title: l10n.myEmployeeTreasury,
                  value: context.formatCurrency(treasury.balance),
                  icon: Icons.account_balance_wallet_outlined,
                  color: treasuryColor,
                  subtitle: l10n.employeeTreasuryFormula,
                  onTap: () => context.push('/employee/treasury/statement'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => context.push('/employee/treasury/statement'),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(l10n.viewAccountStatement),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.myExpenses, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  context.formatCurrency(ledger.totalExpenses),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (expenses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l10n.recentExpenses, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...expenses.take(8).map((entry) => _ExpenseTile(entry: entry)),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.entry});

  final EmployeeLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_gas_station, color: AppColors.warning),
        title: Text(entry.description),
        subtitle: entry.createdAt != null
            ? Text(DateFormat.yMMMd().add_jm().format(entry.createdAt!))
            : null,
        trailing: Text(
          context.formatCurrency(entry.amount),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
