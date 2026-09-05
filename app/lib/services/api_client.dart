import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/api_config.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final path = error.requestOptions.path;

        if (status == 401 && !_isAuthExemptPath(path) && !_sessionExpiryHandling) {
          _sessionExpiryHandling = true;
          try {
            await _storage.clearAll();
            await onSessionExpired?.call();
          } finally {
            _sessionExpiryHandling = false;
          }
        }
        handler.next(error);
      },
    ));
  }

  /// Set from the app root to clear auth state when the token expires.
  static Future<void> Function()? onSessionExpired;

  static bool _sessionExpiryHandling = false;

  final StorageService _storage;
  late final Dio _dio;

  static bool _isAuthExemptPath(String path) =>
      path.contains('/auth/login') || path.contains('/auth/logout');

  Dio get dio => _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.patch<T>(path, data: data, queryParameters: queryParameters);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.delete<T>(path, queryParameters: queryParameters);
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(storageServiceProvider));
});

final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
