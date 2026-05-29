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

    if (kIsWeb) return 'http://localhost:3000/api';

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000/api';
    }

    return 'http://localhost:3000/api';
  }
}
