import '../core/constants/api_constants.dart';
import '../models/employee_ledger_model.dart';
import '../models/employee_treasury_model.dart';
import '../models/account_statement_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class EmployeeRepository {
  EmployeeRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  static const _myTreasuryKey = 'my_treasury';
  static const _myLedgerKey = 'my_ledger';
  static const _myTreasuryStatementKey = 'my_treasury_statement';

  Future<EmployeeLedgerSummary> getLedger(String employeeId) async {
    final response = await _api.get('${ApiConstants.employees}/$employeeId/ledger');
    final data = response.data as Map<String, dynamic>;
    return EmployeeLedgerSummary.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<EmployeeLedgerEntry> addExpense(
    String employeeId,
    double amount,
    String description, {
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'amount': amount,
      'description': description,
      'clientMutationId': mutationId,
    };
    try {
      final response = await _api.post(
        '${ApiConstants.employees}/$employeeId/ledger/expense',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'add_expense',
          {...body, 'employeeId': employeeId},
          clientMutationId: mutationId,
        );
        await _patchCachedTreasury(expenseDelta: amount);
        throw OfflineQueuedException('add_expense', clientMutationId: mutationId);
      }
      rethrow;
    }
  }

  Future<EmployeeLedgerEntry> addDebt(
    String employeeId,
    double amount,
    String description,
    String supplierId, {
    double amountDeducted = 0,
  }) async {
    final response = await _api.post(
      '${ApiConstants.employees}/$employeeId/ledger/debt',
      data: {
        'amount': amount,
        'description': description,
        'supplierId': supplierId,
        'amountDeducted': amountDeducted,
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

  Future<void> deleteSalaryAdvance({
    required String employeeId,
    required String advanceId,
  }) async {
    await _api.delete(
      '${ApiConstants.employees}/$employeeId/advances/$advanceId',
    );
  }

  Future<({double totalExpenses, double totalDebt, List<EmployeeLedgerEntry> entries})>
      getMyLedger() async {
    try {
      final response = await _api.get('${ApiConstants.myAccount}/ledger');
      final data = response.data as Map<String, dynamic>;
      final body = data['data'] as Map<String, dynamic>;
      final entries = (body['entries'] as List? ?? [])
          .map((e) => EmployeeLedgerEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final result = (
        totalExpenses: (body['totalExpenses'] as num?)?.toDouble() ?? 0,
        totalDebt: (body['totalDebt'] as num?)?.toDouble() ?? 0,
        entries: entries,
      );
      await _cache.cacheData(_myLedgerKey, {
        'totalExpenses': result.totalExpenses,
        'totalDebt': result.totalDebt,
        'entries': (body['entries'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      });
      return _mergePendingExpenses(result);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached(_myLedgerKey);
        if (cached != null) {
          final entries = (cached['entries'] as List? ?? [])
              .map(
                (e) => EmployeeLedgerEntry.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          return _mergePendingExpenses((
            totalExpenses: (cached['totalExpenses'] as num?)?.toDouble() ?? 0,
            totalDebt: (cached['totalDebt'] as num?)?.toDouble() ?? 0,
            entries: entries,
          ));
        }
      }
      rethrow;
    }
  }

  ({double totalExpenses, double totalDebt, List<EmployeeLedgerEntry> entries})
      _mergePendingExpenses(
    ({double totalExpenses, double totalDebt, List<EmployeeLedgerEntry> entries})
        base,
  ) {
    final pending = _cache.getPendingSyncs(action: 'add_expense');
    if (pending.isEmpty) return base;

    final extra = <EmployeeLedgerEntry>[];
    var expenseSum = base.totalExpenses;
    for (final item in pending.reversed) {
      final id = item['id']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      // Only merge self-queued expenses (no employeeId = my account).
      final employeeId = payload['employeeId']?.toString();
      if (employeeId != null && employeeId.isNotEmpty) continue;
      final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
      expenseSum += amount;
      extra.add(
        EmployeeLedgerEntry(
          id: 'pending-$id',
          type: 'expense',
          amount: amount,
          description: payload['description']?.toString() ?? 'معلّق — مزامنة',
          createdAt: DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }
    return (
      totalExpenses: expenseSum,
      totalDebt: base.totalDebt,
      entries: [...extra, ...base.entries],
    );
  }

  Future<EmployeeLedgerEntry> addMyExpense(
    double amount,
    String description, {
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'amount': amount,
      'description': description,
      'clientMutationId': mutationId,
    };
    try {
      final response = await _api.post(
        '${ApiConstants.myAccount}/ledger/expense',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      return EmployeeLedgerEntry.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'add_expense',
          body,
          clientMutationId: mutationId,
        );
        await _patchCachedTreasury(expenseDelta: amount);
        throw OfflineQueuedException('add_expense', clientMutationId: mutationId);
      }
      rethrow;
    }
  }

  Future<EmployeeLedgerEntry> addMyDebt(
    double amount,
    String description,
    String supplierId, {
    double amountDeducted = 0,
  }) async {
    final response = await _api.post(
      '${ApiConstants.myAccount}/ledger/debt',
      data: {
        'amount': amount,
        'description': description,
        'supplierId': supplierId,
        'amountDeducted': amountDeducted,
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
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'fromEmployeeId': fromEmployeeId,
      'toEmployeeId': toEmployeeId,
      'amount': amount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'clientMutationId': mutationId,
    };
    try {
      await _api.post('${ApiConstants.employees}/treasury-transfers', data: body);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'transfer_treasury',
          body,
          clientMutationId: mutationId,
        );
        throw OfflineQueuedException(
          'transfer_treasury',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<void> transferMyTreasury({
    required String toEmployeeId,
    required double amount,
    String? notes,
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'toEmployeeId': toEmployeeId,
      'amount': amount,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'clientMutationId': mutationId,
    };
    try {
      await _api.post('${ApiConstants.myAccount}/treasury-transfers', data: body);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'transfer_my_treasury',
          body,
          clientMutationId: mutationId,
        );
        await _patchCachedTreasury(outgoingTransferDelta: amount);
        throw OfflineQueuedException(
          'transfer_my_treasury',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<EmployeeTreasurySummary> getMyTreasury() async {
    try {
      final response = await _api.get('${ApiConstants.myAccount}/treasury');
      final data = response.data as Map<String, dynamic>;
      final raw = data['data'] as Map<String, dynamic>;
      await _cache.cacheData(
        _myTreasuryKey,
        Map<String, dynamic>.from(raw),
      );
      return EmployeeTreasurySummary.fromJson(raw);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached(_myTreasuryKey);
        if (cached != null) {
          return EmployeeTreasurySummary.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  Future<AccountStatement> getMyTreasuryStatement() async {
    try {
      final response =
          await _api.get('${ApiConstants.myAccount}/treasury/statement');
      final data = response.data as Map<String, dynamic>;
      final raw = data['data'] as Map<String, dynamic>;
      await _cache.cacheData(
        _myTreasuryStatementKey,
        Map<String, dynamic>.from(raw),
      );
      return AccountStatement.fromJson(raw);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached(_myTreasuryStatementKey);
        if (cached != null) {
          return AccountStatement.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  Future<AccountStatement> getTreasuryStatement(String employeeId) async {
    final cacheKey = 'employee_treasury_statement_$employeeId';
    try {
      final response = await _api.get(
        '${ApiConstants.employees}/$employeeId/treasury/statement',
      );
      final data = response.data as Map<String, dynamic>;
      final raw = data['data'] as Map<String, dynamic>;
      await _cache.cacheData(cacheKey, Map<String, dynamic>.from(raw));
      return AccountStatement.fromJson(raw);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached(cacheKey);
        if (cached != null) {
          return AccountStatement.fromJson(cached);
        }
      }
      rethrow;
    }
  }

  /// Optimistically adjust cached treasury totals after a queued mutation.
  Future<void> _patchCachedTreasury({
    double expenseDelta = 0,
    double outgoingTransferDelta = 0,
    double collectionDelta = 0,
    double debtDelta = 0,
  }) async {
    final cached = _cache.getCached(_myTreasuryKey);
    if (cached == null) return;
    final map = Map<String, dynamic>.from(cached);
    final balance = (map['balance'] as num?)?.toDouble() ?? 0;
    final expenses = (map['expenses'] as num?)?.toDouble() ?? 0;
    final outgoing = (map['outgoingTransfer'] as num?)?.toDouble() ?? 0;
    final collection = (map['collection'] as num?)?.toDouble() ?? 0;
    final debts = (map['debts'] as num?)?.toDouble() ?? 0;
    map['expenses'] = expenses + expenseDelta;
    map['outgoingTransfer'] = outgoing + outgoingTransferDelta;
    map['collection'] = collection + collectionDelta;
    map['debts'] = debts + debtDelta;
    map['balance'] = balance -
        expenseDelta -
        outgoingTransferDelta -
        debtDelta +
        collectionDelta;
    await _cache.cacheData(_myTreasuryKey, map);
  }

  /// Called from collection queue so treasury balance looks right offline.
  Future<void> patchCachedTreasuryForCollection(double amountPaid) =>
      _patchCachedTreasury(collectionDelta: amountPaid);

  Future<void> patchCachedTreasuryForSupplierPay(double amount) =>
      _patchCachedTreasury(debtDelta: amount);
}
