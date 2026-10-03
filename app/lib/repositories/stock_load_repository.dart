import '../core/constants/api_constants.dart';
import '../models/stock_load_model.dart';
import '../models/stock_load_statement_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class StockLoadRepository {
  StockLoadRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<List<StockLoadModel>> list({String? status}) async {
    try {
      final response = await _api.get(
        ApiConstants.stockLoads,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List? ?? [];
      final items = list
          .map((e) => StockLoadModel.fromJson(e as Map<String, dynamic>))
          .toList();
      // Always cache the employee list used by the stock loads screen.
      final isFullEmployeeView = status == null ||
          status.isEmpty ||
          (status.contains('open') && status.contains('closed'));
      if (isFullEmployeeView) {
        await _cache.cacheData('stock_loads', {
          'items': list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        });
      }
      return items;
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached('stock_loads');
        if (cached != null) {
          var items = (cached['items'] as List? ?? [])
              .map(
                (e) => StockLoadModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          if (status != null && status.isNotEmpty) {
            final allowed = status.split(',').map((s) => s.trim()).toSet();
            items = items.where((l) => allowed.contains(l.status)).toList();
          }
          return items;
        }
      }
      rethrow;
    }
  }

  /// إنهاء التوزيع — remaining becomes عجز (open load_deficit).
  Future<StockLoadModel> finish(String id) async {
    final response = await _api.post('${ApiConstants.stockLoads}/$id/finish');
    final data = response.data as Map<String, dynamic>;
    return StockLoadModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<StockLoadStatement> getStatement(String id) async {
    final cacheKey = 'stock_load_statement_$id';
    try {
      final response =
          await _api.get('${ApiConstants.stockLoads}/$id/statement');
      final data = response.data as Map<String, dynamic>;
      final raw = Map<String, dynamic>.from(data['data'] as Map);
      await _cache.cacheData(cacheKey, raw);
      return StockLoadStatement.fromJson(raw);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached(cacheKey);
        if (cached != null) {
          return StockLoadStatement.fromJson(cached);
        }
      }
      rethrow;
    }
  }
}
