import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Thrown when a mutation was saved locally and will sync later.
class OfflineQueuedException implements Exception {
  OfflineQueuedException(this.action, {this.clientMutationId});

  final String action;
  final String? clientMutationId;

  @override
  String toString() => 'OfflineQueuedException($action)';
}

class CacheService {
  static const String boxName = 'offline_cache';
  static const String pendingSyncBox = 'pending_sync';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
    await Hive.openBox(pendingSyncBox);
  }

  Box get _cache => Hive.box(boxName);
  Box get _pending => Hive.box(pendingSyncBox);

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged;

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await _cache.put(key, data);
  }

  Map<String, dynamic>? getCached(String key) {
    final data = _cache.get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  String newMutationId() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  /// Queue a mutation for later sync. Returns the queue entry id.
  Future<String> addPendingSync(
    String action,
    Map<String, dynamic> payload, {
    String? clientMutationId,
  }) async {
    final id = clientMutationId ?? newMutationId();
    final body = Map<String, dynamic>.from(payload);
    body.putIfAbsent('clientMutationId', () => id);
    await _pending.put(id, {
      'id': id,
      'action': action,
      'payload': body,
      'timestamp': DateTime.now().toIso8601String(),
    });
    return id;
  }

  List<Map<String, dynamic>> getPendingSyncs() {
    final items = <Map<String, dynamic>>[];
    for (final key in _pending.keys) {
      final raw = _pending.get(key);
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      map['id'] = map['id']?.toString() ?? key.toString();
      items.add(map);
    }
    items.sort((a, b) {
      final ta = a['timestamp']?.toString() ?? '';
      final tb = b['timestamp']?.toString() ?? '';
      return ta.compareTo(tb);
    });
    return items;
  }

  int get pendingCount => _pending.length;

  Future<void> removePendingSync(String id) => _pending.delete(id);

  Future<void> clearCache() async {
    await _cache.clear();
  }
}

final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
