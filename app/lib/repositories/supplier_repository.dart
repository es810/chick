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
      final cached = _cache.getCached('suppliers');
      if (cached != null) {
        return (cached['items'] as List)
            .map((e) => SupplierModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  Future<SupplierModel> createSupplier(SupplierModel supplier) async {
    final response = await _api.post(ApiConstants.suppliers, data: supplier.toJson());
    final data = response.data as Map<String, dynamic>;
    return SupplierModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<SupplierModel> updateSupplier(String id, Map<String, dynamic> updates) async {
    final response = await _api.put('${ApiConstants.suppliers}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return SupplierModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSupplier(String id) async {
    await _api.delete('${ApiConstants.suppliers}/$id');
  }

  Future<AccountStatement> getAccountStatement(String id) async {
    final response = await _api.get('${ApiConstants.suppliers}/$id/statement');
    final data = response.data as Map<String, dynamic>;
    return AccountStatement.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> payDebt({
    required String supplierId,
    required DateTime paymentDate,
    required double amount,
    double amountDeducted = 0,
    String notes = '',
    String? employeeId,
  }) async {
    await _api.post(
      '${ApiConstants.suppliers}/$supplierId/payments',
      data: {
        'paymentDate': paymentDate.toIso8601String(),
        'amount': amount,
        'amountDeducted': amountDeducted,
        if (notes.isNotEmpty) 'notes': notes,
        if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
      },
    );
  }
}
