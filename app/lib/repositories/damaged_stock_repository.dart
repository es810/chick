import '../core/constants/api_constants.dart';
import '../models/damaged_stock_model.dart';
import '../services/api_client.dart';

class DamagedStockRepository {
  DamagedStockRepository(this._api);

  final ApiClient _api;

  Future<({List<DamagedStockEntry> entries, int totalQuantity, double totalNetWeight})> list() async {
    final response = await _api.get(ApiConstants.damagedStock);
    final data = response.data as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final list = data['data'] as List? ?? [];
    return (
      entries: list
          .map((e) => DamagedStockEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalQuantity: (summary['totalQuantity'] as num?)?.toInt() ?? 0,
      totalNetWeight: (summary['totalNetWeight'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<DamagedStockEntry> record({
    required String stockId,
    int quantity = 0,
    double? netWeight,
    String? reason,
  }) async {
    final response = await _api.post(
      ApiConstants.damagedStock,
      data: {
        'stockId': stockId,
        'quantity': quantity,
        if (netWeight != null) 'netWeight': netWeight,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return DamagedStockEntry.fromJson(data['data'] as Map<String, dynamic>);
  }
}
