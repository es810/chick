import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/treasury_entry_item.dart';
import 'collection_invoice_form.dart';

Future<void> showTreasuryCategorySheet({
  required BuildContext context,
  required WidgetRef ref,
  required TreasuryCategory category,
  required String title,
  required Future<void> Function() onRefresh,
  VoidCallback? onEditOpening,
}) async {
  if (category == TreasuryCategory.opening) {
    onEditOpening?.call();
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0D1B3E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => _TreasuryCategorySheet(
        category: category,
        title: title,
        scrollController: scrollController,
        onRefresh: onRefresh,
      ),
    ),
  );
}

class _TreasuryCategorySheet extends ConsumerStatefulWidget {
  const _TreasuryCategorySheet({
    required this.category,
    required this.title,
    required this.scrollController,
    required this.onRefresh,
  });

  final TreasuryCategory category;
  final String title;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_TreasuryCategorySheet> createState() => _TreasuryCategorySheetState();
}

class _TreasuryCategorySheetState extends ConsumerState<_TreasuryCategorySheet> {
  List<TreasuryEntryItem> _entries = [];
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _amountLabel(AppLocalizations l10n) {
    if (widget.category == TreasuryCategory.collection) {
      return l10n.collectedAmount;
    }
    return l10n.amountEgp;
  }

  String _addButtonLabel(AppLocalizations l10n) {
    if (widget.category == TreasuryCategory.collection) {
      return l10n.collectionInvoice;
    }
    return l10n.addEntry;
  }

  String _entrySubtitle(TreasuryEntryItem entry) {
    if (entry.isCollectionInvoice) {
      final parts = <String>[
        if (entry.clientName != null && entry.clientName!.isNotEmpty) entry.clientName!,
        if (entry.employeeName != null && entry.employeeName!.isNotEmpty) entry.employeeName!,
        if (entry.collectionDate != null)
          DateFormat.yMMMd().format(entry.collectionDate!),
        '${context.l10n.balanceBeforePayment}: ${entry.balanceBefore?.toStringAsFixed(2) ?? '0'}',
        '${context.l10n.balanceAfterPayment}: ${entry.balanceAfter?.toStringAsFixed(2) ?? '0'}',
      ];
      return parts.join(' · ');
    }
    return [
      if (entry.description.isNotEmpty) entry.description,
      if (entry.subtitle.isNotEmpty) entry.subtitle,
    ].join(' · ');
  }

  Future<void> _openEntryForm({TreasuryEntryItem? existing}) async {
    if (widget.category == TreasuryCategory.collection) {
      final l10n = context.l10n;
      final ok = await showCollectionInvoiceDialog(
        context: context,
        ref: ref,
        existing: existing,
      );
      if (ok == true && mounted) {
        await _afterMutation();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? l10n.entryAdded : l10n.entryUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return;
    }
    await _showSimpleEntryDialog(existing: existing);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(treasuryRepositoryProvider);
      final entries = await repo.listEntries(widget.category);
      List<Map<String, dynamic>> employees = [];
      if (widget.category.needsEmployee) {
        employees = await repo.listEmployees();
      }
      if (mounted) {
        setState(() {
          _entries = entries;
          _employees = employees;
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

  Future<void> _afterMutation() async {
    ref.invalidate(clientsProvider);
    await widget.onRefresh();
    await _load();
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
      await ref.read(treasuryRepositoryProvider).deleteEntry(
            category: widget.category,
            id: entry.id,
          );
      await _afterMutation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.entryDeleted), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showSimpleEntryDialog({TreasuryEntryItem? existing}) async {
    final l10n = context.l10n;
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(2) : '',
    );
    final descController = TextEditingController(text: existing?.description ?? '');
    String? selectedEmployeeId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? _addButtonLabel(l10n) : l10n.editEntry),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.category.needsEmployee && existing == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedEmployeeId,
                    decoration: InputDecoration(labelText: l10n.selectEmployee),
                    items: _employees
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: (e['_id'] ?? e['id']).toString(),
                            child: Text(e['name'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedEmployeeId = v),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: _amountLabel(l10n)),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: l10n.descriptionOptional),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) {
      amountController.dispose();
      descController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
    final description = descController.text.trim();
    amountController.dispose();
    descController.dispose();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
      );
      return;
    }

    if (widget.category.needsEmployee && existing == null && selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectEmployee), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(treasuryRepositoryProvider);
      if (existing == null) {
        await repo.createEntry(
          category: widget.category,
          amount: amount,
          description: description.isEmpty ? null : description,
          employeeId: selectedEmployeeId,
        );
      } else {
        await repo.updateEntry(
          category: widget.category,
          id: existing.id,
          amount: amount,
          description: description.isEmpty ? null : description,
        );
      }
      await _afterMutation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null ? l10n.entryAdded : l10n.entryUpdated),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _error != null
                  ? Center(
                      child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                    )
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            l10n.noTreasuryEntries,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) {
                            final entry = _entries[i];
                            return Card(
                              color: Colors.white.withValues(alpha: 0.08),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: _submitting ? null : () => _openEntryForm(existing: entry),
                                title: Text(
                                  entry.isCollectionInvoice
                                      ? '${entry.clientName ?? entry.description} — ${context.formatCurrency(entry.amountPaid ?? entry.amount)}'
                                      : context.formatCurrency(entry.amount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  _entrySubtitle(entry),
                                  style: const TextStyle(color: Colors.white60),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _openEntryForm(existing: entry);
                                    } else if (action == 'delete') {
                                      _confirmDelete(entry);
                                    }
                                  },
                                  itemBuilder: (_) => [
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
                              ),
                            );
                          },
                        ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : () => _openEntryForm(),
                icon: const Icon(Icons.add),
                label: Text(_addButtonLabel(l10n)),
              ),
            ),
          ),
        ),
        if (_submitting)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: CircularProgressIndicator(color: Colors.white),
          ),
      ],
    );
  }
}
