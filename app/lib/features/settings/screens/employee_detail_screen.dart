import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/employee_ledger_model.dart';
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
    _load();
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
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isExpense ? l10n.addExpense : l10n.addDebt),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isExpense)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.employeeDebtHint,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l10n.amount),
              ),
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
    );

    if (confirmed != true || !mounted) {
      amountController.dispose();
      descController.dispose();
      return;
    }

    final amount = double.tryParse(amountController.text.trim().replaceAll(',', ''));
    final description = descController.text.trim();
    amountController.dispose();
    descController.dispose();

    if (amount == null || amount <= 0 || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
      );
      return;
    }

    try {
      final repo = ref.read(employeeRepositoryProvider);
      if (isExpense) {
        await repo.addExpense(widget.employeeId, amount, description);
      } else {
        await repo.addDebt(widget.employeeId, amount, description);
      }
      ref.invalidate(dashboardProvider);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deductedFromMainTreasury),
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
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
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddDialog(isExpense: true),
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addExpense),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAddDialog(isExpense: false),
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addDebt),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._buildEntries(_ledger!.entries.where((e) => e.isExpense).toList(), l10n),
                      const SizedBox(height: 20),
                      Text(l10n.employeeDebt, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        l10n.employeeDebtHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ..._buildEntries(_ledger!.entries.where((e) => e.isDebt).toList(), l10n),
                    ],
                  ),
                ),
    );
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
          subtitle: Text(
            entry.createdAt != null
                ? DateFormat.yMMMd().add_jm().format(entry.createdAt!)
                : '',
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              context.formatCurrency(amount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
