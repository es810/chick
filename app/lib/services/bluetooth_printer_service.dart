import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/invoice_model.dart';
import '../models/treasury_entry_item.dart';
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

  String? get lastPrinterMac =>
      _prefs.getString(AppConstants.lastPrinterMacKey);
  String? get lastPrinterName =>
      _prefs.getString(AppConstants.lastPrinterNameKey);

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
    final okConnect =
        connect?.isGranted ?? await Permission.bluetoothConnect.isGranted;
    final okScan = scan?.isGranted ?? true;
    if (!okConnect) return false;

    final pluginGranted =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
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
      throw Exception(
          'تعذر الاتصال بالطابعة. تأكد أنها قريبة ومقترنة بالهاتف.');
    }

    final pdfBytes = await _pdf.generateThermalInvoicePdf(invoice);
    final ticket = await _buildTicketFromPdf(pdfBytes);
    final ok = await PrintBluetoothThermal.writeBytes(ticket);
    if (!ok) {
      throw Exception('فشل إرسال الطباعة للطابعة.');
    }
  }

  Future<void> printCollection(
    TreasuryEntryItem entry, {
    required String mac,
  }) async {
    final connected = await connect(mac);
    if (!connected) {
      throw Exception(
          'تعذر الاتصال بالطابعة. تأكد أنها قريبة ومقترنة بالهاتف.');
    }

    final pdfBytes = await _pdf.generateThermalCollectionPdf(entry);
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

    // ~180 DPI keeps Arabic sharp while staying under common BT write limits.
    await for (final page in Printing.raster(pdfBytes, dpi: 180)) {
      final pngBytes = await page.toPng();
      final decoded = img.decodeImage(pngBytes);
      if (decoded == null) continue;

      final prepared =
          _prepareThermalBitmap(decoded, targetWidth: PaperSize.mm58.width);
      // ESC * bit-image is more reliable on portable Xprinters than GS v 0.
      bytes.addAll(generator.image(prepared, align: PosAlign.center));
      bytes.addAll(generator.feed(2));
    }

    bytes.addAll(generator.feed(4));
    return bytes;
  }

  /// Flattens onto white, crops empty bottom space, resizes for 58mm.
  /// Output must be dark text on white — [Generator.image] inverts internally.
  img.Image _prepareThermalBitmap(img.Image source,
      {required int targetWidth}) {
    final canvas = img.Image(width: source.width, height: source.height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, source);

    final cropped = _cropBottomWhitespace(canvas);
    final resized = img.copyResize(
      cropped,
      width: targetWidth,
      interpolation: img.Interpolation.average,
    );

    // Hard black/white for clean thermal dots (still white background).
    for (final pixel in resized) {
      final lum = img.getLuminanceRgb(pixel.r, pixel.g, pixel.b);
      final v = lum < 140 ? 0 : 255;
      pixel
        ..r = v
        ..g = v
        ..b = v
        ..a = 255;
    }
    return resized;
  }

  img.Image _cropBottomWhitespace(img.Image image) {
    var lastContentRow = 0;
    for (var y = 0; y < image.height; y++) {
      var hasInk = false;
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (img.getLuminanceRgb(p.r, p.g, p.b) < 245) {
          hasInk = true;
          break;
        }
      }
      if (hasInk) lastContentRow = y;
    }

    final padded = (lastContentRow + 16).clamp(1, image.height);
    if (padded >= image.height) return image;
    return img.copyCrop(
      image,
      x: 0,
      y: 0,
      width: image.width,
      height: padded,
    );
  }
}
