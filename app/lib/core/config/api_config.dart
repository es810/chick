import 'dart:io';

import 'package:flutter/foundation.dart';

/// API base URL from build (--dart-define) or platform default (dev only).
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      var value = fromEnv.trim().replaceAll(RegExp(r'/+$'), '');
      if (!value.endsWith('/api')) value = '$value/api';
      return value;
    }

    if (kIsWeb) return 'https://chick-production.up.railway.app/api';

    if (Platform.isAndroid) {
      return 'https://chick-production.up.railway.app/api';
    }

    return 'https://chick-production.up.railway.app/api';
  }
}
