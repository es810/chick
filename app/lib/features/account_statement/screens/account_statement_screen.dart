import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/account_statement_model.dart';
import '../../../models/user_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';

enum AccountStatementKind { client, supplier }

class AccountStatementScreen extends ConsumerWidget {
  const AccountStatementScreen({
    super.key,
    required this.entityId,
    required this.entityName,
    required this.kind,
  });

  final String entityId;
  final String entityName;
  final AccountStatementKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final statementAsync = kind == AccountStatementKind.client
        ? ref.watch(clientStatementProvider(entityId))
        : ref.watch(supplierStatementProvider(entityId));
    final isAdmin = ref.watch(currentUserProvider)?.role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.accountStatement} — $entityName'),
      ),
      floatingActionButton: kind == AccountStatementKind.supplier && isAdmin
          ? statementAsync.maybeWhen(
              data: (statement) => statement.entity.balance > 0
                  ? FloatingActionButton.extended(
                      onPressed: () => _showPayDebtDialog(context, ref, statement),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(l10n.paySupplierDebt),
                    )
                  : null,
              orElse: () => null,
            )
          : null,
      body: statementAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(
            e,
            fallback: e is DioException && e.response?.statusCode == 401
                ? l10n.sessionExpired
                : l10n.serverError,
          ),
          onRetry: () => _invalidate(ref),
        ),
        data: (statement) => RefreshIndicator(
          onRefresh: () async => _invalidate(ref),
          child: _StatementBody(statement: statement, kind: kind),
        ),
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    if (kind == AccountStatementKind.client) {
      ref.invalidate(clientStatementProvider(entityId));
    } else {
      ref.invalidate(supplierStatementProvider(entityId));
    }
  }

  Future<void> _showPayDebtDialog(
    BuildContext context,
    WidgetRef ref,
    AccountStatement statement,
  ) async {
    final l10n = context.l10n;
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    var paymentDate = DateTime.now();
    final formKey = GlobalKey<FormState>();
    final maxDebt = statement.entity.balance;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.paySupplierDebt),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l10n.supplierDebt}: ${context.formatCurrency(maxDebt)}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.paymentDate),
                    subtitle: Text(DateFormat.yMMMd().format(paymentDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => paymentDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.paymentAmount,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.fieldRequired;
                      final amount = double.tryParse(v.trim());
                      if (amount == null || amount <= 0) return l10n.invalidAmount;
                      if (amount > maxDebt) return l10n.paymentExceedsSupplierDebt;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: l10n.notesOptional,
                      prefixIcon: const Icon(Icons.notes_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    final amount = double.parse(amountController.text.trim());

    try {
      await ref.read(supplierRepositoryProvider).payDebt(
            supplierId: entityId,
            paymentDate: paymentDate,
            amount: amount,
            notes: notesController.text.trim(),
          );
      ref.invalidate(supplierStatementProvider(entityId));
      ref.invalidate(suppliersProvider);
      ref.invalidate(treasurySummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.supplierPaymentRecorded)),
        );
      }
    } on DioException catch (e) {
      if (!context.mounted) return;
      final message = e.response?.data is Map &&
              (e.response!.data as Map)['message'] == 'Insufficient main treasury balance'
          ? l10n.insufficientTreasury
          : apiErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _StatementBody extends StatelessWidget {
  const _StatementBody({required this.statement, required this.kind});

  final AccountStatement statement;
  final AccountStatementKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entity = statement.entity;
    final debtLabel = kind == AccountStatementKind.client ? l10n.clientDebt : l10n.supplierDebt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entity.name, style: Theme.of(context).textTheme.titleLarge),
                if (entity.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(entity.phone, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(debtLabel, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      context.formatCurrency(entity.balance),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (statement.entries.isEmpty)
          SizedBox(
            height: 200,
            child: EmptyStateWidget(
              icon: Icons.receipt_long,
              title: l10n.noStatementEntries,
            ),
          )
        else
          ..._buildEntries(context, statement.entries),
      ],
    );
  }

  List<Widget> _buildEntries(BuildContext context, List<AccountStatementEntry> entries) {
    final l10n = context.l10n;
    var running = 0.0;

    return entries.map((entry) {
      running += entry.debit - entry.credit;
      final balance = entry.balanceAfter ?? running;
      final isPayment = entry.type == 'payment';

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isPayment)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Icon(Icons.payments, size: 18, color: Colors.green.shade700),
                    ),
                  Expanded(
                    child: Text(
                      entry.description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(entry.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (entry.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AmountChip(
                      label: l10n.debit,
                      amount: entry.debit,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AmountChip(
                      label: l10n.credit,
                      amount: entry.credit,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${l10n.statementBalanceAfter}: ${context.formatCurrency(balance)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(
            amount > 0 ? context.formatCurrency(amount) : '—',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
