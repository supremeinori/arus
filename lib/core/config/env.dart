import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppEnv {
  static String? _customBaseUrl;

  /// Memungkinkan pengubahan URL server secara dinamis dari UI (misal saat ganti Wi-Fi laptop)
  static void setCustomBaseUrl(String url) {
    var clean = url.trim();
    if (clean.isNotEmpty && !clean.endsWith('/api') && !clean.endsWith('/api/')) {
      clean = clean.endsWith('/') ? '${clean}api' : '$clean/api';
    }
    _customBaseUrl = clean;
  }

  static String get currentBaseUrl => apiBaseUrl;

  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  /// Menentukan Base URL API secara otomatis jika tidak diset via --dart-define
  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    // Android: default ke IP Wi-Fi laptop agar HP fisik & emulator langsung terhubung ke web service
    if (Platform.isAndroid) {
      return 'http://10.3.25.69:5000/api';
    }

    return 'http://localhost:5000/api';
  }
}
