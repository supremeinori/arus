import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/storage/prefs_store.dart';
import '../domain/sensor_models.dart';
import '../data/sensor_repository.dart';

// Accelerometer state & hardware listener
class AccelerometerNotifier extends StateNotifier<AccelerometerReading> {
  StreamSubscription<AccelerometerEvent>? _sub;

  AccelerometerNotifier() : super(AccelerometerReading.zero()) {
    _startListening();
  }

  void _startListening() {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      _sub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          state = AccelerometerReading(
            x: event.x,
            y: event.y,
            z: event.z,
            timestamp: DateTime.now(),
          );
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

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
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        state = AccelerometerReading.zero();
      }
    });
  }

  void reset() {
    state = AccelerometerReading.zero();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final accelerometerProvider = StateNotifierProvider<AccelerometerNotifier, AccelerometerReading>((ref) {
  return AccelerometerNotifier();
});

// Gyroscope & Tilt state & hardware listener
class GyroscopeNotifier extends StateNotifier<GyroscopeReading> {
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _pitch = 0.0;
  double _roll = 0.0;
  double _yaw = 0.0;

  GyroscopeNotifier() : super(GyroscopeReading.zero()) {
    _startListening();
  }

  void _startListening() {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      // 1. Hitung pitch dan roll fisik dari gravitasi akselerometer secara presisi
      _accelSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          final pitchRad = math.atan2(event.y, math.sqrt(event.x * event.x + event.z * event.z));
          final rollRad = math.atan2(-event.x, event.z);

          _pitch = (pitchRad * 180 / math.pi).clamp(-90.0, 90.0);
          _roll = (rollRad * 180 / math.pi).clamp(-90.0, 90.0);

          state = GyroscopeReading(
            pitch: _pitch,
            roll: _roll,
            yaw: _yaw,
            timestamp: DateTime.now(),
          );
        },
        onError: (_) {},
        cancelOnError: false,
      );

      // 2. Baca rotasi dinamis Giroskop
      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          if (!mounted) return;
          _yaw = (_yaw + (event.z * 180 / math.pi * 0.02)) % 360.0;
          if (_yaw < 0) _yaw += 360.0;
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void setTilt({double? pitch, double? roll, double? yaw}) {
    state = state.copyWith(
      pitch: pitch,
      roll: roll,
      yaw: yaw,
      timestamp: DateTime.now(),
    );
  }

  void reset() {
    _pitch = 0.0;
    _roll = 0.0;
    _yaw = 0.0;
    state = GyroscopeReading.zero();
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }
}

final gyroscopeProvider = StateNotifierProvider<GyroscopeNotifier, GyroscopeReading>((ref) {
  return GyroscopeNotifier();
});

// Tingkat sensitivitas guncangan (Presets)
enum ShakeSensitivityLevel {
  light, // 4.0 m/s² (Sangat sensitif / guncangan ringan)
  normal, // 6.5 m/s² (Sedang / rekomendasi seimbang)
  strong, // 10.0 m/s² (Guncangan kuat / bertenaga)
  heavy, // 14.0 m/s² (Sangat kuat / guncangan keras)
}

extension ShakeSensitivityLevelX on ShakeSensitivityLevel {
  double get threshold {
    switch (this) {
      case ShakeSensitivityLevel.light:
        return 4.0;
      case ShakeSensitivityLevel.normal:
        return 6.5;
      case ShakeSensitivityLevel.strong:
        return 10.0;
      case ShakeSensitivityLevel.heavy:
        return 14.0;
    }
  }

  String get label {
    switch (this) {
      case ShakeSensitivityLevel.light:
        return 'Ringan';
      case ShakeSensitivityLevel.normal:
        return 'Sedang';
      case ShakeSensitivityLevel.strong:
        return 'Kuat';
      case ShakeSensitivityLevel.heavy:
        return 'Sangat Kuat';
    }
  }

  String get description {
    switch (this) {
      case ShakeSensitivityLevel.light:
        return 'Cukup goyangan kecil pergelangan tangan (4.0 m/s²)';
      case ShakeSensitivityLevel.normal:
        return 'Guncangan wajar & nyaman (6.5 m/s² - Standar Disarankan)';
      case ShakeSensitivityLevel.strong:
        return 'Guncangan bertenaga & mantap (10.0 m/s²)';
      case ShakeSensitivityLevel.heavy:
        return 'Hanya guncangan keras / ayunan penuh (14.0 m/s²)';
    }
  }
}

// Notifier ambang batas sensitivitas guncangan dengan persistensi lokal
class ShakeThresholdNotifier extends StateNotifier<double> {
  final PrefsStore? _prefs;

  ShakeThresholdNotifier([this._prefs]) : super(_prefs?.shakeThreshold ?? 6.0);

  void setThreshold(double val) {
    state = val;
    _prefs?.setShakeThreshold(val);
  }

  void setPreset(ShakeSensitivityLevel level) {
    setThreshold(level.threshold);
  }

  @override
  set state(double value) {
    super.state = value;
    _prefs?.setShakeThreshold(value);
  }
}

final shakeThresholdProvider = StateNotifierProvider<ShakeThresholdNotifier, double>((ref) {
  PrefsStore? prefs;
  try {
    prefs = ref.watch(prefsStoreProvider);
  } catch (_) {}
  return ShakeThresholdNotifier(prefs);
});

// Telemetri realtime kekuatan guncangan terakhir yang terbaca (m/s²)
final lastShakeForceProvider = StateProvider<double>((ref) => 0.0);

// Shake event notification stream (emits timestamp on shake)
class ShakeEventNotifier extends StateNotifier<DateTime?> {
  final Ref _ref;
  DateTime? _lastShakeTime;
  StreamSubscription<UserAccelerometerEvent>? _shakeSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  ShakeEventNotifier(this._ref) : super(null) {
    _startListening();
  }

  void _startListening() {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      // 1. Raw accelerometer (guncangan fisik terhadap gravitasi ~9.8 m/s²)
      // Sangat andal di semua jenis hardware Android (termasuk Xiaomi MIUI / HyperOS)
      _accelSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          final totalG = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final delta = (totalG - 9.80665).abs();
          final threshold = _ref.read(shakeThresholdProvider);

          // Update live force telemetry saat ada gerakan dinamis
          if (delta > 1.5) {
            _ref.read(lastShakeForceProvider.notifier).state = delta;
          }

          // Terdeteksi guncangan jika deviasi gravitasi melebihi threshold
          // atau terjadi guncangan kuat (totalG >= 15.5 m/s² atau drop mendadak <= 3.8 m/s²)
          if (delta >= threshold || totalG >= 15.5 || (totalG <= 3.8 && threshold <= 8.0)) {
            triggerShake();
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );

      // 2. Linear user accelerometer (kompensasi gravitasi oleh OS jika didukung)
      _shakeSub = userAccelerometerEventStream().listen(
        (event) {
          if (!mounted) return;
          final magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          final threshold = _ref.read(shakeThresholdProvider);

          if (magnitude > 1.5) {
            _ref.read(lastShakeForceProvider.notifier).state = magnitude;
          }

          if (magnitude >= threshold) {
            triggerShake();
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void triggerShake() {
    final now = DateTime.now();
    // Debounce 1.0 detik agar guncangan fisik tidak memicu banjir refresh
    if (_lastShakeTime != null && now.difference(_lastShakeTime!).inMilliseconds < 1000) {
      return;
    }

    final settings = _ref.read(sensorSettingsProvider).value;
    final isEnabled = settings?.shakeRefreshEnabled ?? true;

    if (isEnabled) {
      _lastShakeTime = now;
      state = now;
      // Berikan getaran haptik fisik sebagai umpan balik instan ke tangan pengguna
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      // Simulasi efek akselerometer
      _ref.read(accelerometerProvider.notifier).simulateShake();
    }
  }

  void reset() {
    state = null;
  }

  @override
  void dispose() {
    _shakeSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
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
