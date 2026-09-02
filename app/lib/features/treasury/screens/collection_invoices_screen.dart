import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/treasury_entry_item.dart';
import '../../../shared/widgets/collection_pdf_actions.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../widgets/collection_invoice_form.dart';

class CollectionInvoicesScreen extends ConsumerStatefulWidget {
  const CollectionInvoicesScreen({super.key, this.basePath});

  /// `/admin` or `/employee`. Inferred from route when null.
  final String? basePath;

  @override
  ConsumerState<CollectionInvoicesScreen> createState() =>
      _CollectionInvoicesScreenState();
}

class _CollectionInvoicesScreenState extends ConsumerState<CollectionInvoicesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<TreasuryEntryItem> _entries = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  String get _basePath {
    if (widget.basePath != null) return widget.basePath!;
    final location = GoRouterState.of(context).matchedLocation;
    return location.startsWith('/employee') ? '/employee' : '/admin';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await ref.read(collectionRepositoryProvider).listInvoices();
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(treasurySummaryProvider);
    ref.invalidate(clientsProvider);
    ref.invalidate(dashboardProvider);
    await _load();
  }

  List<TreasuryEntryItem> _filter(List<TreasuryEntryItem> entries) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((entry) {
      final client = (entry.clientName ?? '').toLowerCase();
      final phone = (entry.clientPhone ?? '').toLowerCase();
      final employee = (entry.employeeName ?? '').toLowerCase();
      final description = entry.description.toLowerCase();
      final amount = (entry.amountPaid ?? entry.amount).toStringAsFixed(2);
      return client.contains(q) ||
          phone.contains(q) ||
          employee.contains(q) ||
          description.contains(q) ||
          amount.contains(q);
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

  List<_ListRow> _buildRows(List<TreasuryEntryItem> entries) {
    final rows = <_ListRow>[];
    DateTime? lastDay;
    for (final entry in entries) {
      final date = entry.collectionDate?.toLocal() ??
          entry.createdAt?.toLocal() ??
          DateTime.now();
      final day = _dayKey(date);
      if (lastDay == null || day != lastDay) {
        rows.add(_ListRow.header(day));
        lastDay = day;
      }
      rows.add(_ListRow.entry(entry));
    }
    return rows;
  }

  Future<void> _openCreateForm() async {
    final l10n = context.l10n;
    final saved = await showCollectionInvoiceDialog(
      context: context,
      ref: ref,
    );
    if (saved != null && mounted) {
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.entryAdded),
          backgroundColor: AppColors.success,
        ),
      );
      await showCollectionShareDialog(context: context, entry: saved);
    }
  }

  void _openDetail(TreasuryEntryItem entry) {
    context.push('$_basePath/collection-invoices/${entry.id}');
  }

  Future<void> _confirmDelete(TreasuryEntryItem entry) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.confirmDeleteTreasuryEntry),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(collectionRepositoryProvider).deleteInvoice(entry.id);
      if (entry.clientId != null) {
        ref.invalidate(clientStatementProvider(entry.clientId!));
      }
      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.entryDeleted), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e)), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.collectionInvoices),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _openCreateForm,
        icon: const Icon(Icons.payments),
        label: Text(l10n.collectionInvoice),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchCollectionInvoices,
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
            child: _loading
                ? const LoadingShimmer()
                : _error != null
                    ? ErrorStateWidget(message: _error!, onRetry: _load)
                    : _entries.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.payments,
                            title: l10n.noCollectionInvoices,
                            action: ElevatedButton.icon(
                              onPressed: _openCreateForm,
                              icon: const Icon(Icons.add),
                              label: Text(l10n.collectionInvoice),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              final filtered = _filter(_entries);
                              if (filtered.isEmpty) {
                                return EmptyStateWidget(
                                  icon: Icons.search_off,
                                  title: l10n.noCollectionInvoicesMatch,
                                );
                              }
                              final rows = _buildRows(filtered);
                              return RefreshIndicator(
                                onRefresh: _refreshAll,
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                  itemCount: rows.length,
                                  itemBuilder: (_, i) {
                                    final row = rows[i];
                                    if (row.isHeader) {
                                      return _DateSectionHeader(
                                        label: _dateHeaderLabel(context, row.day!),
                                      );
                                    }
                                    final entry = row.entry!;
                                    final time = entry.collectionDate != null
                                        ? DateFormat.jm(
                                                Localizations.localeOf(context).toString())
                                            .format(entry.collectionDate!.toLocal())
                                        : '';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        onTap: _submitting ? null : () => _openDetail(entry),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              const Color(0xFF66BB6A).withValues(alpha: 0.15),
                                          child: const Icon(Icons.payments, color: Color(0xFF66BB6A)),
                                        ),
                                        title: Text(entry.clientName ?? entry.description),
                                        subtitle: Text(
                                          [
                                            if (time.isNotEmpty) time,
                                            if (entry.employeeName != null) entry.employeeName!,
                                            '${l10n.amountPaid}: ${context.formatCurrency(entry.amountPaid ?? entry.amount)}',
                                            if ((entry.amountDeducted ?? 0) > 0)
                                              '${l10n.statementDiscount}: ${context.formatCurrency(entry.amountDeducted!)}',
                                            '${l10n.balanceAfterPayment}: ${context.formatCurrency(entry.balanceAfter ?? 0)}',
                                          ].join(' · '),
                                          maxLines: 4,
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CollectionPdfActions(
                                              entry: entry,
                                              clientPhone: entry.clientPhone,
                                              compact: true,
                                            ),
                                            PopupMenuButton<String>(
                                              onSelected: (action) {
                                                if (action == 'share') {
                                                  showCollectionShareDialog(
                                                    context: context,
                                                    entry: entry,
                                                  );
                                                } else if (action == 'edit') {
                                                  _openDetail(entry);
                                                } else if (action == 'delete') {
                                                  _confirmDelete(entry);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                PopupMenuItem(
                                                  value: 'share',
                                                  child: Text(l10n.shareInvoice),
                                                ),
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text(l10n.editEntry),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                    l10n.delete,
                                                    style: const TextStyle(color: AppColors.error),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
  const _ListRow._({this.day, this.entry});

  factory _ListRow.header(DateTime day) => _ListRow._(day: day);
  factory _ListRow.entry(TreasuryEntryItem entry) => _ListRow._(entry: entry);

  final DateTime? day;
  final TreasuryEntryItem? entry;

  bool get isHeader => day != null;
}

class _DateSectionHeader extends StatelessWidget {
  const _DateSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Row(
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
    );
  }
}
