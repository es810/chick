import 'package:dio/dio.dart';

/// User-facing message from an API error response.
String apiErrorMessage(Object error, {String? fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return fallback ?? error.message ?? 'Request failed';
  }
  return error.toString();
}
