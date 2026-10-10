import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/invoice_model.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/pdf_service.dart';

/// Bottom sheet: pick a paired Bluetooth thermal printer and print the invoice.
Future<void> showBluetoothPrinterPicker({
  required BuildContext context,
  required InvoiceModel invoice,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final service = BluetoothPrinterService(prefs, pdfService);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _BluetoothPrinterSheet(
      invoice: invoice,
      service: service,
    ),
  );
}

class _BluetoothPrinterSheet extends StatefulWidget {
  const _BluetoothPrinterSheet({
    required this.invoice,
    required this.service,
  });

  final InvoiceModel invoice;
  final BluetoothPrinterService service;

  @override
  State<_BluetoothPrinterSheet> createState() => _BluetoothPrinterSheetState();
}

class _BluetoothPrinterSheetState extends State<_BluetoothPrinterSheet> {
  bool _loading = true;
  bool _printing = false;
  String? _error;
  List<BluetoothPrinterDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final permitted = await widget.service.ensurePermissions();
      if (!permitted) {
        setState(() {
          _loading = false;
          _error = context.l10n.bluetoothPermissionDenied;
        });
        return;
      }
      final on = await widget.service.isBluetoothOn();
      if (!on) {
        setState(() {
          _loading = false;
          _error = context.l10n.bluetoothOff;
        });
        return;
      }
      final devices = await widget.service.pairedPrinters();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
        if (devices.isEmpty) {
          _error = context.l10n.noPairedPrinters;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _printTo(BluetoothPrinterDevice device) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await widget.service.printInvoice(widget.invoice, mac: device.mac);
      await widget.service.rememberPrinter(device);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thermalPrinted),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.thermalPrintError}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lastMac = widget.service.lastPrinterMac;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.selectPrinter,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.selectPrinterHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_printing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(l10n.printingThermal),
                  ],
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _devices.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ] else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = _devices[i];
                    final isLast = d.mac == lastMac;
                    return ListTile(
                      leading: Icon(
                        Icons.print,
                        color: isLast ? AppColors.primaryGreen : null,
                      ),
                      title: Text(d.name.isEmpty ? l10n.unknownPrinter : d.name),
                      subtitle: Text(d.mac),
                      trailing: isLast
                          ? Chip(
                              label: Text(l10n.lastUsedPrinter),
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  AppColors.primaryGreen.withValues(alpha: 0.12),
                            )
                          : const Icon(Icons.chevron_left),
                      onTap: () => _printTo(d),
                    );
                  },
                ),
              ),
            if (!_loading && !_printing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refreshPrinters),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
