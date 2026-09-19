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
    final response = await _api.get('${ApiConstants.collections}/$id');
    final data = response.data as Map<String, dynamic>;
    return TreasuryEntryItem.fromJson(data['data'] as Map<String, dynamic>);
  }

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
