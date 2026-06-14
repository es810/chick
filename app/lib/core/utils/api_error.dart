import 'package:dio/dio.dart';

/// User-facing message from an API error response.
String apiErrorMessage(Object error, {String? fallback}) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return fallback ?? 'Session expired. Please login again.';
    }
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (status == 500) {
      return fallback ?? 'Server error. Try again or contact support.';
    }
    return fallback ?? error.message ?? 'Request failed';
  }
  return error.toString();
}
