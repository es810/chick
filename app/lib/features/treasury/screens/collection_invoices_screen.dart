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
      body: _loading
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
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _entries.length,
                        itemBuilder: (_, i) {
                          final entry = _entries[i];
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
                                  if (entry.collectionDate != null)
                                    DateFormat.yMMMd().format(entry.collectionDate!),
                                  if (entry.employeeName != null) entry.employeeName!,
                                  '${l10n.amountPaid}: ${context.formatCurrency(entry.amountPaid ?? entry.amount)}',
                                  '${l10n.balanceAfterPayment}: ${(entry.balanceAfter ?? 0).toStringAsFixed(2)}',
                                ].join(' · '),
                                maxLines: 3,
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
                    ),
    );
  }
}
