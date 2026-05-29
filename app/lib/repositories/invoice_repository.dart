import '../core/constants/api_constants.dart';
import '../models/invoice_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class InvoiceRepository {
  InvoiceRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<({List<InvoiceModel> invoices, PaginationMeta? pagination})> getInvoices({
    int page = 1,
    String? paymentStatus,
    String? search,
  }) async {
    try {
      final response = await _api.get(
        ApiConstants.invoices,
        queryParameters: {
          'page': page,
          'limit': 20,
          if (paymentStatus != null) 'paymentStatus': paymentStatus,
          if (search != null) 'search': search,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final invoices = (data['data'] as List)
          .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final pagination = data['pagination'] != null
          ? PaginationMeta.fromJson(data['pagination'] as Map<String, dynamic>)
          : null;
      return (invoices: invoices, pagination: pagination);
    } catch (e) {
      if (!await _cache.isOnline) {
        final cached = _cache.getCached('invoices');
        if (cached != null) {
          final invoices = (cached['items'] as List)
              .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return (invoices: invoices, pagination: null);
        }
      }
      rethrow;
    }
  }

  Future<InvoiceModel> getInvoice(String id) async {
    final response = await _api.get('${ApiConstants.invoices}/$id');
    final data = response.data as Map<String, dynamic>;
    return InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<InvoiceModel> createInvoice(Map<String, dynamic> payload) async {
  try {
      final response = await _api.post(ApiConstants.invoices, data: payload);
      final data = response.data as Map<String, dynamic>;
      return InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!await _cache.isOnline) {
        await _cache.addPendingSync('create_invoice', payload);
      }
      rethrow;
    }
  }

  Future<InvoiceModel> updateInvoice(String id, Map<String, dynamic> updates) async {
    final response = await _api.patch('${ApiConstants.invoices}/$id', data: updates);
    final data = response.data as Map<String, dynamic>;
    return InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteInvoice(String id) async {
    await _api.delete('${ApiConstants.invoices}/$id');
  }
}
