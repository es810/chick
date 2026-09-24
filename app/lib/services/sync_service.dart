import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../features/auth/providers/auth_provider.dart';
import '../services/cache_service.dart';

class SyncService {
  SyncService(this._cache, this._ref);

  final CacheService _cache;
  final Ref _ref;

  bool _syncing = false;
  StreamSubscription? _connectivitySub;
  String? lastError;

  /// Start listening for network restore and sync automatically.
  void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = _cache.onConnectivityChanged.listen((results) async {
      final online =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (!online) return;
      // Brief delay so the radio/DNS is ready after reconnect.
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        await syncPending();
        await warmOfflineCaches();
      } catch (e) {
        debugPrint('Auto sync failed: $e');
      }
    });
    // Kick once at startup in case there are leftovers (after auth restores).
    Future<void>.delayed(const Duration(seconds: 3), () async {
      try {
        await syncPending();
        await warmOfflineCaches();
      } catch (_) {}
    });
  }

  /// Prefetch clients + invoices + collections (+ stock) so offline client work
  /// (list, statements, details) is available without visiting every screen.
  Future<void> warmOfflineCaches() async {
    if (!await _cache.isOnline) return;
    if (_ref.read(authProvider).user == null) return;

    Future<void> safe(Future<void> Function() run) async {
      try {
        await run();
      } catch (e) {
        debugPrint('Warm offline cache step failed: $e');
      }
    }

    await Future.wait([
      safe(() async {
        await _ref.read(clientRepositoryProvider).getClients();
      }),
      safe(() async {
        await _ref.read(invoiceRepositoryProvider).getInvoices();
      }),
      safe(() async {
        await _ref.read(collectionRepositoryProvider).listInvoices();
      }),
      safe(() async {
        await _ref.read(stockRepositoryProvider).getStock();
      }),
    ]);
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<int> syncPending() async {
    if (_syncing) return 0;
    if (_cache.pendingCount == 0) return 0;
    if (!await _cache.isOnline) return 0;

    // Need a session before POSTing queued mutations.
    if (_ref.read(authProvider).user == null) return 0;

    _syncing = true;
    var synced = 0;
    lastError = null;

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
                    collectionDate:
                        DateTime.parse(payload['collectionDate'] as String),
                    amountPaid: (payload['amountPaid'] as num).toDouble(),
                    amountDeducted:
                        (payload['amountDeducted'] as num).toDouble(),
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
          lastError = e.toString();
          debugPrint('Sync item $id failed: $e');
          // Network blip: leave item queued and stop; will retry on resume.
          if (await _cache.shouldQueueError(e)) {
            break;
          }
          // Permanent/business error: stop to preserve money order.
          break;
        }
      }

      if (synced > 0) {
        invalidateAllAppData(_ref);
      }
      // Refresh offline snapshots after reconnect / successful flush.
      await warmOfflineCaches();
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
