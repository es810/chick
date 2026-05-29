import '../core/constants/api_constants.dart';
import '../models/stock_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class StockRepository {
  StockRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<List<StockModel>> getStock() async {
    try {
      final response = await _api.get(ApiConstants.stock);
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List)
          .map((e) => StockModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheData('stock', {'items': list.map((s) => s.toJson()).toList()});
      return list;
    } catch (e) {
      final cached = _cache.getCached('stock');
      if (cached != null) {
        return (cached['items'] as List)
            .map((e) => StockModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  Future<List<StockModel>> getLowStockAlerts() async {
    final response = await _api.get(ApiConstants.stockAlerts);
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => StockModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockModel> addStock(Map<String, dynamic> payload) async {
    final response = await _api.post(ApiConstants.stock, data: payload);
    final data = response.data as Map<String, dynamic>;
    return StockModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<StockModel> updateStock(String id, Map<String, dynamic> updates) async {
    final response = await _api.put('${ApiConstants.stock}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return StockModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteStock(String id) async {
    await _api.delete('${ApiConstants.stock}/$id');
  }
}
