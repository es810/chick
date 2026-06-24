import '../core/constants/api_constants.dart';
import '../models/stock_model.dart';
import '../services/api_client.dart';

class SupplierStockRepository {
  SupplierStockRepository(this._api);

  final ApiClient _api;

  String _base(String supplierId) => '${ApiConstants.suppliers}/$supplierId/stock';

  Future<List<StockModel>> getStock(String supplierId) async {
    final response = await _api.get(_base(supplierId));
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List)
        .map((e) => StockModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockModel> addStock(String supplierId, Map<String, dynamic> payload) async {
    final response = await _api.post(_base(supplierId), data: payload);
    final data = response.data as Map<String, dynamic>;
    return StockModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<StockModel> updateStock(String supplierId, String id, Map<String, dynamic> updates) async {
    final response = await _api.put('${_base(supplierId)}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return StockModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteStock(String supplierId, String id) async {
    await _api.delete('${_base(supplierId)}/$id');
  }
}
