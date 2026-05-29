import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';

/// Stock IN / edit fields: location, type, count, tare, net, price, total (read-only).
class StockEntryForm extends StatefulWidget {
  const StockEntryForm({
    super.key,
    this.initialLocation = '',
    this.initialType = '',
    this.initialCount = '',
    this.initialTare = '',
    this.initialNet = '',
    this.initialPrice = '',
    this.typeReadOnly = false,
  });

  final String initialLocation;
  final String initialType;
  final String initialCount;
  final String initialTare;
  final String initialNet;
  final String initialPrice;
  final bool typeReadOnly;

  @override
  State<StockEntryForm> createState() => StockEntryFormState();
}

class StockEntryFormState extends State<StockEntryForm> {
  late final TextEditingController _locationController;
  late final TextEditingController _typeController;
  late final TextEditingController _countController;
  late final TextEditingController _tareController;
  late final TextEditingController _netController;
  late final TextEditingController _priceController;
  late final TextEditingController _totalController;

  double _total = 0;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.initialLocation);
    _typeController = TextEditingController(text: widget.initialType);
    _countController = TextEditingController(text: widget.initialCount);
    _tareController = TextEditingController(text: widget.initialTare);
    _netController = TextEditingController(text: widget.initialNet);
    _priceController = TextEditingController(text: widget.initialPrice);
    _totalController = TextEditingController();
    _recalcTotal();
    for (final c in [_netController, _priceController]) {
      c.addListener(_recalcTotal);
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _typeController.dispose();
    _countController.dispose();
    _tareController.dispose();
    _netController.dispose();
    _priceController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    final price = double.tryParse(_priceController.text.trim().replaceAll(',', '')) ?? 0;
    final net = double.tryParse(_netController.text.trim().replaceAll(',', '')) ?? 0;
    final next = price * net;
    if (next != _total) {
      _total = next;
      _totalController.text = next.toStringAsFixed(2);
      setState(() {});
    }
  }

  Map<String, dynamic> toPayload() {
    final count = int.parse(_countController.text.trim());
    final tare = double.parse(_tareController.text.trim().replaceAll(',', ''));
    final net = double.parse(_netController.text.trim().replaceAll(',', ''));
    final price = double.parse(_priceController.text.trim().replaceAll(',', ''));
    return {
      'location': _locationController.text.trim(),
      'chickenType': _typeController.text.trim(),
      'quantity': count,
      'tareWeight': tare,
      'netWeight': net,
      'pricePerKg': price,
      'totalAmount': _total,
      'averageWeight': count > 0 ? net / count : 0,
    };
  }

  bool validate(BuildContext context) {
    final l10n = context.l10n;
    if (_typeController.text.trim().isEmpty) return false;
    if (int.tryParse(_countController.text.trim()) == null) return false;
    if (double.tryParse(_tareController.text.trim().replaceAll(',', '')) == null) return false;
    if (double.tryParse(_netController.text.trim().replaceAll(',', '')) == null) return false;
    if (double.tryParse(_priceController.text.trim().replaceAll(',', '')) == null) return false;
    final net = double.parse(_netController.text.trim().replaceAll(',', ''));
    if (net <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.invalidWeights)),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: l10n.stockLocation,
            prefixIcon: const Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _typeController,
          readOnly: widget.typeReadOnly,
          decoration: InputDecoration(
            labelText: l10n.stockTypeLabel,
            prefixIcon: const Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _countController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.itemCount,
            prefixIcon: const Icon(Icons.numbers),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tareController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.tareWeight,
            prefixIcon: const Icon(Icons.scale_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _netController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.netWeight,
            prefixIcon: const Icon(Icons.fitness_center_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.stockPrice,
            prefixIcon: const Icon(Icons.attach_money),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          readOnly: true,
          controller: _totalController,
          decoration: InputDecoration(
            labelText: l10n.stockTotal,
            prefixIcon: const Icon(Icons.calculate_outlined),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
