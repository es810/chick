import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/invoice_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/client_model.dart';
import '../../../models/stock_model.dart';

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

  double get _gross => double.tryParse(_grossController.text) ?? 0;
  int get _count => int.tryParse(_countController.text) ?? 0;
  double get _tare => invoiceTareWeight(_count);
  double get _net => (_gross - _tare).clamp(0, double.infinity);
  double get _price => double.tryParse(_priceController.text) ?? 0;
  double get _mealTotal => _net * _price;

  double get _balanceBefore => _selectedClient?.balance ?? 0;
  double get _balanceAfter => _balanceBefore + _mealTotal;

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<ClientModel>(
          initialValue: _selectedClient,
          decoration: InputDecoration(labelText: l10n.selectClient),
          items: clients
              .map((c) => DropdownMenuItem(value: c, child: Text('${c.name} (${c.phone})')))
              .toList(),
          onChanged: (v) => setState(() => _selectedClient = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _chickenType,
          decoration: InputDecoration(labelText: l10n.chickenType),
          items: stock
              .map(
                (s) => DropdownMenuItem(
                  value: s.chickenType,
                  child: Text('${s.chickenType}'),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _chickenType = v;
              final s = stock.firstWhere((s) => s.chickenType == v);
              _priceController.text = s.pricePerKg.toStringAsFixed(2);
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _countController,
          decoration: InputDecoration(labelText: l10n.itemCount),
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _grossController,
          decoration: InputDecoration(labelText: l10n.grossWeight),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.tareWeight,
            helperText: l10n.tareWeightFormula,
          ),
          child: Text(
            _tare.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _priceController,
          decoration: InputDecoration(labelText: l10n.pricePerKg),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                _previewRow(l10n.tareWeight, _tare.toStringAsFixed(2)),
                _previewRow(l10n.netWeight, _net.toStringAsFixed(2)),
                _previewRow(l10n.mealTotal, _mealTotal.toStringAsFixed(2)),
                if (_selectedClient != null) ...[
                  _previewRow(l10n.balanceBefore, _balanceBefore.toStringAsFixed(2)),
                  _previewRow(l10n.balanceAfter, _balanceAfter.toStringAsFixed(2)),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invoiceCreated(invoice.invoiceNumber))),
        );
        context.go('${widget.basePath}/invoices');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
