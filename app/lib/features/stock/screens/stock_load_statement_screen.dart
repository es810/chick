import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/stock_load_statement_model.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/stat_card.dart';

final stockLoadStatementProvider =
    FutureProvider.family<StockLoadStatement, String>((ref, loadId) async {
  return ref.watch(stockLoadRepositoryProvider).getStatement(loadId);
});

class StockLoadStatementScreen extends ConsumerWidget {
  const StockLoadStatementScreen({
    super.key,
    required this.loadId,
    required this.basePath,
    this.title = '',
  });

  final String loadId;
  final String basePath;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(stockLoadStatementProvider(loadId));

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : l10n.loadStatement),
      ),
      body: async.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorStateWidget(
          message: apiErrorMessage(
            e,
            fallback: e is DioException ? l10n.serverError : e.toString(),
          ),
          onRetry: () => ref.invalidate(stockLoadStatementProvider(loadId)),
        ),
        data: (statement) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(stockLoadStatementProvider(loadId));
            await ref.read(stockLoadStatementProvider(loadId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LoadHeader(statement: statement),
              const SizedBox(height: 16),
              _TotalsRow(statement: statement),
              const SizedBox(height: 20),
              Text(
                l10n.loadDistributions,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              if (statement.entries.isEmpty)
                EmptyStateWidget(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.noLoadDistributionsYet,
                )
              else
                ...statement.entries.map(
                  (entry) => _EntryCard(
                    entry: entry,
                    basePath: basePath,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadHeader extends StatelessWidget {
  const _LoadHeader({required this.statement});

  final StockLoadStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final load = statement.load;
    final statusLabel = load.isPendingWriteOff
        ? l10n.loadPendingWriteOff
        : load.isClosed
            ? l10n.loadClosed
            : l10n.pendingWriteOffLoads;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    load.chickenType,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                StatusChip(
                  label: statusLabel,
                  color: load.isPendingWriteOff
                      ? AppColors.warning
                      : load.isOpen
                          ? AppColors.primaryGreen
                          : Colors.grey,
                ),
              ],
            ),
            if (load.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(DateFormat.yMMMd().add_jm().format(load.createdAt!)),
            ],
            const SizedBox(height: 10),
            Text(
              '${l10n.loadedLabel}: ${load.loadedQuantity}'
              '${load.loadedNetWeight > 0 ? ' — ${load.loadedNetWeight.toStringAsFixed(1)} kg' : ''}',
            ),
            Text(
              '${l10n.loadRemainingLabel}: ${load.remainingQuantity}'
              '${load.remainingNetWeight > 0 ? ' — ${load.remainingNetWeight.toStringAsFixed(1)} kg' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.statement});

  final StockLoadStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = statement.totals;
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            title: l10n.loadDistributedQty,
            value: '${t.distributedQuantity}',
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            title: l10n.loadDistributedWeight,
            value: '${t.distributedNetWeight.toStringAsFixed(1)} kg',
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(
            title: l10n.loadUnpaidAmount,
            value: context.formatCurrency(t.unpaidAmount),
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.basePath});

  final StockLoadStatementEntry entry;
  final String basePath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canOpen = entry.isDistribution && entry.id.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: canOpen
            ? () => context.push('$basePath/invoices/${entry.id}')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.description,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (entry.isDistribution)
                    StatusChip(
                      label: _paymentLabel(l10n, entry.paymentStatus),
                      color: entry.paymentStatus == 'paid'
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(DateFormat.yMMMd().add_jm().format(entry.date)),
              if (entry.clientName.isNotEmpty) Text(entry.clientName),
              if (entry.subtitle.isNotEmpty && entry.clientName.isEmpty)
                Text(entry.subtitle),
              const SizedBox(height: 6),
              Text(
                '${l10n.quantity}: ${entry.quantity}'
                '${entry.netWeight > 0 ? ' — ${entry.netWeight.toStringAsFixed(1)} kg' : ''}',
              ),
              if (entry.amount > 0)
                Text(
                  context.formatCurrency(entry.amount),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'paid' => l10n.paid,
      'partial' => l10n.partial,
      _ => l10n.pending,
    };
  }
}
