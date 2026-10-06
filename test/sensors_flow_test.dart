import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arus/features/sensors/domain/sensor_models.dart';
import 'package:arus/features/sensors/data/sensor_repository.dart';
import 'package:arus/features/sensors/presentation/sensor_provider.dart';
import 'package:arus/features/sensors/presentation/sensor_test_screen.dart';

class FakeSensorRepository implements SensorRepository {
  UserSettingsModel _settings = UserSettingsModel.defaultSettings(userId: 'u-test');

  @override
  Future<UserSettingsModel> getUserSettings() async {
    return _settings;
  }

  @override
  Future<UserSettingsModel> updateUserSettings({
    bool? biometricEnabled,
    bool? shakeRefreshEnabled,
    bool? tiltEnabled,
    String? displayCurrency,
    String? displayTimezone,
  }) async {
    _settings = _settings.copyWith(
      biometricEnabled: biometricEnabled,
      shakeRefreshEnabled: shakeRefreshEnabled,
      tiltEnabled: tiltEnabled,
      displayCurrency: displayCurrency,
      displayTimezone: displayTimezone,
    );
    return _settings;
  }
}

void main() {
  group('Sensors & Biometrics Unit & Flow Tests (Milestone 14)', () {
    test('T-SENS-U01: Perhitungan magnitudo akselerometer dan pembaruan giroskop akurat', () {
      final reading = AccelerometerReading(
        x: 3.0,
        y: 4.0,
        z: 0.0,
        timestamp: DateTime(2026, 10, 6),
      );

      // sqrt(3^2 + 4^2 + 0^2) = sqrt(9 + 16) = 5.0
      expect(reading.totalAcceleration, 5.0);

      final gyro = GyroscopeReading.zero();
      expect(gyro.pitch, 0.0);
      expect(gyro.roll, 0.0);

      final tilted = gyro.copyWith(pitch: 15.0, roll: -10.0);
      expect(tilted.pitch, 15.0);
      expect(tilted.roll, -10.0);
    });

    test('T-SENS-U02: ShakeEventNotifier merespons saat aktif dan mengabaikan saat nonaktif', () async {
      final fakeRepo = FakeSensorRepository();
      final container = ProviderContainer(
        overrides: [
          sensorRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      // Wait for settings to load
      await container.read(sensorSettingsProvider.notifier).loadSettings();

      // Trigger shake saat shakeRefreshEnabled = true
      container.read(shakeEventProvider.notifier).triggerShake();
      expect(container.read(shakeEventProvider), isNotNull);

      // Matikan shake refresh
      await container.read(sensorSettingsProvider.notifier).toggleShakeRefresh(false);
      container.read(shakeEventProvider.notifier).reset();
      expect(container.read(shakeEventProvider), isNull);

      // Trigger shake saat nonaktif -> tetap null
      container.read(shakeEventProvider.notifier).triggerShake();
      expect(container.read(shakeEventProvider), isNull);
    });

    testWidgets('T-SENS-W01: SensorTestScreen menampilkan seluruh gauge diagnostik & simulasi biometrik', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeSensorRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sensorRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SensorTestScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan judul dan seksi utama tampil
      expect(find.text('Diagnostik Sensor & Biometrik'), findsOneWidget);
      expect(find.text('Status Sensor Hardware ARUS'), findsOneWidget);
      expect(find.text('Telemetri Akselerometer (G-Force)'), findsOneWidget);
      expect(find.text('Giroskop & Level Kemiringan (Tilt)'), findsOneWidget);
      expect(find.text('Diagnostik Guncangan (Shake-to-Refresh)'), findsOneWidget);
      expect(find.text('Diagnostik Autentikasi Biometrik'), findsOneWidget);

      // Uji tombol simulasi guncangan
      final shakeBtn = find.text('Simulasikan Guncangan (Shake Device)');
      expect(shakeBtn, findsOneWidget);
      await tester.tap(shakeBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Guncangan Terdeteksi'), findsOneWidget);

      // Uji modal biometrik sidik jari (Simulasi Berhasil)
      final fingerprintBtn = find.text('Uji Sidik Jari');
      expect(fingerprintBtn, findsOneWidget);
      await tester.tap(fingerprintBtn);
      await tester.pumpAndSettle();

      expect(find.text('Autentikasi Sidik Jari'), findsOneWidget);
      final successBtn = find.text('Simulasi Berhasil');
      expect(successBtn, findsOneWidget);
      await tester.tap(successBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Autentikasi Sidik Jari Berhasil!'), findsOneWidget);

      // Uji modal biometrik Face ID (Simulasi Gagal)
      final faceBtn = find.text('Uji Face ID');
      expect(faceBtn, findsOneWidget);
      await tester.tap(faceBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pemindaian Wajah (Face ID)'), findsOneWidget);
      final failBtn = find.text('Simulasi Gagal');
      expect(failBtn, findsOneWidget);
      await tester.tap(failBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Autentikasi Gagal:'), findsOneWidget);
    });
  });
}
