import 'package:fl_chart/fl_chart.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../models/dashboard_model.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminDashboard),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(
            e,
            fallback: e is DioException && e.response?.statusCode == 401
                ? l10n.sessionExpired
                : l10n.serverError,
          ),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (dashboard) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardProvider);
            ref.invalidate(salesReportProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TreasuryCard(dashboard: dashboard),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  StatCard(
                    title: l10n.dailyProfit,
                    value: context.formatCurrencyCompact(dashboard.dailyProfit.profit),
                    icon: Icons.today,
                    color: AppColors.primaryGreen,
                  ),
                  _MonthlyProfitCard(monthlyProfit: dashboard.monthlyProfit),
                  StatCard(
                    title: l10n.invoices,
                    value: '${dashboard.monthlyInvoices}',
                    icon: Icons.receipt_long,
                    color: AppColors.primaryGreen,
                  ),
                  StatCard(
                    title: l10n.receivables,
                    value: context.formatCurrencyCompact(dashboard.receivables),
                    icon: Icons.account_balance_wallet,
                    color: AppColors.warning,
                  ),
                  StatCard(
                    title: l10n.damagedStock,
                    value: '${dashboard.damagedStockQuantity}',
                    icon: Icons.delete_sweep_outlined,
                    color: AppColors.error,
                    subtitle: l10n.damagedStockTreasuryNote,
                    onTap: () => context.go('/admin/damaged-stock'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(l10n.salesTrend, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const _SalesTrendChart(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.recentInvoices, style: Theme.of(context).textTheme.titleLarge),
                  TextButton(onPressed: () => context.go('/admin/invoices'), child: Text(l10n.viewAll)),
                ],
              ),
              ...dashboard.recentInvoices.map((inv) {
                final number = inv['invoiceNumber'] ?? '';
                final total = inv['totalPrice'] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      child: const Icon(Icons.receipt, color: AppColors.primaryGreen),
                    ),
                    title: Text(number.toString()),
                    subtitle: Text(context.formatCurrency((total as num).toDouble())),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickAction(
                    icon: Icons.payments,
                    label: l10n.collectionInvoices,
                    onTap: () => context.push('/admin/collection-invoices'),
                  ),
                  _QuickAction(
                    icon: Icons.receipt_long,
                    label: l10n.distributionInvoices,
                    onTap: () => context.go('/admin/invoices'),
                  ),
                  _QuickAction(
                    icon: Icons.people,
                    label: l10n.employees,
                    onTap: () => context.go('/admin/employees'),
                  ),
                  _QuickAction(
                    icon: Icons.inventory,
                    label: l10n.stock,
                    onTap: () => context.go('/admin/stock'),
                  ),
                  _QuickAction(
                    icon: Icons.analytics,
                    label: l10n.reports,
                    onTap: () => context.go('/admin/reports'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyProfitCard extends ConsumerWidget {
  const _MonthlyProfitCard({required this.monthlyProfit});

  final MonthlyProfitSummary monthlyProfit;

  Future<void> _pickMonth(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final selected = ref.read(dashboardMonthProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: l10n.selectMonth,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    ref.read(dashboardMonthProvider.notifier).state = DateTime(picked.year, picked.month);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat.yMMMM(locale).format(
      DateTime(monthlyProfit.year, monthlyProfit.month),
    );

    return StatCard(
      title: l10n.monthlyProfit,
      value: context.formatCurrencyCompact(monthlyProfit.profit),
      icon: Icons.calendar_month,
      color: AppColors.lightGreen,
      subtitle:
          '$monthLabel · ${l10n.afterSalariesDeduction}: ${context.formatCurrencyCompact(monthlyProfit.salaries)}',
      onTap: () => _pickMonth(context, ref),
    );
  }
}

class _TreasuryCard extends ConsumerWidget {
  const _TreasuryCard({required this.dashboard});

  final DashboardData dashboard;

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.zeroTreasury),
        content: Text(l10n.confirmZeroTreasury),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.zeroTreasury),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(treasuryRepositoryProvider).resetMainTreasury();
      ref.invalidate(dashboardProvider);
      ref.invalidate(treasurySummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treasuryZeroed), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Material(
      color: AppColors.primaryGreen,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/admin/treasury'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/admin/treasury'),
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: l10n.editTreasury,
                  ),
                  IconButton(
                    onPressed: () => _confirmReset(context, ref),
                    icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white),
                    tooltip: l10n.zeroTreasury,
                  ),
                  Expanded(
                    child: Text(
                      l10n.mainTreasury,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.formatCurrency(dashboard.mainTreasuryBalance),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesTrendChart extends ConsumerWidget {
  const _SalesTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final salesAsync = ref.watch(salesReportProvider);

    return SizedBox(
      height: 200,
      child: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.chartUnavailable)),
        data: (sales) => sales.isEmpty
            ? Center(child: Text(l10n.noSalesData))
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sales.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value.totalSales);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primaryGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primaryGreen),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
