import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/invoice_model.dart';
import 'pdf_service.dart';

class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({required this.name, required this.mac});

  final String name;
  final String mac;
}

class BluetoothPrinterService {
  BluetoothPrinterService(this._prefs, this._pdf);

  final SharedPreferences _prefs;
  final PdfService _pdf;

  String? get lastPrinterMac => _prefs.getString(AppConstants.lastPrinterMacKey);
  String? get lastPrinterName => _prefs.getString(AppConstants.lastPrinterNameKey);

  Future<void> rememberPrinter(BluetoothPrinterDevice device) async {
    await _prefs.setString(AppConstants.lastPrinterMacKey, device.mac);
    await _prefs.setString(AppConstants.lastPrinterNameKey, device.name);
  }

  Future<bool> ensurePermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final connect = statuses[Permission.bluetoothConnect];
    final scan = statuses[Permission.bluetoothScan];
    // Location only needed on older Android; ignore if permanently denied on new OS.
    final okConnect = connect?.isGranted ?? await Permission.bluetoothConnect.isGranted;
    final okScan = scan?.isGranted ?? true;
    if (!okConnect) return false;

    final pluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    return pluginGranted || (okConnect && okScan);
  }

  Future<bool> isBluetoothOn() => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<BluetoothPrinterDevice>> pairedPrinters() async {
    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((d) => BluetoothPrinterDevice(name: d.name, mac: d.macAdress))
        .where((d) => d.mac.trim().isNotEmpty)
        .toList();
  }

  Future<bool> connect(String mac) async {
    final already = await PrintBluetoothThermal.connectionStatus;
    if (already) {
      // Reconnect if different / ensure fresh session.
      await PrintBluetoothThermal.disconnect;
    }
    return PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  /// Builds Arabic receipt as image (58mm) and sends ESC/POS bytes to the printer.
  Future<void> printInvoice(InvoiceModel invoice, {required String mac}) async {
    final connected = await connect(mac);
    if (!connected) {
      throw Exception('تعذر الاتصال بالطابعة. تأكد أنها قريبة ومقترنة بالهاتف.');
    }

    final pdfBytes = await _pdf.generateThermalInvoicePdf(invoice);
    final ticket = await _buildTicketFromPdf(pdfBytes);
    final ok = await PrintBluetoothThermal.writeBytes(ticket);
    if (!ok) {
      throw Exception('فشل إرسال الطباعة للطابعة.');
    }
  }

  Future<List<int>> _buildTicketFromPdf(Uint8List pdfBytes) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];
    bytes.addAll(generator.reset());

    // 203 DPI is typical for 58mm thermal heads; resize to ESC/POS width (384 dots).
    await for (final page in Printing.raster(pdfBytes, dpi: 203)) {
      final pngBytes = await page.toPng();
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) continue;
      final resized = img.copyResize(
        decoded,
        width: PaperSize.mm58.width,
        interpolation: img.Interpolation.linear,
      );
      bytes.addAll(generator.imageRaster(resized, align: PosAlign.center));
      bytes.addAll(generator.feed(2));
    }

    // Portable Xprinters usually have no auto-cutter — feed enough to tear.
    bytes.addAll(generator.feed(4));
    return bytes;
  }
}
