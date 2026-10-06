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

  bool get isBiometricEnabled => _prefs.getBool(_keyBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool val) => _prefs.setBool(_keyBiometricEnabled, val);

  String get displayCurrency => _prefs.getString(_keyDisplayCurrency) ?? 'IDR';
  Future<void> setDisplayCurrency(String val) => _prefs.setString(_keyDisplayCurrency, val);

  String get displayTimezone => _prefs.getString(_keyDisplayTimezone) ?? 'Asia/Jakarta';
  Future<void> setDisplayTimezone(String val) => _prefs.setString(_keyDisplayTimezone, val);
}
