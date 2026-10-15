import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  String get displayCurrency => _prefs.getString(_keyDisplayCurrency) ?? 'IDR';
  Future<void> setDisplayCurrency(String val) => _prefs.setString(_keyDisplayCurrency, val);

  String get displayTimezone => _prefs.getString(_keyDisplayTimezone) ?? 'Asia/Jakarta';
  Future<void> setDisplayTimezone(String val) => _prefs.setString(_keyDisplayTimezone, val);

  bool get isShakeRefreshEnabled => _prefs.getBool(_keyShakeRefreshEnabled) ?? true;
  Future<void> setShakeRefreshEnabled(bool val) => _prefs.setBool(_keyShakeRefreshEnabled, val);

  double get shakeThreshold => _prefs.getDouble(_keyShakeThreshold) ?? 6.0;
  Future<void> setShakeThreshold(double val) => _prefs.setDouble(_keyShakeThreshold, val);
}
