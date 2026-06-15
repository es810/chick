import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final StorageService _storage;

  Future<AuthResponse> login(String email, String password, {bool remember = false}) async {
    final response = await _api.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });

    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? 'Login failed');
    }

    final auth = AuthResponse.fromJson(data['data'] as Map<String, dynamic>);
    await _storage.saveToken(auth.token);
    await _storage.saveUser(auth.user);
    await _storage.setRememberSession(remember);
    return auth;
  }

  UserModel? getCachedUser() => _storage.getUser();

  Future<bool> hasToken() async => (await _storage.getToken()) != null;

  Future<UserModel?> getCurrentUser() async {
    final cached = _storage.getUser();
    final token = await _storage.getToken();
    if (token == null) return null;

    try {
      final response = await _api.get(ApiConstants.me);
      final data = response.data as Map<String, dynamic>;
      final user = UserModel.fromJson(data['data'] as Map<String, dynamic>);
      await _storage.saveUser(user);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clearAll();
        return null;
      }
      return cached;
    } catch (_) {
      return cached;
    }
  }

  Future<void> clearSession() async {
    await _storage.clearAll();
  }

  Future<void> logout() async {
    final token = await _storage.getToken();
    await _storage.clearAll();
    if (token == null) return;

    try {
      await _api.dio.post(
        ApiConstants.logout,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  String? parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'] as String;
    return e.message;
  }
}
