import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(revenueProvider);
    final salesAsync = ref.watch(salesReportProvider);
    final auditAsync = ref.watch(auditLogsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports & Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Revenue'),
              Tab(text: 'Sales'),
              Tab(text: 'Audit Logs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            revenueAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (revenue) {
                final daily = revenue['daily'] as Map<String, dynamic>? ?? {};
                final monthly = revenue['monthly'] as Map<String, dynamic>? ?? {};
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        StatCard(
                          title: 'Daily Revenue',
                          value: context.formatCurrencyCompact((daily['revenue'] as num?) ?? 0),
                          icon: Icons.today,
                          subtitle: '${daily['count'] ?? 0} invoices',
                        ),
                        StatCard(
                          title: 'Monthly Revenue',
                          value: context.formatCurrencyCompact((monthly['revenue'] as num?) ?? 0),
                          icon: Icons.calendar_month,
                          subtitle: '${monthly['count'] ?? 0} invoices',
                        ),
                        StatCard(
                          title: 'Stock Value',
                          value: context.formatCurrencyCompact((revenue['stockValue'] as num?) ?? 0),
                          icon: Icons.inventory,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            salesAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sales) => sales.isEmpty
                  ? const Center(child: Text('No sales data'))
                  : Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              barGroups: sales.asMap().entries.map((e) {
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: e.value.totalSales,
                                      color: AppColors.primaryGreen,
                                      width: 16,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ],
                                );
                              }).toList(),
                              titlesData: const FlTitlesData(show: false),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: sales.length,
                            itemBuilder: (_, i) {
                              final item = sales[i];
                              return ListTile(
                                title: Text(item.date),
                                trailing: Text(context.formatCurrency(item.totalSales)),
                                subtitle: Text('${item.invoiceCount} invoices'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            auditAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (logs) => ListView.builder(
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  return ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('${log['action']} - ${log['target']}'),
                    subtitle: Text(log['createdAt']?.toString() ?? ''),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
