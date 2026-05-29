import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAccount)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(invoicesProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            invoicesAsync.when(
              loading: () => const LoadingShimmerColumn(itemCount: 2),
              error: (e, _) => ErrorStateWidget(message: e.toString()),
              data: (result) {
                final invoices = result.invoices;
                final totalSpent = invoices.fold<double>(0, (sum, i) => sum + i.totalPrice);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          title: l10n.totalSpent,
                          value: context.formatCurrencyCompact(totalSpent),
                          icon: Icons.payments,
                          color: AppColors.primaryGreen,
                        ),
                        StatCard(
                          title: l10n.invoices,
                          value: '${invoices.length}',
                          icon: Icons.receipt,
                          color: AppColors.lightGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(l10n.myInvoices, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (invoices.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: l10n.noInvoicesYet,
                      )
                    else
                      ...invoices.map((invoice) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => context.go('/client/invoices/${invoice.id}'),
                              title: Text(invoice.invoiceNumber),
                              subtitle: Text(
                                invoice.createdAt != null
                                    ? DateFormat.yMMMd().format(invoice.createdAt!)
                                    : '',
                              ),
                              trailing: Text(
                                context.formatCurrency(invoice.totalPrice),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
