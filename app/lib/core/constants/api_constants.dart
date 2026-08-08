import '../config/api_config.dart';

class ApiConstants {
  /// Build-time define, saved server URL on login screen, or platform default.
  static String get baseUrl => ApiConfig.baseUrl;

  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String clients = '/clients';
  static const String suppliers = '/suppliers';
  static const String stock = '/stock';
  static const String stockAlerts = '/stock/alerts';
  static const String invoices = '/invoices';
  static const String employees = '/employees';
  static const String dashboard = '/reports/dashboard';
  static const String salesReport = '/reports/sales';
  static const String revenueReport = '/reports/revenue';
  static const String auditLogs = '/reports/audit-logs';
  static const String treasury = '/treasury';
  static const String collections = '/collections';
  static const String damagedStock = '/damaged-stock';
  static const String stockLoads = '/stock-loads';
  static const String myAccount = '/me';
}
