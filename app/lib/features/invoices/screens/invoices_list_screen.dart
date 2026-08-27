import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/invoice_model.dart';
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
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InvoiceModel> _filter(List<InvoiceModel> invoices) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return invoices;
    return invoices.where((inv) {
      final number = inv.invoiceNumber.toLowerCase();
      final client = (inv.clientName ?? '').toLowerCase();
      final phone = (inv.clientPhone ?? '').toLowerCase();
      return number.contains(q) || client.contains(q) || phone.contains(q);
    }).toList();
  }

  DateTime _dayKey(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateHeaderLabel(BuildContext context, DateTime day) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return l10n.today;
    if (day == yesterday) return l10n.yesterday;
    return DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(day);
  }

  List<_ListRow> _buildRows(List<InvoiceModel> invoices) {
    final rows = <_ListRow>[];
    DateTime? lastDay;
    for (final invoice in invoices) {
      final created = invoice.createdAt?.toLocal() ?? DateTime.now();
      final day = _dayKey(created);
      if (lastDay == null || day != lastDay) {
        rows.add(_ListRow.header(day));
        lastDay = day;
      }
      rows.add(_ListRow.invoice(invoice));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.distributionInvoices),
        actions: [
          if (widget.basePath.contains('admin'))
            IconButton(
              icon: const Icon(Icons.payments_outlined),
              tooltip: context.l10n.collectionInvoices,
              onPressed: () => context.push('/admin/collection-invoices'),
            ),
          if (widget.basePath.contains('employee'))
            IconButton(
              icon: const Icon(Icons.payments_outlined),
              tooltip: context.l10n.collectionInvoices,
              onPressed: () => context.go('/employee/collection-invoices'),
            ),
          if (widget.basePath.contains('employee') || widget.basePath.contains('admin'))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: context.l10n.distributionReceipt,
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
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const LoadingShimmer(),
              error: (e, _) => ErrorStateWidget(
                message: apiErrorMessage(e, fallback: l10n.serverError),
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (result) {
                final filtered = _filter(result.invoices);
                if (filtered.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.receipt_long,
                    title: l10n.noInvoicesFound,
                  );
                }
                final rows = _buildRows(filtered);
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(invoicesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final row = rows[i];
                      if (row.isHeader) {
                        return _DateSectionHeader(
                          label: _dateHeaderLabel(context, row.day!),
                        );
                      }
                      final invoice = row.invoice!;
                      final time = invoice.createdAt != null
                          ? DateFormat.jm(Localizations.localeOf(context).toString())
                              .format(invoice.createdAt!.toLocal())
                          : '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () =>
                              context.go('${widget.basePath}/invoices/${invoice.id}'),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryGreen.withValues(alpha: 0.15),
                            child: const Icon(Icons.receipt, color: AppColors.primaryGreen),
                          ),
                          title: Text(invoice.invoiceNumber),
                          subtitle: Text(
                            [
                              invoice.clientName ?? 'Client',
                              if (time.isNotEmpty) time,
                            ].join(' • '),
                          ),
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

class _ListRow {
  const _ListRow._({this.day, this.invoice});

  factory _ListRow.header(DateTime day) => _ListRow._(day: day);
  factory _ListRow.invoice(InvoiceModel invoice) => _ListRow._(invoice: invoice);

  final DateTime? day;
  final InvoiceModel? invoice;

  bool get isHeader => day != null;
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.45), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.45), thickness: 1)),
            ],
          ),
        ],
      ),
    );
  }
}
