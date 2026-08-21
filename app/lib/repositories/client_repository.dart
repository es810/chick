import '../core/constants/api_constants.dart';
import '../models/client_model.dart';
import '../models/account_statement_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class ClientRepository {
  ClientRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  /// Loads every client page so the list is not capped at 50.
  Future<List<ClientModel>> getClients({String? search}) async {
    try {
      const limit = 100;
      var page = 1;
      var totalPages = 1;
      final all = <ClientModel>[];

      do {
        final response = await _api.get(
          ApiConstants.clients,
          queryParameters: {
            if (search != null && search.isNotEmpty) 'search': search,
            'page': page,
            'limit': limit,
          },
        );
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List)
            .map((e) => ClientModel.fromJson(e as Map<String, dynamic>))
            .toList();
        all.addAll(list);

        final pagination = data['pagination'] as Map<String, dynamic>?;
        totalPages = (pagination?['pages'] as num?)?.toInt() ?? 1;
        page++;
      } while (page <= totalPages);

      await _cache.cacheData('clients', {
        'items': all.map((c) => c.toJson()).toList(),
      });
      return all;
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

  Future<AccountStatement> getAccountStatement(String id) async {
    final response = await _api.get('${ApiConstants.clients}/$id/statement');
    final data = response.data as Map<String, dynamic>;
    return AccountStatement.fromJson(data['data'] as Map<String, dynamic>);
  }
}
