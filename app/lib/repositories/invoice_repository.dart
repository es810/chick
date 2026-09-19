import '../core/constants/api_constants.dart';
import '../models/invoice_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class InvoiceRepository {
  InvoiceRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  /// Loads every invoice page so the list is not capped at 20.
  Future<({List<InvoiceModel> invoices, PaginationMeta? pagination})> getInvoices({
    String? paymentStatus,
    String? search,
  }) async {
    try {
      const limit = 100;
      var page = 1;
      var totalPages = 1;
      var total = 0;
      final all = <InvoiceModel>[];

      do {
        final response = await _api.get(
          ApiConstants.invoices,
          queryParameters: {
            'page': page,
            'limit': limit,
            if (paymentStatus != null) 'paymentStatus': paymentStatus,
            if (search != null && search.isNotEmpty) 'search': search,
          },
        );
        final data = response.data as Map<String, dynamic>;
        final invoices = (data['data'] as List)
            .map((e) => InvoiceModel.fromJson(e as Map<String, dynamic>))
            .toList();
        all.addAll(invoices);

        final pagination = data['pagination'] as Map<String, dynamic>?;
        totalPages = (pagination?['pages'] as num?)?.toInt() ?? 1;
        total = (pagination?['total'] as num?)?.toInt() ?? all.length;
        page++;
      } while (page <= totalPages);

      await _cache.cacheData('invoices', {
        'items': all.map((e) => e.toJson()).toList(),
        'total': total,
      });
      for (final invoice in all) {
        await _cache.cacheData('invoice_${invoice.id}', invoice.toJson());
      }

      final merged = _mergePendingInvoices(all);
      return (
        invoices: merged,
        pagination: PaginationMeta(total: merged.length, page: 1, pages: 1),
      );
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached('invoices');
        if (cached != null) {
          final invoices = (cached['items'] as List)
              .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return (invoices: _mergePendingInvoices(invoices), pagination: null);
        }
        final pendingOnly = _mergePendingInvoices(const []);
        if (pendingOnly.isNotEmpty) {
          return (invoices: pendingOnly, pagination: null);
        }
      }
      rethrow;
    }
  }

  List<InvoiceModel> _mergePendingInvoices(List<InvoiceModel> remote) {
    final pending = _cache.getPendingSyncs(action: 'create_invoice');
    if (pending.isEmpty) return remote;

    final clientNames = <String, String>{};
    final cachedClients = _cache.getCached('clients');
    final clientItems = cachedClients?['items'];
    if (clientItems is List) {
      for (final raw in clientItems) {
        if (raw is! Map) continue;
        final id = raw['_id']?.toString() ?? raw['id']?.toString() ?? '';
        final name = raw['name']?.toString() ?? '';
        if (id.isNotEmpty) clientNames[id] = name;
      }
    }

    final pendingModels = <InvoiceModel>[];
    for (final item in pending.reversed) {
      final id = item['id']?.toString() ?? '';
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      final clientId = payload['clientId']?.toString() ?? '';
      final itemsRaw = payload['items'];
      final items = itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => InvoiceItemModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <InvoiceItemModel>[];

      var totalWeight = 0.0;
      var totalPrice = 0.0;
      for (final line in items) {
        totalWeight += line.weight;
        totalPrice += line.weight * line.unitPrice;
      }

      pendingModels.add(
        InvoiceModel(
          id: 'pending-$id',
          invoiceNumber: 'معلّق — مزامنة',
          clientId: clientId,
          employeeId: '',
          items: items,
          itemCount: (payload['itemCount'] as num?)?.toInt() ?? items.length,
          grossWeight: (payload['grossWeight'] as num?)?.toDouble(),
          tareWeight: (payload['tareWeight'] as num?)?.toDouble(),
          totalWeight: totalWeight,
          totalPrice: totalPrice,
          paymentStatus: 'pending',
          clientName: clientNames[clientId] ?? 'عميل',
          createdAt: DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }

    return [...pendingModels, ...remote];
  }

  Future<InvoiceModel> getInvoice(String id) async {
    final local = _invoiceFromLocal(id);
    if (id.startsWith('pending-')) {
      if (local != null) return local;
      throw StateError('Pending invoice not found');
    }

    try {
      final response = await _api.get('${ApiConstants.invoices}/$id');
      final data = response.data as Map<String, dynamic>;
      final invoice = InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
      await _cache.cacheData('invoice_$id', invoice.toJson());
      return invoice;
    } catch (e) {
      if (local != null) return local;
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        throw StateError('Invoice unavailable offline');
      }
      rethrow;
    }
  }

  InvoiceModel? _invoiceFromLocal(String id) {
    if (id.startsWith('pending-')) {
      for (final invoice in _mergePendingInvoices(const [])) {
        if (invoice.id == id) return invoice;
      }
      return null;
    }

    final single = _cache.getCached('invoice_$id');
    if (single != null) {
      try {
        return InvoiceModel.fromJson(single);
      } catch (_) {}
    }

    final cached = _cache.getCached('invoices');
    final items = cached?['items'];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        try {
          final invoice =
              InvoiceModel.fromJson(Map<String, dynamic>.from(raw));
          if (invoice.id == id) return invoice;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Creates an invoice. When offline (and [allowQueue] is true), queues locally
  /// and throws [OfflineQueuedException] so the UI can show a pending success.
  Future<InvoiceModel> createInvoice(
    Map<String, dynamic> payload, {
    bool allowQueue = true,
  }) async {
    final body = Map<String, dynamic>.from(payload);
    body['clientMutationId'] ??= _cache.newMutationId();

    try {
      final response = await _api.post(ApiConstants.invoices, data: body);
      final data = response.data as Map<String, dynamic>;
      return InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'create_invoice',
          body,
          clientMutationId: body['clientMutationId'] as String?,
        );
        throw OfflineQueuedException(
          'create_invoice',
          clientMutationId: body['clientMutationId'] as String?,
        );
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
