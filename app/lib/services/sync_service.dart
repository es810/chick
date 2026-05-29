import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../services/cache_service.dart';

class SyncService {
  SyncService(this._cache, this._ref);

  final CacheService _cache;
  final Ref _ref;

  Future<int> syncPending() async {
    if (!await _cache.isOnline) return 0;

    final pending = _cache.getPendingSyncs();
    var synced = 0;

    for (final item in pending) {
      try {
        final action = item['action'] as String;
        final payload = Map<String, dynamic>.from(item['payload'] as Map);

        if (action == 'create_invoice') {
          await _ref.read(invoiceRepositoryProvider).createInvoice(payload);
        }

        await _cache.removePendingSync(item['timestamp'] as String);
        synced++;
      } catch (_) {
        break;
      }
    }

    return synced;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(cacheServiceProvider), ref);
});
