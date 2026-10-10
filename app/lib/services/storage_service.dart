import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class StorageService {
  StorageService(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _secureTimeout = Duration(seconds: 4);

  /// Persist token in secure storage and SharedPreferences fallback.
  /// Android Keystore / encrypted prefs can flake; prefs keeps the session alive.
  Future<void> saveToken(String token) async {
    await _prefs.setString(AppConstants.tokenKey, token);
    try {
      await _secure.write(key: AppConstants.tokenKey, value: token).timeout(_secureTimeout);
    } catch (e) {
      debugPrint('saveToken secure failed (prefs kept): $e');
    }
  }

  Future<String?> getToken() async {
    try {
      final secure = await _secure.read(key: AppConstants.tokenKey).timeout(_secureTimeout);
      if (secure != null && secure.isNotEmpty) {
        // Keep prefs mirror in sync for next secure-storage failure.
        if (_prefs.getString(AppConstants.tokenKey) != secure) {
          await _prefs.setString(AppConstants.tokenKey, secure);
        }
        return secure;
      }
    } catch (e) {
      debugPrint('getToken secure failed, trying prefs: $e');
    }
    final fallback = _prefs.getString(AppConstants.tokenKey);
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  Future<void> clearToken() async {
    await _prefs.remove(AppConstants.tokenKey);
    try {
      await _secure.delete(key: AppConstants.tokenKey).timeout(_secureTimeout);
    } catch (e) {
      debugPrint('clearToken secure failed: $e');
    }
  }

  Future<void> saveUser(UserModel user) =>
      _prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  UserModel? getUser() {
    final data = _prefs.getString(AppConstants.userKey);
    if (data == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
  Future<void> clearUser() => _prefs.remove(AppConstants.userKey);

  Future<void> setRememberSession(bool value) =>
      _prefs.setBool(AppConstants.rememberKey, value);
  bool getRememberSession() => _prefs.getBool(AppConstants.rememberKey) ?? false;

  Future<void> setThemeMode(String mode) => _prefs.setString(AppConstants.themeKey, mode);
  String getThemeMode() => _prefs.getString(AppConstants.themeKey) ?? 'system';

  Future<void> setLocale(String code) => _prefs.setString(AppConstants.localeKey, code);
  String getLocale() => _prefs.getString(AppConstants.localeKey) ?? 'en';

  Future<void> clearAll() async {
    await clearToken();
    await clearUser();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be overridden');
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});
