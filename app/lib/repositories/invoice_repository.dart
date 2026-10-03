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

      // Keep full offline list intact — never overwrite with filtered results.
      final isFullList = (paymentStatus == null || paymentStatus.isEmpty) &&
          (search == null || search.isEmpty);
      if (isFullList) {
        await _cache.cacheData('invoices', {
          'items': all.map((e) => e.toJson()).toList(),
          'total': total,
        });
        for (final invoice in all) {
          await _cache.cacheData('invoice_${invoice.id}', invoice.toJson());
        }
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
    final deletedIds = _cache
        .getPendingSyncs(action: 'delete_invoice')
        .map((e) => (e['payload'] as Map?)?['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final updateById = <String, Map<String, dynamic>>{};
    for (final item in _cache.getPendingSyncs(action: 'update_invoice')) {
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      final id = payload['id']?.toString() ?? '';
      if (id.isNotEmpty) updateById[id] = payload;
    }

    var list = remote.where((inv) => !deletedIds.contains(inv.id)).map((inv) {
      final upd = updateById[inv.id];
      if (upd == null) return inv;
      return _applyInvoiceUpdate(inv, upd);
    }).toList();

    final pending = _cache.getPendingSyncs(action: 'create_invoice');
    if (pending.isEmpty) return list;

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
      if (deletedIds.contains('pending-$id')) continue;
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

    return [...pendingModels, ...list];
  }

  InvoiceModel _applyInvoiceUpdate(InvoiceModel inv, Map<String, dynamic> upd) {
    final itemsRaw = upd['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((e) => InvoiceItemModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : inv.items;
    var totalWeight = 0.0;
    var totalPrice = 0.0;
    for (final line in items) {
      totalWeight += line.weight;
      totalPrice += line.weight * line.unitPrice;
    }
    return InvoiceModel(
      id: inv.id,
      invoiceNumber: inv.invoiceNumber,
      clientId: upd['clientId']?.toString() ?? inv.clientId,
      employeeId: inv.employeeId,
      items: items,
      itemCount: (upd['itemCount'] as num?)?.toInt() ?? items.length,
      grossWeight: (upd['grossWeight'] as num?)?.toDouble() ?? inv.grossWeight,
      tareWeight: (upd['tareWeight'] as num?)?.toDouble() ?? inv.tareWeight,
      totalWeight: totalWeight,
      totalPrice: totalPrice,
      paymentStatus: inv.paymentStatus,
      clientName: inv.clientName,
      notes: upd['notes']?.toString() ?? inv.notes,
      createdAt: inv.createdAt,
    );
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

  Future<InvoiceModel> updateInvoice(
    String id,
    Map<String, dynamic> updates, {
    bool allowQueue = true,
  }) async {
    if (id.startsWith('pending-')) {
      final queueId = id.substring('pending-'.length);
      final body = Map<String, dynamic>.from(updates);
      body['clientMutationId'] = queueId;
      await _cache.updatePendingSyncPayload(queueId, body);
      throw OfflineQueuedException('create_invoice', clientMutationId: queueId);
    }

    final mutationId = _cache.newMutationId();
    final body = Map<String, dynamic>.from(updates);
    body['clientMutationId'] = mutationId;

    try {
      final response =
          await _api.patch('${ApiConstants.invoices}/$id', data: body);
      final data = response.data as Map<String, dynamic>;
      final invoice =
          InvoiceModel.fromJson(data['data'] as Map<String, dynamic>);
      await _cache.cacheData('invoice_$id', invoice.toJson());
      return invoice;
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'update_invoice',
          {'id': id, ...body},
          clientMutationId: mutationId,
        );
        // Patch local cache so UI reflects the edit before sync.
        final local = _invoiceFromLocal(id);
        if (local != null) {
          final patchedModel = _applyInvoiceUpdate(local, body);
          final patched = patchedModel.toJson();
          await _cache.cacheData('invoice_$id', patched);
          final cached = _cache.getCached('invoices');
          if (cached != null) {
            final items = (cached['items'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .map((e) {
                  final itemId =
                      e['_id']?.toString() ?? e['id']?.toString() ?? '';
                  return itemId == id ? patched : e;
                })
                .toList();
            await _cache.cacheData('invoices', {...cached, 'items': items});
          }
        }
        throw OfflineQueuedException(
          'update_invoice',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<void> deleteInvoice(String id, {bool allowQueue = true}) async {
    if (id.startsWith('pending-')) {
      final queueId = id.substring('pending-'.length);
      await _cache.removePendingSync(queueId);
      return;
    }

    final mutationId = _cache.newMutationId();
    try {
      await _api.delete('${ApiConstants.invoices}/$id');
      await _removeInvoiceFromCache(id);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'delete_invoice',
          {'id': id, 'clientMutationId': mutationId},
          clientMutationId: mutationId,
        );
        await _removeInvoiceFromCache(id);
        throw OfflineQueuedException(
          'delete_invoice',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<void> _removeInvoiceFromCache(String id) async {
    final cached = _cache.getCached('invoices');
    if (cached != null) {
      final items = (cached['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) {
            final itemId = e['_id']?.toString() ?? e['id']?.toString() ?? '';
            return itemId != id;
          })
          .toList();
      await _cache.cacheData('invoices', {
        ...cached,
        'items': items,
        'total': items.length,
      });
    }
  }
}
