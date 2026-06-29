import '../core/constants/api_constants.dart';
import '../models/employee_ledger_model.dart';
import '../models/employee_treasury_model.dart';
import '../models/account_statement_model.dart';
import '../services/api_client.dart';

class EmployeeRepository {
  EmployeeRepository(this._api);

  final ApiClient _api;

  Future<EmployeeLedgerSummary> getLedger(String employeeId) async {
    final response = await _api.get('${ApiConstants.employees}/$employeeId/ledger');
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerSummary.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<EmployeeLedgerEntry> addExpense(String employeeId, double amount, String description) async {
    final response = await _api.post(
      '${ApiConstants.employees}/$employeeId/ledger/expense',
      data: {'amount': amount, 'description': description},
    );
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<EmployeeLedgerEntry> addDebt(
    String employeeId,
    double amount,
    String description,
    String supplierId,
  ) async {
    final response = await _api.post(
      '${ApiConstants.employees}/$employeeId/ledger/debt',
      data: {
        'amount': amount,
        'description': description,
        'supplierId': supplierId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<SalaryAdvanceEntry> addSalaryAdvance({
    required String employeeId,
    required DateTime advanceDate,
    required double amount,
    String notes = '',
  }) async {
    final response = await _api.post(
      '${ApiConstants.employees}/$employeeId/advances',
      data: {
        'advanceDate': advanceDate.toIso8601String(),
        'amount': amount,
        if (notes.isNotEmpty) 'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return SalaryAdvanceEntry.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<({double totalExpenses, double totalDebt, List<EmployeeLedgerEntry> entries})> getMyLedger() async {
    final response = await _api.get('${ApiConstants.myAccount}/ledger');
    final data = response.data as Map<String, dynamic>;
    final body = data['data'] as Map<String, dynamic>;
    final entries = (body['entries'] as List? ?? [])
        .map((e) => EmployeeLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      totalExpenses: (body['totalExpenses'] as num?)?.toDouble() ?? 0,
      totalDebt: (body['totalDebt'] as num?)?.toDouble() ?? 0,
      entries: entries,
    );
  }

  Future<EmployeeLedgerEntry> addMyExpense(double amount, String description) async {
    final response = await _api.post(
      '${ApiConstants.myAccount}/ledger/expense',
      data: {'amount': amount, 'description': description},
    );
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<EmployeeLedgerEntry> addMyDebt(
    double amount,
    String description,
    String supplierId,
  ) async {
    final response = await _api.post(
      '${ApiConstants.myAccount}/ledger/debt',
      data: {
        'amount': amount,
        'description': description,
        'supplierId': supplierId,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> transferTreasury({
    required String fromEmployeeId,
    required String toEmployeeId,
    required double amount,
    String? notes,
  }) async {
    await _api.post(
      '${ApiConstants.employees}/treasury-transfers',
      data: {
        'fromEmployeeId': fromEmployeeId,
        'toEmployeeId': toEmployeeId,
        'amount': amount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<EmployeeTreasurySummary> getMyTreasury() async {
    final response = await _api.get('${ApiConstants.myAccount}/treasury');
    final data = response.data as Map<String, dynamic>;
    return EmployeeTreasurySummary.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<AccountStatement> getMyTreasuryStatement() async {
    final response = await _api.get('${ApiConstants.myAccount}/treasury/statement');
    final data = response.data as Map<String, dynamic>;
    return AccountStatement.fromJson(data['data'] as Map<String, dynamic>);
  }
}
