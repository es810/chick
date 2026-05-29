import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key, this.basePath = '/admin'});

  final String basePath;

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          if (widget.basePath.contains('employee') || widget.basePath.contains('admin'))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: context.l10n.createInvoice,
              onPressed: () => context.go('${widget.basePath}/invoices/create'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.searchInvoices,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onSubmitted: (_) => ref.invalidate(invoicesProvider),
            ),
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: e.toString(),
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (result) {
                if (result.invoices.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.receipt_long,
                    title: 'No invoices found',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(invoicesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: result.invoices.length,
                    itemBuilder: (_, i) {
                      final invoice = result.invoices[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => context.go('${widget.basePath}/invoices/${invoice.id}'),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                            child: const Icon(Icons.receipt, color: AppColors.primaryGreen),
                          ),
                          title: Text(invoice.invoiceNumber),
                          subtitle: Text('${invoice.clientName ?? "Client"} • ${invoice.items.length} items'),
                          trailing: Text(
                            context.formatCurrency(invoice.totalPrice),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
