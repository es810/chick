import '../core/constants/api_constants.dart';
import '../models/supplier_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class SupplierRepository {
  SupplierRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<List<SupplierModel>> getSuppliers({String? search, int page = 1}) async {
    try {
      final response = await _api.get(
        ApiConstants.suppliers,
        queryParameters: {'search': search, 'page': page, 'limit': 50},
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List)
          .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheData('suppliers', {'items': list.map((s) => s.toJson()).toList()});
      return list;
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
}
