import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
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

  /// Link-level connectivity (not a guarantee of reachable API).
  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    if (result.isEmpty) return false;
    return !result.contains(ConnectivityResult.none);
  }

  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Connectivity().onConnectivityChanged;

  /// Whether a failed mutation should be queued / a read should use cache.
  Future<bool> shouldQueueError(Object e) async {
    if (!await isOnline) return true;
    if (e is! DioException) return false;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // Host unreachable / DNS / socket errors often surface as unknown
        // with no HTTP response.
        return e.response == null;
      case DioExceptionType.badResponse:
        // Captive portals sometimes return HTML 502/503 with no API body.
        final code = e.response?.statusCode ?? 0;
        return code == 502 || code == 503 || code == 504;
      default:
        return false;
    }
  }

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

  List<Map<String, dynamic>> getPendingSyncs({String? action}) {
    final items = <Map<String, dynamic>>[];
    for (final key in _pending.keys) {
      final raw = _pending.get(key);
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      map['id'] = map['id']?.toString() ?? key.toString();
      if (action != null && map['action'] != action) continue;
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
