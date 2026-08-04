import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/treasury_summary_model.dart';
import '../../settings/screens/employees_screen.dart';
import '../../stock/screens/stock_screen.dart';
import '../../../models/treasury_entry_item.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../widgets/treasury_category_sheet.dart';

class AdminTreasuryScreen extends ConsumerStatefulWidget {
  const AdminTreasuryScreen({super.key});

  @override
  ConsumerState<AdminTreasuryScreen> createState() => _AdminTreasuryScreenState();
}

class _AdminTreasuryScreenState extends ConsumerState<AdminTreasuryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSubmitting = false;

  static const _pageBlue = Color(0xFF0D1B3E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(treasurySummaryProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(clientsProvider);
  }

  Future<void> _showAmountDialog({
    required String title,
    required Future<void> Function(double amount, String? description) onSubmit,
  }) async {
    final l10n = context.l10n;
    final amountController = TextEditingController();
    final descController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.amountEgp),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: l10n.descriptionOptional),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invalidAmount), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await onSubmit(amount, description.isEmpty ? null : description);
      await _refresh();
      if (mounted) {
        final msg = title == context.l10n.addExternalRevenue
            ? context.l10n.revenueAdded
            : context.l10n.withdrawalDone;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: _pageBlue,
      appBar: AppBar(
        backgroundColor: _pageBlue,
        foregroundColor: Colors.white,
        title: Text(l10n.treasury),
        actions: [
          IconButton(
            onPressed: _isSubmitting ? null : _confirmResetTreasury,
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: l10n.zeroTreasury,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: l10n.treasury),
            Tab(text: l10n.employeesTreasury),
            Tab(text: l10n.stock),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MainTreasuryTab(
            isSubmitting: _isSubmitting,
            onRefresh: _refresh,
            onWithdraw: () => _showAmountDialog(
              title: l10n.withdrawFromTreasury,
              onSubmit: (amount, desc) =>
                  ref.read(treasuryRepositoryProvider).withdraw(amount, description: desc),
            ),
            onAddRevenue: () => _showAmountDialog(
              title: l10n.addExternalRevenue,
              onSubmit: (amount, desc) =>
                  ref.read(treasuryRepositoryProvider).addExternalRevenue(amount, description: desc),
            ),
            onEditBalance: () => _showEditBalanceDialog(),
            onReset: () => _confirmResetTreasury(),
          ),
          const EmployeesScreen(embedded: true),
          const StockScreen(embedded: true),
        ],
      ),
    );
  }

  Future<void> _showEditBalanceDialog() async {
    final l10n = context.l10n;
    final summary = ref.read(treasurySummaryProvider).valueOrNull;
    final controller = TextEditingController(
      text: (summary?.openingBalance ?? 0).toStringAsFixed(2),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.openingBalance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.treasuryFormula, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.openingBalance),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.save)),
        ],
      ),
    );

    if (ok != true || !mounted) {
      controller.dispose();
      return;
    }

    final amount = double.tryParse(controller.text.trim().replaceAll(',', ''));
    controller.dispose();
    if (amount == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(treasuryRepositoryProvider).updateOpeningBalance(amount);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treasuryUpdated), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmResetTreasury() async {
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

    if (ok != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(treasuryRepositoryProvider).resetMainTreasury();
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.treasuryZeroed), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _MainTreasuryTab extends ConsumerWidget {
  const _MainTreasuryTab({
    required this.isSubmitting,
    required this.onRefresh,
    required this.onWithdraw,
    required this.onAddRevenue,
    required this.onEditBalance,
    required this.onReset,
  });

  final bool isSubmitting;
  final Future<void> Function() onRefresh;
  final VoidCallback onWithdraw;
  final VoidCallback onAddRevenue;
  final VoidCallback onEditBalance;
  final VoidCallback onReset;

  void _openCategory(
    BuildContext context,
    WidgetRef ref,
    TreasuryCategory category,
    String title,
  ) {
    showTreasuryCategorySheet(
      context: context,
      ref: ref,
      category: category,
      title: title,
      onRefresh: onRefresh,
      onEditOpening: onEditBalance,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summaryAsync = ref.watch(treasurySummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, _) => ErrorStateWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(treasurySummaryProvider),
      ),
      data: (summary) => RefreshIndicator(
        onRefresh: onRefresh,
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _FinancialCard(
              summary: summary,
              onEdit: onEditBalance,
              onReset: onReset,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.treasuryFormula,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.manageEntries,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white38),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _MetricRow(
              label: l10n.openingBalance,
              value: summary.openingBalance,
              valueColor: Colors.white,
              icon: Icons.account_balance,
              iconColor: Colors.white70,
              onTap: () => _openCategory(context, ref, TreasuryCategory.opening, l10n.openingBalance),
            ),
            _MetricRow(
              label: l10n.stockValue,
              value: summary.stockValue,
              valueColor: const Color(0xFF26A69A),
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFF26A69A),
              onTap: () => context.push('/admin/stock'),
            ),
            _MetricRow(
              label: l10n.totalCollection,
              value: summary.totalCollection,
              valueColor: const Color(0xFF66BB6A),
              icon: Icons.payments,
              iconColor: const Color(0xFF66BB6A),
              onTap: () => context.push('/admin/collection-invoices'),
            ),
            _MetricRow(
              label: l10n.externalRevenue,
              value: summary.externalRevenue,
              valueColor: const Color(0xFFAB47BC),
              icon: Icons.account_balance,
              iconColor: const Color(0xFFAB47BC),
              onTap: () => _openCategory(context, ref, TreasuryCategory.externalRevenue, l10n.externalRevenue),
            ),
            _MetricRow(
              label: l10n.totalLoading,
              value: summary.totalLoading,
              valueColor: const Color(0xFF29B6F6),
              icon: Icons.local_shipping,
              iconColor: const Color(0xFF29B6F6),
              onTap: () => _openCategory(context, ref, TreasuryCategory.loading, l10n.totalLoading),
            ),
            _MetricRow(
              label: l10n.otherExpenses,
              value: summary.otherExpenses,
              valueColor: const Color(0xFFFFA726),
              icon: Icons.receipt_long,
              iconColor: const Color(0xFFFFA726),
              onTap: () => _openCategory(context, ref, TreasuryCategory.expense, l10n.otherExpenses),
            ),
            _MetricRow(
              label: l10n.withdrawals,
              value: summary.withdrawals,
              valueColor: const Color(0xFFEF5350),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFFEF5350),
              onTap: () => _openCategory(context, ref, TreasuryCategory.withdrawal, l10n.withdrawals),
            ),
            _MetricRow(
              label: l10n.totalTreasuryBalance,
              value: summary.balance,
              valueColor: Colors.white,
              icon: Icons.savings,
              iconColor: Colors.white70,
              isTotal: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : () => context.push('/admin/collection-invoices'),
                icon: const Icon(Icons.payments),
                label: Text(l10n.collectionInvoice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isSubmitting)
              const Center(child: CircularProgressIndicator(color: Colors.white))
            else
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: l10n.withdrawFromTreasury,
                      icon: Icons.upload,
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      onPressed: onWithdraw,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: l10n.addExternalRevenue,
                      icon: Icons.add_circle_outline,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      onPressed: onAddRevenue,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onReset,
                icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white),
                label: Text(l10n.zeroTreasury),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({
    required this.summary,
    required this.onEdit,
    required this.onReset,
  });

  final TreasurySummaryModel summary;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 56),
              Positioned(
                left: 0,
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                  tooltip: l10n.editTreasury,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  onPressed: onReset,
                  icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white70, size: 22),
                  tooltip: l10n.zeroTreasury,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.financialTreasury,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.formatCurrency(summary.balance),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (summary.stockValue > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${l10n.stockValue}: ${context.formatCurrency(summary.stockValue)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF80CBC4),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    this.isTotal = false,
    this.onTap,
  });

  final String label;
  final double value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;
  final bool isTotal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        if (onTap != null)
          Icon(Icons.chevron_left, color: Colors.white.withValues(alpha: 0.4), size: 20),
        Text(
          'EGP ${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 16 : 15,
          ),
        ),
        const Spacer(),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isTotal ? 1 : 0.9),
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(width: 10),
        Icon(icon, color: iconColor, size: 22),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isTotal
            ? const Color(0xFF1A237E).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: onTap == null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: content,
            )
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: foregroundColor, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
