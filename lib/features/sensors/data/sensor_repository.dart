import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/sensor_models.dart';

final sensorRepositoryProvider = Provider<SensorRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SensorRepository(client);
});

class SensorRepository {
  final ApiClient _client;

  SensorRepository(this._client);

  static UserSettingsModel _cachedSettings = const UserSettingsModel(
    userId: 'usr-demo-owner',
    displayCurrency: 'IDR',
    displayTimezone: 'Asia/Jakarta',
    biometricEnabled: true,
    shakeRefreshEnabled: true,
    tiltEnabled: true,
    dailyRevenueTargetIdr: 15000000,
  );

  Future<UserSettingsModel> getUserSettings() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/users/me/settings');
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      _cachedSettings = UserSettingsModel.fromJson(data);
      return _cachedSettings;
    } catch (_) {
      return _cachedSettings;
    }
  }

  Future<UserSettingsModel> updateUserSettings({
    bool? biometricEnabled,
    bool? shakeRefreshEnabled,
    bool? tiltEnabled,
    String? displayCurrency,
    String? displayTimezone,
  }) async {
    final payload = <String, dynamic>{};
    if (biometricEnabled != null) payload['biometric_enabled'] = biometricEnabled;
    if (shakeRefreshEnabled != null) payload['shake_refresh_enabled'] = shakeRefreshEnabled;
    if (tiltEnabled != null) payload['tilt_enabled'] = tiltEnabled;
    if (displayCurrency != null) payload['display_currency'] = displayCurrency;
    if (displayTimezone != null) payload['display_timezone'] = displayTimezone;

    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/users/me/settings',
        data: payload,
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      _cachedSettings = UserSettingsModel.fromJson(data);
      return _cachedSettings;
    } catch (_) {
      _cachedSettings = _cachedSettings.copyWith(
        biometricEnabled: biometricEnabled,
        shakeRefreshEnabled: shakeRefreshEnabled,
        tiltEnabled: tiltEnabled,
        displayCurrency: displayCurrency,
        displayTimezone: displayTimezone,
      );
      return _cachedSettings;
    }
  }
}
