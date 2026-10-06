import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/sensor_models.dart';
import '../data/sensor_repository.dart';

// Accelerometer state & simulation
class AccelerometerNotifier extends StateNotifier<AccelerometerReading> {
  AccelerometerNotifier() : super(AccelerometerReading.zero());

  void update(double x, double y, double z) {
    state = AccelerometerReading(
      x: x,
      y: y,
      z: z,
      timestamp: DateTime.now(),
    );
  }

  void simulateShake({double surge = 22.0}) {
    state = AccelerometerReading(
      x: surge * 0.6,
      y: surge * 0.7,
      z: surge * 0.4,
      timestamp: DateTime.now(),
    );
    // Settle back to earth gravity after short delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        state = AccelerometerReading.zero();
      }
    });
  }

  void reset() {
    state = AccelerometerReading.zero();
  }
}

final accelerometerProvider = StateNotifierProvider<AccelerometerNotifier, AccelerometerReading>((ref) {
  return AccelerometerNotifier();
});

// Gyroscope state & simulation
class GyroscopeNotifier extends StateNotifier<GyroscopeReading> {
  GyroscopeNotifier() : super(GyroscopeReading.zero());

  void setTilt({double? pitch, double? roll, double? yaw}) {
    state = state.copyWith(
      pitch: pitch,
      roll: roll,
      yaw: yaw,
      timestamp: DateTime.now(),
    );
  }

  void reset() {
    state = GyroscopeReading.zero();
  }
}

final gyroscopeProvider = StateNotifierProvider<GyroscopeNotifier, GyroscopeReading>((ref) {
  return GyroscopeNotifier();
});

// Shake threshold setting (default 12.0 m/s^2 delta)
final shakeThresholdProvider = StateProvider<double>((ref) => 12.0);

// Shake event notification stream (emits timestamp on shake)
class ShakeEventNotifier extends StateNotifier<DateTime?> {
  final Ref _ref;
  DateTime? _lastShakeTime;

  ShakeEventNotifier(this._ref) : super(null);

  void triggerShake() {
    final now = DateTime.now();
    // Debounce 1 detik agar tidak trigger beruntun
    if (_lastShakeTime != null && now.difference(_lastShakeTime!).inMilliseconds < 1000) {
      return;
    }

    final settings = _ref.read(sensorSettingsProvider).value;
    final isEnabled = settings?.shakeRefreshEnabled ?? true;

    if (isEnabled) {
      _lastShakeTime = now;
      state = now;
      // Berikan efek akselerometer
      _ref.read(accelerometerProvider.notifier).simulateShake();
    }
  }

  void reset() {
    state = null;
  }
}

final shakeEventProvider = StateNotifierProvider<ShakeEventNotifier, DateTime?>((ref) {
  return ShakeEventNotifier(ref);
});

// User Sensor Settings Notifier (Loads & persists to backend)
class SensorSettingsNotifier extends StateNotifier<AsyncValue<UserSettingsModel>> {
  final SensorRepository _repository;

  SensorSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _repository.getUserSettings();
      state = AsyncValue.data(settings);
    } catch (_) {
      // Fallback ke default settings jika jaringan offline / belum diset
      state = AsyncValue.data(UserSettingsModel.defaultSettings());
    }
  }

  Future<void> toggleBiometric(bool enabled) async {
    final current = state.value ?? UserSettingsModel.defaultSettings();
    final updated = current.copyWith(biometricEnabled: enabled);
    state = AsyncValue.data(updated);

    try {
      final saved = await _repository.updateUserSettings(biometricEnabled: enabled);
      state = AsyncValue.data(saved);
    } catch (_) {
      // Tetap gunakan state lokal
    }
  }

  Future<void> toggleShakeRefresh(bool enabled) async {
    final current = state.value ?? UserSettingsModel.defaultSettings();
    final updated = current.copyWith(shakeRefreshEnabled: enabled);
    state = AsyncValue.data(updated);

    try {
      final saved = await _repository.updateUserSettings(shakeRefreshEnabled: enabled);
      state = AsyncValue.data(saved);
    } catch (_) {
      // Tetap gunakan state lokal
    }
  }

  Future<void> toggleTilt(bool enabled) async {
    final current = state.value ?? UserSettingsModel.defaultSettings();
    final updated = current.copyWith(tiltEnabled: enabled);
    state = AsyncValue.data(updated);

    try {
      final saved = await _repository.updateUserSettings(tiltEnabled: enabled);
      state = AsyncValue.data(saved);
    } catch (_) {
      // Tetap gunakan state lokal
    }
  }
}

final sensorSettingsProvider = StateNotifierProvider<SensorSettingsNotifier, AsyncValue<UserSettingsModel>>((ref) {
  final repo = ref.watch(sensorRepositoryProvider);
  return SensorSettingsNotifier(repo);
});
