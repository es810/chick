import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/monthly_profit_statement_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

typedef MonthKey = ({int year, int month});

final monthlyProfitStatementProvider =
    FutureProvider.family<MonthlyProfitStatement, MonthKey>((ref, key) async {
  return ref.watch(reportRepositoryProvider).getMonthlyProfitStatement(
        year: key.year,
        month: key.month,
      );
});

class MonthlyProfitStatementScreen extends ConsumerWidget {
  const MonthlyProfitStatementScreen({
    super.key,
    required this.year,
    required this.month,
  });

  final int year;
  final int month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final key = (year: year, month: month);
    final async = ref.watch(monthlyProfitStatementProvider(key));
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat.yMMMM(locale).format(DateTime(year, month));

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.monthlyProfitStatement} — $monthLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: l10n.selectMonth,
            onPressed: () => _pickMonth(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(
            e,
            fallback: e is DioException ? l10n.serverError : e.toString(),
          ),
          onRetry: () => ref.invalidate(monthlyProfitStatementProvider(key)),
        ),
        data: (statement) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyProfitStatementProvider(key));
            await ref.read(monthlyProfitStatementProvider(key).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SummaryCard(statement: statement),
              const SizedBox(height: 16),
              Text(
                l10n.dailyProfitBreakdown,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (statement.days.isEmpty)
                EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.noStatementEntries,
                )
              else
                ...statement.days.map((day) => _DayCard(day: day)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(year, month),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: l10n.selectMonth,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null || !context.mounted) return;
    ref.read(dashboardMonthProvider.notifier).state =
        DateTime(picked.year, picked.month);
    context.pushReplacement(
      '/admin/profit-statement?year=${picked.year}&month=${picked.month}',
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.statement});

  final MonthlyProfitStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.monthlyProfit,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.monthlyProfitFormula,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            _kv(context, l10n.monthlyRevenue, statement.revenue),
            _kv(context, l10n.profitLoadCost, statement.loading),
            _kv(context, l10n.expenses, statement.expenses),
            _kv(context, l10n.totalDiscount, statement.discount),
            const Divider(height: 24),
            _kv(context, l10n.dailyProfitsTotal, statement.dailyProfitsTotal),
            _kv(context, l10n.salaryAdvanceThisMonth, -statement.salaryAdvances),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.afterSalariesDeduction,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  context.formatCurrency(statement.profit),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statement.profit >= 0
                            ? AppColors.primaryGreen
                            : AppColors.error,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            context.formatCurrency(value),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DailyProfitRow day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final parsed = DateTime.tryParse(day.date);
    final dateLabel = parsed != null
        ? DateFormat.yMMMEd(locale).format(parsed)
        : day.date;
    final profitColor =
        day.profit >= 0 ? AppColors.primaryGreen : AppColors.error;

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
                    dateLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  context.formatCurrency(day.profit),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: profitColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _chip(context, muted, l10n.monthlyRevenue, day.revenue),
                _chip(context, muted, l10n.profitLoadCost, day.loading),
                _chip(context, muted, l10n.expenses, day.expenses),
                _chip(context, muted, l10n.totalDiscount, day.discount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    Color muted,
    String label,
    double value,
  ) {
    return Text(
      '$label: ${context.formatCurrencyCompact(value)}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
    );
  }
}
