import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/number_input_utils.dart';
import '../../../models/employee_ledger_model.dart';
import '../../../models/supplier_model.dart';
import '../../../shared/widgets/invoice_number_field.dart';
import '../../../shared/widgets/loading_widget.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employeeId, required this.employeeName});

  final String employeeId;
  final String employeeName;

  @override
  ConsumerState<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  EmployeeLedgerSummary? _ledger;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ledger = await ref.read(employeeRepositoryProvider).getLedger(widget.employeeId);
      if (mounted) {
        setState(() {
          _ledger = ledger;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _showAddDialog({required bool isExpense}) async {
    final l10n = context.l10n;
    final amountController = TextEditingController();
    final discountController = TextEditingController();
    final descController = TextEditingController();
    String? selectedSupplierId;
    List<SupplierModel> suppliers = [];

    void disposeControllers() {
      amountController.dispose();
      discountController.dispose();
      descController.dispose();
    }

    if (!isExpense) {
      try {
        suppliers = await ref.read(suppliersProvider.future);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
          );
        }
        disposeControllers();
        return;
      }
    }

    if (!mounted) {
      disposeControllers();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isExpense ? l10n.addExpense : l10n.addDebt),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isExpense) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.employeeDebtHint,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedSupplierId ?? 'supplier'),
                    initialValue: selectedSupplierId,
                    decoration: InputDecoration(labelText: l10n.selectSupplier),
                    items: suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              '${s.name} — ${context.formatCurrency(s.balance)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => selectedSupplierId = value),
                  ),
                  const SizedBox(height: 12),
                ],
                InvoiceNumberField(
                  controller: amountController,
                  labelText: l10n.amount,
                ),
                if (!isExpense) ...[
                  const SizedBox(height: 12),
                  InvoiceNumberField(
                    controller: discountController,
                    labelText: l10n.amountDeducted,
                    helperText: l10n.discountOptionalHint,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: l10n.description,
                    hintText: isExpense ? l10n.expenseDescriptionHint : l10n.debtDescriptionHint,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deductedFromMainTreasury,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.add)),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      disposeControllers();
      return;
    }

    final amount = parseInputNumber(amountController.text);
    final amountDeducted = isExpense ? 0.0 : parseInputNumber(discountController.text);
    final description = descController.text.trim();
    SupplierModel? supplierForDebt;
    if (selectedSupplierId != null) {
      for (final s in suppliers) {
        if (s.id == selectedSupplierId) {
          supplierForDebt = s;
          break;
        }
      }
    }
    disposeControllers();

    if (amount <= 0 || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!isExpense && (selectedSupplierId == null || selectedSupplierId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supplierRequired), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!isExpense) {
      if (amountDeducted < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
        );
        return;
      }
      final maxDebt = supplierForDebt?.balance ?? 0;
      if (amount + amountDeducted > maxDebt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.paymentExceedsSupplierDebt), backgroundColor: AppColors.error),
        );
        return;
      }
    }

    try {
      final repo = ref.read(employeeRepositoryProvider);
      if (isExpense) {
        await repo.addExpense(widget.employeeId, amount, description);
      } else {
        await repo.addDebt(
          widget.employeeId,
          amount,
          description,
          selectedSupplierId!,
          amountDeducted: amountDeducted,
        );
        ref.invalidate(supplierStatementProvider(selectedSupplierId!));
        ref.invalidate(suppliersProvider);
      }
      ref.invalidate(dashboardProvider);
      ref.invalidate(treasurySummaryProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isExpense ? l10n.deductedFromMainTreasury : l10n.supplierPaymentRecorded),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Insufficient') ? l10n.insufficientTreasury : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }

  double _remainingAdvanceThisMonth() {
    if (_ledger == null) return 0;
    final now = DateTime.now();
    final taken = _ledger!.advances
        .where(
          (a) =>
              a.advanceDate.year == now.year && a.advanceDate.month == now.month,
        )
        .fold<double>(0, (sum, a) => sum + a.amount);
    return (_ledger!.employeeSalary - taken).clamp(0, double.infinity);
  }

  Future<void> _showAddAdvanceDialog() async {
    final l10n = context.l10n;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    var advanceDate = DateTime.now();
    final remaining = _remainingAdvanceThisMonth();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.addSalaryAdvance),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.salaryAdvanceHint,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                if (_ledger!.employeeSalary > 0) ...[
                  Text('${l10n.employeeSalary}: ${context.formatCurrency(_ledger!.employeeSalary)}'),
                  Text(
                    '${l10n.remainingSalaryAdvance}: ${context.formatCurrency(remaining)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.paymentDate),
                  subtitle: Text(DateFormat.yMMMd().format(advanceDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: advanceDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => advanceDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.paymentAmount),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.notesOptional),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.deductedFromSalary,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.add)),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      amountController.dispose();
      notesController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
    final notes = notesController.text.trim();
    amountController.dispose();
    notesController.dispose();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_ledger!.employeeSalary > 0 && amount > remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.advanceExceedsSalary), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      await ref.read(employeeRepositoryProvider).addSalaryAdvance(
            employeeId: widget.employeeId,
            advanceDate: advanceDate,
            amount: amount,
            notes: notes,
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(treasurySummaryProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.salaryAdvanceRecorded),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('Insufficient')
            ? l10n.insufficientTreasury
            : e.toString().contains('remaining salary')
                ? l10n.advanceExceedsSalary
                : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayName =
        widget.employeeName.isNotEmpty ? widget.employeeName : (_ledger?.employeeName ?? l10n.employee);

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: _loading
          ? const LoadingOverlay()
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _SummaryCard(
                              title: l10n.employeeTreasuryBalance,
                              amount: _ledger!.treasuryBalance,
                              icon: Icons.account_balance_wallet,
                              color: _ledger!.treasuryBalance >= 0
                                  ? AppColors.primaryGreen
                                  : AppColors.error,
                              subtitle: l10n.employeeTreasuryFormula,
                              onTap: () => context.push(
                                '/admin/employees/${widget.employeeId}/treasury-statement',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => context.push(
                                  '/admin/employees/${widget.employeeId}/treasury-statement',
                                ),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: Text(l10n.viewAccountStatement),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: l10n.expenses,
                                    amount: _ledger!.totalExpenses,
                                    icon: Icons.local_gas_station,
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    title: l10n.employeeDebt,
                                    amount: _ledger!.totalDebt,
                                    icon: Icons.inventory_2,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    title: l10n.salaryAdvance,
                                    amount: _ledger!.totalAdvances,
                                    icon: Icons.payments_outlined,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    title: l10n.employeeSalary,
                                    amount: _ledger!.employeeSalary,
                                    icon: Icons.account_balance_wallet_outlined,
                                    color: AppColors.darkGreen,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showAddAdvanceDialog,
                                icon: const Icon(Icons.payments_outlined),
                                label: Text(l10n.addSalaryAdvance),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.salaryAdvanceHint,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 24),
                            Text(l10n.salaryAdvance, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            ..._buildAdvanceEntries(_ledger!.advances, l10n),
                            const SizedBox(height: 24),
                            Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                          ]),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _EmployeeActionButtonsHeader(
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          onAddExpense: () => _showAddDialog(isExpense: true),
                          onAddDebt: () => _showAddDialog(isExpense: false),
                          addExpenseLabel: l10n.addExpense,
                          addDebtLabel: l10n.addDebt,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            _buildEntries(
                              _ledger!.entries.where((e) => e.isExpense).toList(),
                              l10n,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text(l10n.employeeDebt, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              l10n.employeeDebtHint,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            ..._buildEntries(
                              _ledger!.entries.where((e) => e.isDebt).toList(),
                              l10n,
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _buildAdvanceEntries(List<SalaryAdvanceEntry> entries, AppLocalizations l10n) {
    if (entries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.noLedgerEntries, style: const TextStyle(color: Colors.grey)),
        ),
      ];
    }
    return entries.map((entry) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.15),
            child: const Icon(Icons.payments_outlined, color: AppColors.primaryGreen),
          ),
          title: Text(l10n.salaryAdvance),
          subtitle: Text(
            [
              DateFormat.yMMMd().format(entry.advanceDate),
              if (entry.notes.isNotEmpty) entry.notes,
            ].join(' · '),
          ),
          trailing: Text(
            context.formatCurrency(entry.amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildEntries(List<EmployeeLedgerEntry> entries, AppLocalizations l10n) {
    if (entries.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.noLedgerEntries, style: const TextStyle(color: Colors.grey)),
        ),
      ];
    }
    return entries.map((entry) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: (entry.isExpense ? AppColors.warning : AppColors.error)
                .withValues(alpha: 0.15),
            child: Icon(
              entry.isExpense ? Icons.receipt : Icons.shopping_bag,
              color: entry.isExpense ? AppColors.warning : AppColors.error,
            ),
          ),
          title: Text(entry.description),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.isDebt && entry.supplierName != null && entry.supplierName!.isNotEmpty)
                Text('${l10n.suppliers}: ${entry.supplierName}'),
              if (entry.createdAt != null)
                Text(DateFormat.yMMMd().add_jm().format(entry.createdAt!)),
            ],
          ),
          trailing: Text(
            context.formatCurrency(entry.amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
  }
}

class _EmployeeActionButtonsHeader extends SliverPersistentHeaderDelegate {
  const _EmployeeActionButtonsHeader({
    required this.backgroundColor,
    required this.onAddExpense,
    required this.onAddDebt,
    required this.addExpenseLabel,
    required this.addDebtLabel,
  });

  final Color backgroundColor;
  final VoidCallback onAddExpense;
  final VoidCallback onAddDebt;
  final String addExpenseLabel;
  final String addDebtLabel;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add),
                label: Text(addExpenseLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddDebt,
                icon: const Icon(Icons.add),
                label: Text(addDebtLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _EmployeeActionButtonsHeader oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.addExpenseLabel != addExpenseLabel ||
        oldDelegate.addDebtLabel != addDebtLabel;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  if (onTap != null) ...[
                    const Spacer(),
                    Icon(Icons.chevron_left, color: Colors.grey.shade600),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                context.formatCurrency(amount),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
