import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/account_statement_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

class EmployeeTreasuryStatementScreen extends ConsumerWidget {
  const EmployeeTreasuryStatementScreen({super.key, this.employeeId});

  /// When null, loads the signed-in employee's own statement (`/me`).
  final String? employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isSelf = employeeId == null || employeeId!.isEmpty;
    final statementAsync = isSelf
        ? ref.watch(myTreasuryStatementProvider)
        : ref.watch(employeeTreasuryStatementProvider(employeeId!));

    void retry() {
      if (isSelf) {
        ref.invalidate(myTreasuryStatementProvider);
      } else {
        ref.invalidate(employeeTreasuryStatementProvider(employeeId!));
      }
    }

    Future<void> refresh() async {
      retry();
      if (isSelf) {
        ref.invalidate(myTreasuryProvider);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountStatement),
      ),
      body: statementAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(e),
          onRetry: retry,
        ),
        data: (statement) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statement.entity.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (statement.entity.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          statement.entity.phone,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.myEmployeeTreasury,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            context.formatCurrency(statement.entity.balance),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.employeeTreasuryFormula,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (statement.entries.isEmpty)
                SizedBox(
                  height: 200,
                  child: EmptyStateWidget(
                    icon: Icons.receipt_long,
                    title: l10n.noStatementEntries,
                  ),
                )
              else
                ..._buildEntries(context, statement.entries),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries(BuildContext context, List<AccountStatementEntry> entries) {
    final l10n = context.l10n;
    var running = 0.0;

    return entries.map((entry) {
      running += entry.credit - entry.debit;
      final balance = entry.balanceAfter ?? running;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(entry.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (entry.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AmountChip(
                      label: l10n.debit,
                      amount: entry.debit,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AmountChip(
                      label: l10n.credit,
                      amount: entry.credit,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${l10n.statementBalanceAfter}: ${context.formatCurrency(balance)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(
            amount > 0 ? context.formatCurrency(amount) : '—',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
