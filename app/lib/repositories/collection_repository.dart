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
    final pending = _cache.getPendingSyncs(action: 'create_collection');
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

    final pendingEntries = <TreasuryEntryItem>[];
    for (final item in pending.reversed) {
      final id = item['id']?.toString() ?? '';
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

    return [...pendingEntries, ...remote];
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
        throw OfflineQueuedException('create_collection', clientMutationId: mutationId);
      }
      rethrow;
    }
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
  }) async {
    final response = await _api.patch(
      '${ApiConstants.collections}/$id',
      data: {
        'clientId': clientId,
        'employeeId': employeeId,
        'collectionDate': collectionDate.toIso8601String(),
        'amountPaid': amountPaid,
        'amountDeducted': amountDeducted,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final payload = data['data'] as Map<String, dynamic>;
    return TreasuryEntryItem.fromJson(payload['entry'] as Map<String, dynamic>);
  }

  Future<void> deleteInvoice(String id) async {
    await _api.delete('${ApiConstants.collections}/$id');
  }
}
