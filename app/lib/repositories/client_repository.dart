import '../core/constants/api_constants.dart';
import '../models/client_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class ClientRepository {
  ClientRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<List<ClientModel>> getClients({String? search, int page = 1}) async {
    try {
      final response = await _api.get(
        ApiConstants.clients,
        queryParameters: {'search': search, 'page': page, 'limit': 50},
      );
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List)
          .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheData('clients', {'items': list.map((c) => c.toJson()).toList()});
      return list;
    } catch (e) {
      final cached = _cache.getCached('clients');
      if (cached != null) {
        return (cached['items'] as List)
            .map((e) => ClientModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      rethrow;
    }
  }

  Future<ClientModel> createClient(ClientModel client, {String? password}) async {
    final response = await _api.post(
      ApiConstants.clients,
      data: client.toJson(password: password),
    );
    final data = response.data as Map<String, dynamic>;
    return ClientModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<ClientModel> updateClient(String id, Map<String, dynamic> updates) async {
    final response = await _api.put('${ApiConstants.clients}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return ClientModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteClient(String id) async {
    await _api.delete('${ApiConstants.clients}/$id');
  }
}
