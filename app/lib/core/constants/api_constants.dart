import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  /// Resolves API base URL by platform unless overridden at build time.
  ///
  /// - Windows/macOS/Linux desktop → localhost
  /// - Android emulator → 10.0.2.2 (host machine)
  /// - Physical device → pass `--dart-define=API_BASE_URL=http://YOUR_PC_IP:3000/api`
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://localhost:3000/api';

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }

  return 'http://localhost:3000/api';
  }

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String clients = '/clients';
  static const String stock = '/stock';
  static const String stockAlerts = '/stock/alerts';
  static const String invoices = '/invoices';
  static const String employees = '/employees';
  static const String dashboard = '/reports/dashboard';
  static const String salesReport = '/reports/sales';
  static const String revenueReport = '/reports/revenue';
  static const String auditLogs = '/reports/audit-logs';
  static const String treasury = '/treasury';
  static const String myAccount = '/me';
}
