class AppEnv {
  static String? _customBaseUrl;

  /// Memungkinkan pengubahan URL server secara dinamis dari UI jika diinginkan
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
    defaultValue: 'production',
  );

  /// Menentukan Base URL API secara default mengarah ke Cloud Web Service Vercel
  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    // Default ke Cloud Web Service Vercel resmi (online 24/7 HTTPS)
    return 'https://arus-lime.vercel.app/api';
  }
}
