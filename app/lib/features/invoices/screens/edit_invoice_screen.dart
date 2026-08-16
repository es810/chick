import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/invoice_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/client_model.dart';
import '../../../models/invoice_model.dart';
import '../../../models/stock_model.dart';
import '../../../shared/widgets/client_picker_field.dart';
import '../../../shared/widgets/loading_widget.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  const EditInvoiceScreen({
    super.key,
    required this.invoiceId,
    this.basePath = '/admin',
  });

  final String invoiceId;
  final String basePath;

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  InvoiceModel? _invoice;
  ClientModel? _selectedClient;
  final _notesController = TextEditingController();
  final _countController = TextEditingController();
  final _grossController = TextEditingController();
  bool _isSubmitting = false;
  bool _initialized = false;
  final List<_InvoiceLineItem> _items = [];

  @override
  void dispose() {
    _notesController.dispose();
    _countController.dispose();
    _grossController.dispose();
    super.dispose();
  }

  void _initFromInvoice(InvoiceModel invoice, List<ClientModel> clients) {
    if (_initialized) return;
    _initialized = true;
    _invoice = invoice;
    _notesController.text = invoice.notes;
    _countController.text = '${invoice.itemCount}';
    _grossController.text = invoice.displayGrossWeight.toStringAsFixed(2);
    _selectedClient = clients.where((c) => c.id == invoice.clientId).firstOrNull;
    _items.clear();
    for (final item in invoice.items) {
      _items.add(_InvoiceLineItem(
        chickenType: item.chickenType,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        avgWeight: item.quantity > 0 ? item.weight / item.quantity : 2.5,
      ));
    }
    if (_items.isEmpty) _items.add(_InvoiceLineItem());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clientsAsync = ref.watch(clientsProvider);
    final stockAsync = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editInvoice)),
      body: FutureBuilder<InvoiceModel>(
        future: ref.read(invoiceRepositoryProvider).getInvoice(widget.invoiceId),
        builder: (context, invoiceSnapshot) {
          if (invoiceSnapshot.connectionState == ConnectionState.waiting) {
            return const LoadingOverlay();
          }
          if (invoiceSnapshot.hasError) {
            return Center(child: Text('${l10n.pdfError}: ${invoiceSnapshot.error}'));
          }

          return clientsAsync.when(
            loading: () => const LoadingOverlay(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (clients) => stockAsync.when(
              loading: () => const LoadingOverlay(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (stock) {
                _initFromInvoice(invoiceSnapshot.data!, clients);
                return _buildForm(context, l10n, clients, stock);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    List<ClientModel> clients,
    List<StockModel> stock,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_invoice != null)
          Text(
            _invoice!.invoiceNumber,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
          ),
        const SizedBox(height: 12),
        ClientPickerField(
          clients: clients,
          selected: _selectedClient,
          onSelected: (v) => setState(() => _selectedClient = v),
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
        Builder(
          builder: (context) {
            final count = int.tryParse(_countController.text) ?? 0;
            final tare = invoiceTareWeight(count);
            return InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.tareWeight,
                helperText: l10n.tareWeightFormula,
              ),
              child: Text(
                tare.toStringAsFixed(2),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(labelText: l10n.notes),
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.items, style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_InvoiceLineItem())),
              icon: const Icon(Icons.add),
              label: Text(l10n.addItem),
            ),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: item.chickenType,
                    decoration: InputDecoration(labelText: l10n.chickenType),
                    items: stock
                        .map((s) => DropdownMenuItem(
                              value: s.chickenType,
                              child: Text(s.chickenType),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        item.chickenType = v;
                        final s = stock.firstWhere((s) => s.chickenType == v);
                        item.unitPrice = s.pricePerKg;
                        item.avgWeight = s.averageWeight;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: item.quantity.toString(),
                          decoration: InputDecoration(labelText: l10n.quantity),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => item.quantity = int.tryParse(v) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${l10n.estWeight}: ${(item.quantity * item.avgWeight).toStringAsFixed(2)} kg',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (_items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppColors.error),
                          onPressed: () => setState(() => _items.removeAt(index)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => _submit(stock),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.saveChanges),
        ),
      ],
    );
  }

  Future<void> _submit(List<StockModel> stock) async {
    final l10n = context.l10n;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectClientRequired)),
      );
      return;
    }

    for (final item in _items) {
      if (item.chickenType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.selectChickenType)),
        );
        return;
      }
    }

    final gross = double.tryParse(_grossController.text) ?? 0;
    final itemCount = int.tryParse(_countController.text) ?? 0;
    if (itemCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fieldRequired)));
      return;
    }
    final tare = invoiceTareWeight(itemCount);
    final net = gross - tare;
    if (net <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidWeights)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'clientId': _selectedClient!.id,
        'notes': _notesController.text.trim(),
        'itemCount': itemCount,
        'grossWeight': gross,
        'tareWeight': tare,
        'items': _items
            .map((item) => {
                  'chickenType': item.chickenType,
                  'quantity': item.quantity,
                  'weight': net,
                  'unitPrice': item.unitPrice,
                })
            .toList(),
      };

      await ref.read(invoiceRepositoryProvider).updateInvoice(widget.invoiceId, payload);

      if (mounted) {
        ref.invalidate(invoicesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.invoiceUpdated)),
        );
        context.go('${widget.basePath}/invoices/${widget.invoiceId}');
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

class _InvoiceLineItem {
  _InvoiceLineItem({
    this.chickenType,
    this.quantity = 1,
    this.unitPrice = 0,
    this.avgWeight = 2.5,
  });

  String? chickenType;
  int quantity;
  double unitPrice;
  double avgWeight;
}
