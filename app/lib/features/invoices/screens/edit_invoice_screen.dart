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
  String? _chickenType;
  final _notesController = TextEditingController();
  final _countController = TextEditingController();
  final _grossController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSubmitting = false;
  bool _initialized = false;

  @override
  void dispose() {
    _notesController.dispose();
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

  void _initFromInvoice(InvoiceModel invoice, List<ClientModel> clients) {
    if (_initialized) return;
    _initialized = true;
    _invoice = invoice;
    _notesController.text = invoice.notes;
    _countController.text = '${invoice.itemCount}';
    _grossController.text = invoice.displayGrossWeight.toStringAsFixed(2);
    _priceController.text = invoice.pricePerKg.toStringAsFixed(2);
    _selectedClient = clients.where((c) => c.id == invoice.clientId).firstOrNull;
    _chickenType = invoice.items.isNotEmpty ? invoice.items.first.chickenType : null;
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
            return Center(child: Text(apiErrorMessage(invoiceSnapshot.error!)));
          }

          return clientsAsync.when(
            loading: () => const LoadingOverlay(),
            error: (e, _) => Center(child: Text(apiErrorMessage(e))),
            data: (clients) => stockAsync.when(
              loading: () => const LoadingOverlay(),
              error: (e, _) => Center(child: Text(apiErrorMessage(e))),
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
        DropdownButtonFormField<String>(
          initialValue: _chickenType != null &&
                  stock.any((s) => s.chickenType == _chickenType)
              ? _chickenType
              : null,
          decoration: InputDecoration(labelText: l10n.chickenType),
          items: stock
              .map(
                (s) => DropdownMenuItem(
                  value: s.chickenType,
                  child: Text(s.chickenType),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _chickenType = v;
              if (v != null) {
                final s = stock.firstWhere((s) => s.chickenType == v);
                // Keep existing price unless field is empty.
                if (_priceController.text.trim().isEmpty) {
                  _priceController.text = s.pricePerKg.toStringAsFixed(2);
                }
              }
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(labelText: l10n.notes),
          maxLines: 2,
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
                _previewRow(l10n.netWeight, _net.toStringAsFixed(2)),
                _previewRow(l10n.pricePerKg, _price.toStringAsFixed(2)),
                _previewRow(l10n.mealTotal, _mealTotal.toStringAsFixed(2)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
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

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectClientRequired)),
      );
      return;
    }
    if (_chickenType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectChickenType)),
      );
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
    if (_price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidAmount)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'clientId': _selectedClient!.id,
        'notes': _notesController.text.trim(),
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
