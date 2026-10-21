import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/money_formatter.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main()');
});

final prefsStoreProvider = Provider<PrefsStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrefsStore(prefs);
});

class PrefsStore {
  final SharedPreferences _prefs;

  PrefsStore(this._prefs);

  static const _keyBiometricEnabled = 'biometric_enabled';
  static const _keyDisplayCurrency = 'display_currency';
  static const _keyDisplayTimezone = 'display_timezone';
  static const _keyShakeRefreshEnabled = 'shake_refresh_enabled';
  static const _keyShakeThreshold = 'shake_threshold';

  bool get isBiometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool val) => _prefs.setBool(_keyBiometricEnabled, val);

  /// Preferensi matauang untuk akun tertentu (disimpan per user id).
  ///
  /// Dipisah per akun supaya pilihan user A tidak terbawa ke user B di
  /// perangkat yang sama. Sumber kebenaran tetap kolom `User.display_currency`
  /// di server.
  String displayCurrencyFor(String userId) {
    if (userId.isEmpty) return displayCurrency;
    return _prefs.getString('${_keyDisplayCurrency}_$userId') ?? displayCurrency;
  }

  Future<void> setDisplayCurrencyFor(String userId, String val) {
    if (userId.isEmpty) return setDisplayCurrency(val);
    return _prefs.setString('${_keyDisplayCurrency}_$userId', val);
  }

  String get displayCurrency =>
      _prefs.getString(_keyDisplayCurrency) ?? MoneyFormatter.defaultCurrency;
  Future<void> setDisplayCurrency(String val) => _prefs.setString(_keyDisplayCurrency, val);

  String get displayTimezone => _prefs.getString(_keyDisplayTimezone) ?? 'Asia/Jakarta';
  Future<void> setDisplayTimezone(String val) => _prefs.setString(_keyDisplayTimezone, val);

  bool get isShakeRefreshEnabled => _prefs.getBool(_keyShakeRefreshEnabled) ?? true;
  Future<void> setShakeRefreshEnabled(bool val) => _prefs.setBool(_keyShakeRefreshEnabled, val);

  double get shakeThreshold => _prefs.getDouble(_keyShakeThreshold) ?? 6.0;
  Future<void> setShakeThreshold(double val) => _prefs.setDouble(_keyShakeThreshold, val);
}
