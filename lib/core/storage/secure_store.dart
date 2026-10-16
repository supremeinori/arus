import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore();
});

class SecureStore {
  final FlutterSecureStorage _storage;

  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  static const _keyAccessToken = 'arus_access_token';
  static const _keyRefreshToken = 'arus_refresh_token';
  static const _keyBiometricEnabled = 'arus_biometric_enabled';
  static const _keyUserJson = 'arus_user_json';
  static const _keyLoginTimestamp = 'arus_login_timestamp';

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureStore] Warning: failed to read $key: $e');
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStore] Warning: failed to write $key: $e');
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStore] Warning: failed to delete $key: $e');
    }
  }

  Future<String?> getAccessToken() async => await _safeRead(_keyAccessToken);
  Future<void> setAccessToken(String token) async => await _safeWrite(_keyAccessToken, token);
  Future<void> deleteAccessToken() async => await _safeDelete(_keyAccessToken);

  Future<String?> getRefreshToken() async => await _safeRead(_keyRefreshToken);
  Future<void> setRefreshToken(String token) async => await _safeWrite(_keyRefreshToken, token);
  Future<void> deleteRefreshToken() async => await _safeDelete(_keyRefreshToken);

  Future<bool> isBiometricEnabled() async {
    final val = await _safeRead(_keyBiometricEnabled);
    return val == 'true' || val == '1';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _safeWrite(_keyBiometricEnabled, enabled ? 'true' : 'false');
  }

  Future<String?> getUserJson() async => await _safeRead(_keyUserJson);
  Future<void> setUserJson(String json) async => await _safeWrite(_keyUserJson, json);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
    bool? biometricEnabled,
  }) async {
    await setAccessToken(accessToken);
    await setRefreshToken(refreshToken);
    await setUserJson(userJson);
    await _safeWrite(_keyLoginTimestamp, DateTime.now().toIso8601String());
    if (biometricEnabled != null) {
      await setBiometricEnabled(biometricEnabled);
    }
  }

  Future<bool> hasValidStoredSession() async {
    try {
      final refresh = await getRefreshToken();
      final userJson = await getUserJson();
      return refresh != null && refresh.isNotEmpty && userJson != null && userJson.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah token/sesi telah kedaluwarsa (> 7 hari)
  Future<bool> isSessionExpired() async {
    try {
      final tsStr = await _safeRead(_keyLoginTimestamp);
      if (tsStr == null) return false;
      final loginDate = DateTime.parse(tsStr);
      final diff = DateTime.now().difference(loginDate);
      return diff.inDays >= 7;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateLoginTimestamp() async {
    await _safeWrite(_keyLoginTimestamp, DateTime.now().toIso8601String());
  }

  Future<void> clearTokens() async {
    await deleteAccessToken();
    await deleteRefreshToken();
    await _safeDelete(_keyUserJson);
    await _safeDelete(_keyLoginTimestamp);
  }

  Future<void> clearAllSession() async {
    await clearTokens();
    await _safeDelete(_keyBiometricEnabled);
  }
}
