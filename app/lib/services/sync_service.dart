import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../services/cache_service.dart';

class SyncService {
  SyncService(this._cache, this._ref);

  final CacheService _cache;
  final Ref _ref;

  bool _syncing = false;
  StreamSubscription? _connectivitySub;

  /// Start listening for network restore and sync automatically.
  void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = _cache.onConnectivityChanged.listen((results) async {
      final online = !results.contains(ConnectivityResult.none);
      if (online) {
        try {
          await syncPending();
        } catch (e) {
          debugPrint('Auto sync failed: $e');
        }
      }
    });
    // Kick once at startup in case there are leftovers.
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        await syncPending();
      } catch (_) {}
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<int> syncPending() async {
    if (_syncing) return 0;
    if (!await _cache.isOnline) return 0;

    _syncing = true;
    var synced = 0;

    try {
      final pending = _cache.getPendingSyncs();
      for (final item in pending) {
        final id = item['id']?.toString();
        if (id == null || id.isEmpty) continue;

        try {
          final action = item['action'] as String;
          final payload = Map<String, dynamic>.from(item['payload'] as Map);

          switch (action) {
            case 'create_invoice':
              await _ref.read(invoiceRepositoryProvider).createInvoice(
                    payload,
                    allowQueue: false,
                  );
              break;
            case 'create_collection':
              await _ref.read(collectionRepositoryProvider).createInvoice(
                    clientId: payload['clientId'] as String,
                    employeeId: payload['employeeId'] as String,
                    collectionDate: DateTime.parse(payload['collectionDate'] as String),
                    amountPaid: (payload['amountPaid'] as num).toDouble(),
                    amountDeducted: (payload['amountDeducted'] as num).toDouble(),
                    balanceBefore: (payload['balanceBefore'] as num).toDouble(),
                    balanceAfter: (payload['balanceAfter'] as num).toDouble(),
                    clientMutationId: payload['clientMutationId'] as String?,
                    allowQueue: false,
                  );
              break;
            case 'add_expense':
              final amount = (payload['amount'] as num).toDouble();
              final description = payload['description'] as String;
              final employeeId = payload['employeeId'] as String?;
              if (employeeId != null && employeeId.isNotEmpty) {
                await _ref.read(employeeRepositoryProvider).addExpense(
                      employeeId,
                      amount,
                      description,
                      clientMutationId: payload['clientMutationId'] as String?,
                      allowQueue: false,
                    );
              } else {
                await _ref.read(employeeRepositoryProvider).addMyExpense(
                      amount,
                      description,
                      clientMutationId: payload['clientMutationId'] as String?,
                      allowQueue: false,
                    );
              }
              break;
            default:
              // Unknown legacy action — drop so it doesn't block the queue.
              break;
          }

          await _cache.removePendingSync(id);
          synced++;
        } catch (e) {
          debugPrint('Sync item $id failed: $e');
          // Stop on first failure to preserve order for money-related ops.
          break;
        }
      }

      if (synced > 0) {
        invalidateAllAppData(_ref);
      }
    } finally {
      _syncing = false;
    }

    return synced;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(cacheServiceProvider), ref);
  ref.onDispose(service.dispose);
  return service;
});
