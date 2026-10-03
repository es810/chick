import '../core/constants/api_constants.dart';
import '../models/supplier_model.dart';
import '../models/account_statement_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class SupplierRepository {
  SupplierRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  /// Loads every supplier page so the list is not capped at 50.
  Future<List<SupplierModel>> getSuppliers({String? search}) async {
    try {
      const limit = 100;
      var page = 1;
      var totalPages = 1;
      final all = <SupplierModel>[];

      do {
        final response = await _api.get(
          ApiConstants.suppliers,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'page': page,
            'limit': limit,
          },
        );
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List)
            .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
            .toList();
        all.addAll(list);

        final pagination = data['pagination'] as Map<String, dynamic>?;
        totalPages = (pagination?['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= totalPages);

      await _cache.cacheData('suppliers', {
        'items': all.map((s) => s.toJson()).toList(),
      });
      return all;
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached('suppliers');
        if (cached != null) {
          var list = (cached['items'] as List)
              .map((e) =>
                  SupplierModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          if (search != null && search.isNotEmpty) {
            final q = search.toLowerCase();
            list = list
                .where((s) =>
                    s.name.toLowerCase().contains(q) ||
                    s.phone.toLowerCase().contains(q))
                .toList();
          }
          return list;
        }
      }
      rethrow;
    }
  }

  Future<SupplierModel> createSupplier(SupplierModel supplier) async {
    final response =
        await _api.post(ApiConstants.suppliers, data: supplier.toJson());
    final data = response.data as Map<String, dynamic>;
    return SupplierModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<SupplierModel> updateSupplier(
      String id, Map<String, dynamic> updates) async {
    final response =
        await _api.put('${ApiConstants.suppliers}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return SupplierModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSupplier(String id) async {
    await _api.delete('${ApiConstants.suppliers}/$id');
  }

  Future<AccountStatement> getAccountStatement(String id) async {
    final cacheKey = 'supplier_statement_$id';
    try {
      final response =
          await _api.get('${ApiConstants.suppliers}/$id/statement');
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

  Future<void> payDebt({
    required String supplierId,
    required DateTime paymentDate,
    required double amount,
    double amountDeducted = 0,
    String notes = '',
    String? employeeId,
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'paymentDate': paymentDate.toIso8601String(),
      'amount': amount,
      'amountDeducted': amountDeducted,
      if (notes.isNotEmpty) 'notes': notes,
      if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      'clientMutationId': mutationId,
    };
    try {
      await _api.post(
        '${ApiConstants.suppliers}/$supplierId/payments',
        data: body,
      );
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'pay_supplier',
          {'supplierId': supplierId, ...body},
          clientMutationId: mutationId,
        );
        // Optimistic supplier balance + employee treasury.
        await _patchSupplierBalance(
          supplierId,
          -(amount + amountDeducted),
        );
        final treasury = _cache.getCached('my_treasury');
        if (treasury != null) {
          final map = Map<String, dynamic>.from(treasury);
          final balance = (map['balance'] as num?)?.toDouble() ?? 0;
          final debts = (map['debts'] as num?)?.toDouble() ?? 0;
          map['balance'] = balance - amount;
          map['debts'] = debts + amount;
          await _cache.cacheData('my_treasury', map);
        }
        throw OfflineQueuedException(
          'pay_supplier',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<void> _patchSupplierBalance(String supplierId, double delta) async {
    final cached = _cache.getCached('suppliers');
    if (cached == null) return;
    final items = (cached['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    for (final item in items) {
      final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
      if (id != supplierId) continue;
      final bal = (item['balance'] as num?)?.toDouble() ?? 0;
      item['balance'] = bal + delta;
      break;
    }
    await _cache.cacheData('suppliers', {'items': items});

    final stmt = _cache.getCached('supplier_statement_$supplierId');
    if (stmt != null) {
      final map = Map<String, dynamic>.from(stmt);
      final entity = Map<String, dynamic>.from(map['entity'] as Map? ?? {});
      final bal = (entity['balance'] as num?)?.toDouble() ?? 0;
      entity['balance'] = bal + delta;
      map['entity'] = entity;
      await _cache.cacheData('supplier_statement_$supplierId', map);
    }
  }
}
