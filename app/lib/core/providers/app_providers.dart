import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/stock_model.dart';
import '../../models/account_statement_model.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/supplier_repository.dart';
import '../../repositories/supplier_stock_repository.dart';
import '../../repositories/invoice_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/stock_repository.dart';
import '../../repositories/damaged_stock_repository.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/treasury_repository.dart';
import '../../repositories/stock_load_repository.dart';
import '../../services/api_client.dart';
import '../../services/cache_service.dart';
import '../../services/storage_service.dart';

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepository(ref.watch(apiClientProvider), ref.watch(cacheServiceProvider));
});

final supplierStockRepositoryProvider = Provider<SupplierStockRepository>((ref) {
  return SupplierStockRepository(ref.watch(apiClientProvider));
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

final stockLoadRepositoryProvider = Provider<StockLoadRepository>((ref) {
  return StockLoadRepository(ref.watch(apiClientProvider));
});

final clientsProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(clientRepositoryProvider).getClients();
});

final suppliersProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(supplierRepositoryProvider).getSuppliers();
});

final clientStatementProvider = FutureProvider.family<AccountStatement, String>((ref, clientId) async {
  return ref.watch(clientRepositoryProvider).getAccountStatement(clientId);
});

final supplierStatementProvider = FutureProvider.family<AccountStatement, String>((ref, supplierId) async {
  return ref.watch(supplierRepositoryProvider).getAccountStatement(supplierId);
});

final supplierStockProvider = FutureProvider.family<List<StockModel>, String>((ref, supplierId) async {
  ref.keepAlive();
  return ref.watch(supplierStockRepositoryProvider).getStock(supplierId);
});

final stockProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(stockRepositoryProvider).getStock();
});

final invoicesProvider = FutureProvider.autoDispose((ref) async {
  return ref.watch(invoiceRepositoryProvider).getInvoices();
});

final myLedgerProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(employeeRepositoryProvider).getMyLedger();
});

final myTreasuryProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(employeeRepositoryProvider).getMyTreasury();
});

final myTreasuryStatementProvider = FutureProvider((ref) async {
  return ref.watch(employeeRepositoryProvider).getMyTreasuryStatement();
});

final damagedStockProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(damagedStockRepositoryProvider).list();
});

final stockLoadsProvider = FutureProvider((ref) async {
  ref.keepAlive();
  return ref.watch(stockLoadRepositoryProvider).list(
        status: 'open,pending_writeoff',
      );
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

/// Clears offline cache and refreshes all server-backed providers (e.g. after login or wipe).
void invalidateAllAppData(Ref ref) {
  ref.read(cacheServiceProvider).clearCache();
  ref.invalidate(clientsProvider);
  ref.invalidate(suppliersProvider);
  ref.invalidate(stockProvider);
  ref.invalidate(invoicesProvider);
  ref.invalidate(myLedgerProvider);
  ref.invalidate(myTreasuryProvider);
  ref.invalidate(damagedStockProvider);
  ref.invalidate(stockLoadsProvider);
  ref.invalidate(dashboardProvider);
  ref.invalidate(treasurySummaryProvider);
  ref.invalidate(salesReportProvider);
  ref.invalidate(revenueProvider);
  ref.invalidate(auditLogsProvider);
}
