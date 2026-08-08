import '../core/constants/api_constants.dart';
import '../models/stock_load_model.dart';
import '../services/api_client.dart';

class StockLoadRepository {
  StockLoadRepository(this._api);

  final ApiClient _api;

  Future<List<StockLoadModel>> list({String? status}) async {
    final response = await _api.get(
      ApiConstants.stockLoads,
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final list = data['data'] as List? ?? [];
    return list
        .map((e) => StockLoadModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// إنهاء التوزيع — remaining becomes عجز (open load_deficit).
  Future<StockLoadModel> finish(String id) async {
    final response = await _api.post('${ApiConstants.stockLoads}/$id/finish');
    final data = response.data as Map<String, dynamic>;
    return StockLoadModel.fromJson(data['data'] as Map<String, dynamic>);
  }
}
