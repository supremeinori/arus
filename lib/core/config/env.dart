import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppEnv {
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
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }

    // Android emulator menggunakan 10.0.2.2 untuk mengarah ke localhost host machine
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }

    return 'http://localhost:5000/api';
  }
}
