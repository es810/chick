import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/invoice_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../core/utils/number_input_utils.dart';
import '../../../models/client_model.dart';
import '../../../models/stock_model.dart';
import '../../../shared/widgets/client_picker_field.dart';
import '../../../shared/widgets/invoice_number_field.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  const CreateInvoiceScreen({super.key, this.basePath = '/employee'});

  final String basePath;

  @override
  ConsumerState<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  ClientModel? _selectedClient;
  String? _chickenType;
  bool _isSubmitting = false;

  final _countController = TextEditingController();
  final _grossController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _countController.dispose();
    _grossController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _gross => parseInputNumber(_grossController.text);
  int get _count => parseInputInt(_countController.text);
  double get _tare => invoiceTareWeight(_count);
  double get _net => (_gross - _tare).clamp(0, double.infinity);
  double get _price => parseInputNumber(_priceController.text);
  double get _mealTotal => _net * _price;

  double get _balanceBefore => _selectedClient?.balance ?? 0;
  double get _balanceAfter => _balanceBefore + _mealTotal;

  StockModel? _selectedStock(List<StockModel> stock) {
    if (_chickenType == null) return null;
    for (final item in stock) {
      if (item.chickenType == _chickenType) return item;
    }
    return null;
  }

  Widget _stockAvailabilityCard(AppLocalizations l10n, StockModel selected) {
    final low = selected.isLowStock;
    final color = low ? AppColors.warning : AppColors.primaryGreen;

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onHandStock,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${selected.usableQuantity}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  if (selected.usableNetWeight > 0)
                    Text(
                      '${l10n.netWeight}: ${formatInputNumber(selected.usableNetWeight)} kg',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (selected.hasPendingSurplus)
                    Text(
                      '${l10n.pendingSurplusLabel}: '
                      '${selected.pendingSurplusQuantity > 0 ? '${selected.pendingSurplusQuantity} ' : ''}'
                      '${selected.pendingSurplusNetWeight > 0 ? '${selected.pendingSurplusNetWeight.toStringAsFixed(1)} kg' : ''}'
                          .trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                          ),
                    ),
                ],
              ),
            ),
            if (low)
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clientsAsync = ref.watch(clientsProvider);
    final stockAsync = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.distributionReceipt)),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (clients) => stockAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stock) {
            if (stock.isEmpty) {
              return Center(child: Text(l10n.noStockAddFirst));
            }
            return _buildForm(l10n, clients, stock);
          },
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n, List<ClientModel> clients, List<StockModel> stock) {
    final selectedStock = _selectedStock(stock);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClientPickerField(
          clients: clients,
          selected: _selectedClient,
          onSelected: (v) => setState(() => _selectedClient = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _chickenType,
          decoration: InputDecoration(labelText: l10n.chickenType),
          items: stock
              .map(
                (s) => DropdownMenuItem(
                  value: s.chickenType,
                  child: Text('${s.chickenType} — ${l10n.onHandStock}: ${s.usableQuantity}'),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _chickenType = v;
              final s = stock.firstWhere((s) => s.chickenType == v);
              if (_priceController.text.trim().isEmpty) {
                _priceController.text = formatInputNumber(s.pricePerKg);
              }
            });
          },
        ),
        if (selectedStock != null) ...[
          const SizedBox(height: 12),
          _stockAvailabilityCard(l10n, selectedStock),
        ],
        const SizedBox(height: 16),
        InvoiceNumberField(
          controller: _countController,
          labelText: l10n.itemCount,
          helperText: selectedStock != null
              ? '${l10n.onHandStock}: ${selectedStock.usableQuantity}'
              : null,
          decimal: false,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        InvoiceNumberField(
          controller: _grossController,
          labelText: l10n.grossWeight,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.tareWeight,
            helperText: l10n.tareWeightFormula,
          ),
          child: Text(
            formatInputNumber(_tare),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        InvoiceNumberField(
          controller: _priceController,
          labelText: l10n.pricePerKg,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.receiptPreview, style: Theme.of(context).textTheme.titleMedium),
                const Divider(),
                if (_chickenType != null) _previewRow('نوع الصنف', _chickenType!),
                _previewRow(l10n.tareWeight, formatInputNumber(_tare)),
                _previewRow(l10n.netWeight, formatInputNumber(_net)),
                _previewRow(l10n.mealTotal, formatInputNumber(_mealTotal)),
                if (_selectedClient != null) ...[
                  _previewRow(l10n.balanceBefore, formatInputNumber(_balanceBefore)),
                  _previewRow(l10n.balanceAfter, formatInputNumber(_balanceAfter)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submit(stock, l10n),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.createInvoice),
        ),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _submit(List<StockModel> stock, AppLocalizations l10n) async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectClientRequired)));
      return;
    }
    if (_chickenType == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.selectStockType)));
      return;
    }
    if (_count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fieldRequired)));
      return;
    }
    if (_net <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidWeights)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'clientId': _selectedClient!.id,
        'itemCount': _count,
        'grossWeight': _gross,
        'tareWeight': _tare,
        'items': [
          {
            'chickenType': _chickenType,
            'quantity': _count,
            'weight': _net,
            'unitPrice': _price,
          },
        ],
      };

      final invoice = await ref.read(invoiceRepositoryProvider).createInvoice(payload);

      ref.invalidate(invoicesProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(stockProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invoiceCreated(invoice.invoiceNumber))),
        );
        context.go('${widget.basePath}/invoices');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(apiErrorMessage(e, fallback: l10n.serverError)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
