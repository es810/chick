import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/damaged_stock_repository.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/treasury_repository.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/storage_service.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(apiClientProvider));
});

final treasuryRepositoryProvider = Provider<TreasuryRepository>((ref) {
  return TreasuryRepository(ref.watch(apiClientProvider));
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(ref.watch(apiClientProvider));
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});

final damagedStockRepositoryProvider = Provider<DamagedStockRepository>((ref) {
  return DamagedStockRepository(ref.watch(apiClientProvider));
});

final clientsProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(clientRepositoryProvider).getClients();
});

final stockProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(stockRepositoryProvider).getStock();
});

final invoicesProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(invoiceRepositoryProvider).getInvoices();
});

final myLedgerProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(employeeRepositoryProvider).getMyLedger();
});

final damagedStockProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(damagedStockRepositoryProvider).list();
});

final dashboardMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final dashboardProvider = FutureProvider((ref) async {
  ref.keepAlive();
  final selected = ref.watch(dashboardMonthProvider);
  return ref.watch(reportRepositoryProvider).getDashboard(
        year: selected.year,
        month: selected.month,
      );
});

final treasurySummaryProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(treasuryRepositoryProvider).getSummary();
});

final salesReportProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(reportRepositoryProvider).getSalesReport();
});

final revenueProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(reportRepositoryProvider).getRevenue();
});

final auditLogsProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(reportRepositoryProvider).getAuditLogs();
});

final themeModeProvider = StateProvider<String>((ref) {
  return ref.watch(storageServiceProvider).getThemeMode();
});
