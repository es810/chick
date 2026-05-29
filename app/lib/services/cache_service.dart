import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String boxName = 'offline_cache';
  static const String pendingSyncBox = 'pending_sync';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(boxName);
    await Hive.openBox<Map>(pendingSyncBox);
  }

  Box<Map> get _cache => Hive.box<Map>(boxName);
  Box<Map> get _pending => Hive.box<Map>(pendingSyncBox);

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await _cache.put(key, data);
  }

  Map<String, dynamic>? getCached(String key) {
    final data = _cache.get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  Future<void> addPendingSync(String action, Map<String, dynamic> payload) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _pending.put(id, {'action': action, 'payload': payload, 'timestamp': id});
  }

  List<Map<String, dynamic>> getPendingSyncs() {
    return _pending.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> removePendingSync(String id) => _pending.delete(id);

  Future<void> clearCache() async {
    await _cache.clear();
  }
}

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
