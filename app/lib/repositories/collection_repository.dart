import '../core/constants/api_constants.dart';
import '../models/treasury_entry_item.dart';
import '../models/treasury_summary_model.dart';
import '../services/api_client.dart';
import '../services/cache_service.dart';

class CollectionCreateResult {
  const CollectionCreateResult({required this.entry, this.summary});

  final TreasuryEntryItem entry;
  final TreasurySummaryModel? summary;
}

class CollectionRepository {
  CollectionRepository(this._api, this._cache);

  final ApiClient _api;
  final CacheService _cache;

  Future<List<TreasuryEntryItem>> listInvoices() async {
    try {
      final response = await _api.get(ApiConstants.collections);
      final data = response.data as Map<String, dynamic>;
      final list = data['data'] as List;
      final entries = list
          .map((e) => TreasuryEntryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      await _cache.cacheData('collections', {
        'items': list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      });
      for (final entry in entries) {
        await _cache.cacheData(
          'collection_${entry.id}',
          _collectionToCacheMap(entry),
        );
      }
      return _mergePendingCollections(entries);
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached('collections');
        if (cached != null) {
          final items = (cached['items'] as List? ?? [])
              .map((e) => TreasuryEntryItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          return _mergePendingCollections(items);
        }
        final pendingOnly = _mergePendingCollections(const []);
        if (pendingOnly.isNotEmpty) return pendingOnly;
      }
      rethrow;
    }
  }

  List<TreasuryEntryItem> _mergePendingCollections(List<TreasuryEntryItem> remote) {
    final deletedIds = _cache
        .getPendingSyncs(action: 'delete_collection')
        .map((e) => (e['payload'] as Map?)?['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final updateById = <String, Map<String, dynamic>>{};
    for (final item in _cache.getPendingSyncs(action: 'update_collection')) {
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      final id = payload['id']?.toString() ?? '';
      if (id.isNotEmpty) updateById[id] = payload;
    }

    var list = remote.where((e) => !deletedIds.contains(e.id)).map((entry) {
      final upd = updateById[entry.id];
      if (upd == null) return entry;
      return TreasuryEntryItem(
        id: entry.id,
        category: entry.category,
        amount: (upd['amountPaid'] as num?)?.toDouble() ?? entry.amount,
        description: entry.description,
        subtitle: entry.subtitle,
        createdAt: entry.createdAt,
        clientId: upd['clientId']?.toString() ?? entry.clientId,
        clientName: entry.clientName,
        clientPhone: entry.clientPhone,
        clientWhatsappGroupLink: entry.clientWhatsappGroupLink,
        employeeId: upd['employeeId']?.toString() ?? entry.employeeId,
        employeeName: entry.employeeName,
        collectionDate: DateTime.tryParse(upd['collectionDate']?.toString() ?? '') ??
            entry.collectionDate,
        amountPaid: (upd['amountPaid'] as num?)?.toDouble() ?? entry.amountPaid,
        amountDeducted:
            (upd['amountDeducted'] as num?)?.toDouble() ?? entry.amountDeducted,
        balanceBefore:
            (upd['balanceBefore'] as num?)?.toDouble() ?? entry.balanceBefore,
        balanceAfter:
            (upd['balanceAfter'] as num?)?.toDouble() ?? entry.balanceAfter,
      );
    }).toList();

    final pending = _cache.getPendingSyncs(action: 'create_collection');
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

    final pendingEntries = <TreasuryEntryItem>[];
    for (final item in pending.reversed) {
      final id = item['id']?.toString() ?? '';
      if (deletedIds.contains('pending-$id')) continue;
      final payload = Map<String, dynamic>.from(item['payload'] as Map? ?? {});
      final clientId = payload['clientId']?.toString();
      final amountPaid = (payload['amountPaid'] as num?)?.toDouble() ?? 0;
      pendingEntries.add(
        TreasuryEntryItem(
          id: 'pending-$id',
          category: 'collection',
          amount: amountPaid,
          description: clientNames[clientId] ?? 'معلّق — مزامنة',
          clientId: clientId,
          clientName: clientNames[clientId],
          employeeId: payload['employeeId']?.toString(),
          collectionDate:
              DateTime.tryParse(payload['collectionDate']?.toString() ?? ''),
          amountPaid: amountPaid,
          amountDeducted: (payload['amountDeducted'] as num?)?.toDouble(),
          balanceBefore: (payload['balanceBefore'] as num?)?.toDouble(),
          balanceAfter: (payload['balanceAfter'] as num?)?.toDouble(),
          createdAt: DateTime.tryParse(item['timestamp']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }

    return [...pendingEntries, ...list];
  }

  Future<TreasuryEntryItem> getInvoice(String id) async {
    final local = _collectionFromLocal(id);
    if (id.startsWith('pending-')) {
      if (local != null) return local;
      throw StateError('Pending collection not found');
    }

    try {
      final response = await _api.get('${ApiConstants.collections}/$id');
      final data = response.data as Map<String, dynamic>;
      final entry = TreasuryEntryItem.fromJson(data['data'] as Map<String, dynamic>);
      await _cache.cacheData(
        'collection_$id',
        _collectionToCacheMap(entry),
      );
      return entry;
    } catch (e) {
      if (local != null) return local;
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        throw StateError('Collection unavailable offline');
      }
      rethrow;
    }
  }

  TreasuryEntryItem? _collectionFromLocal(String id) {
    if (id.startsWith('pending-')) {
      for (final entry in _mergePendingCollections(const [])) {
        if (entry.id == id) return entry;
      }
      return null;
    }

    final single = _cache.getCached('collection_$id');
    if (single != null) {
      try {
        return TreasuryEntryItem.fromJson(single);
      } catch (_) {}
    }

    final cached = _cache.getCached('collections');
    final items = cached?['items'];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        try {
          final entry =
              TreasuryEntryItem.fromJson(Map<String, dynamic>.from(raw));
          if (entry.id == id) return entry;
        } catch (_) {}
      }
    }
    return null;
  }

  Map<String, dynamic> _collectionToCacheMap(TreasuryEntryItem entry) => {
        'id': entry.id,
        'category': entry.category,
        'amount': entry.amount,
        'description': entry.description,
        'subtitle': entry.subtitle,
        'createdAt': entry.createdAt?.toIso8601String(),
        'clientId': entry.clientId,
        'clientName': entry.clientName,
        'clientPhone': entry.clientPhone,
        'clientWhatsappGroupLink': entry.clientWhatsappGroupLink,
        'employeeId': entry.employeeId,
        'employeeName': entry.employeeName,
        'collectionDate': entry.collectionDate?.toIso8601String(),
        'amountPaid': entry.amountPaid,
        'amountDeducted': entry.amountDeducted,
        'balanceBefore': entry.balanceBefore,
        'balanceAfter': entry.balanceAfter,
      };

  Future<List<Map<String, dynamic>>> listEmployees() async {
    try {
      final response = await _api.get('${ApiConstants.collections}/employees');
      final data = response.data as Map<String, dynamic>;
      final list = (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      await _cache.cacheData('collection_employees', {'items': list});
      return list;
    } catch (e) {
      if (await _cache.shouldQueueError(e) || !await _cache.isOnline) {
        final cached = _cache.getCached('collection_employees');
        if (cached != null) {
          return (cached['items'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      rethrow;
    }
  }

  Future<CollectionCreateResult> createInvoice({
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'clientId': clientId,
      'employeeId': employeeId,
      'collectionDate': collectionDate.toIso8601String(),
      'amountPaid': amountPaid,
      'amountDeducted': amountDeducted,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'clientMutationId': mutationId,
    };

    try {
      final response = await _api.post(ApiConstants.collections, data: body);
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      final entry = TreasuryEntryItem.fromJson(payload['entry'] as Map<String, dynamic>);
      final summary = payload['summary'] != null
          ? TreasurySummaryModel.fromJson(payload['summary'] as Map<String, dynamic>)
          : null;
      return CollectionCreateResult(entry: entry, summary: summary);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'create_collection',
          body,
          clientMutationId: mutationId,
        );
        await _patchCachedTreasuryCollection(amountPaid);
        throw OfflineQueuedException('create_collection', clientMutationId: mutationId);
      }
      rethrow;
    }
  }

  Future<void> _patchCachedTreasuryCollection(double amountPaid) async {
    final cached = _cache.getCached('my_treasury');
    if (cached == null) return;
    final map = Map<String, dynamic>.from(cached);
    final balance = (map['balance'] as num?)?.toDouble() ?? 0;
    final collection = (map['collection'] as num?)?.toDouble() ?? 0;
    map['balance'] = balance + amountPaid;
    map['collection'] = collection + amountPaid;
    await _cache.cacheData('my_treasury', map);
  }

  Future<TreasuryEntryItem> updateInvoice({
    required String id,
    required String clientId,
    required String employeeId,
    required DateTime collectionDate,
    required double amountPaid,
    required double amountDeducted,
    required double balanceBefore,
    required double balanceAfter,
    String? clientMutationId,
    bool allowQueue = true,
  }) async {
    if (id.startsWith('pending-')) {
      final queueId = id.substring('pending-'.length);
      final body = {
        'clientId': clientId,
        'employeeId': employeeId,
        'collectionDate': collectionDate.toIso8601String(),
        'amountPaid': amountPaid,
        'amountDeducted': amountDeducted,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'clientMutationId': queueId,
      };
      await _cache.updatePendingSyncPayload(queueId, body);
      throw OfflineQueuedException(
        'create_collection',
        clientMutationId: queueId,
      );
    }

    final mutationId = clientMutationId ?? _cache.newMutationId();
    final body = {
      'clientId': clientId,
      'employeeId': employeeId,
      'collectionDate': collectionDate.toIso8601String(),
      'amountPaid': amountPaid,
      'amountDeducted': amountDeducted,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'clientMutationId': mutationId,
    };
    try {
      final response = await _api.patch(
        '${ApiConstants.collections}/$id',
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>;
      final entry =
          TreasuryEntryItem.fromJson(payload['entry'] as Map<String, dynamic>);
      await _cache.cacheData('collection_$id', _collectionToCacheMap(entry));
      return entry;
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'update_collection',
          {'id': id, ...body},
          clientMutationId: mutationId,
        );
        final patched = TreasuryEntryItem(
          id: id,
          category: 'collection',
          amount: amountPaid,
          description: '',
          clientId: clientId,
          employeeId: employeeId,
          collectionDate: collectionDate,
          amountPaid: amountPaid,
          amountDeducted: amountDeducted,
          balanceBefore: balanceBefore,
          balanceAfter: balanceAfter,
          createdAt: _collectionFromLocal(id)?.createdAt,
          clientName: _collectionFromLocal(id)?.clientName,
          clientPhone: _collectionFromLocal(id)?.clientPhone,
          clientWhatsappGroupLink:
              _collectionFromLocal(id)?.clientWhatsappGroupLink,
          employeeName: _collectionFromLocal(id)?.employeeName,
        );
        await _cache.cacheData('collection_$id', _collectionToCacheMap(patched));
        await _upsertCollectionInListCache(patched);
        throw OfflineQueuedException(
          'update_collection',
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
      await _api.delete('${ApiConstants.collections}/$id');
      await _removeCollectionFromCache(id);
    } catch (e) {
      if (allowQueue && await _cache.shouldQueueError(e)) {
        await _cache.addPendingSync(
          'delete_collection',
          {'id': id, 'clientMutationId': mutationId},
          clientMutationId: mutationId,
        );
        await _removeCollectionFromCache(id);
        throw OfflineQueuedException(
          'delete_collection',
          clientMutationId: mutationId,
        );
      }
      rethrow;
    }
  }

  Future<void> _removeCollectionFromCache(String id) async {
    final cached = _cache.getCached('collections');
    if (cached == null) return;
    final items = (cached['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) {
          final itemId = e['_id']?.toString() ?? e['id']?.toString() ?? '';
          return itemId != id;
        })
        .toList();
    await _cache.cacheData('collections', {...cached, 'items': items});
  }

  Future<void> _upsertCollectionInListCache(TreasuryEntryItem entry) async {
    final cached = _cache.getCached('collections');
    if (cached == null) return;
    final map = _collectionToCacheMap(entry);
    final items = (cached['items'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    var found = false;
    for (var i = 0; i < items.length; i++) {
      final itemId =
          items[i]['_id']?.toString() ?? items[i]['id']?.toString() ?? '';
      if (itemId == entry.id) {
        items[i] = map;
        found = true;
        break;
      }
    }
    if (!found) items.insert(0, map);
    await _cache.cacheData('collections', {...cached, 'items': items});
  }
}
