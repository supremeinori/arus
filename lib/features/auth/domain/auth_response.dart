import 'user_model.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 900,
      user: UserModel.fromJson(_extractUser(json)),
    );
  }

  /// Ambil objek user dari response auth.
  ///
  /// Beberapa endpoint (mis. `/auth/refresh`) menaruh `settings` di level atas
  /// response, bukan di dalam `user`. Kalau tidak digabung, `display_currency`
  /// akan hilang setiap kali token di-refresh dan tampilan kembali ke default.
  static Map<String, dynamic> _extractUser(Map<String, dynamic> json) {
    final rawUser = Map<String, dynamic>.from(
      json['user'] as Map<String, dynamic>? ?? const {},
    );
    final nested = rawUser['settings'] as Map<String, dynamic>?;
    final topLevel = json['settings'] as Map<String, dynamic>?;

    if (nested != null && nested.isNotEmpty) {
      rawUser['settings'] = nested;
    } else if (topLevel != null) {
      rawUser['settings'] = topLevel;
    }
    return rawUser;
  }
}
