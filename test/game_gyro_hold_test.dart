import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/game/data/game_repository.dart';
import 'package:arus/features/game/domain/tilt_direction.dart';
import 'package:arus/features/game/presentation/game_home_screen.dart';
import 'package:arus/features/sensors/data/sensor_repository.dart';
import 'package:arus/features/sensors/domain/sensor_models.dart';
import 'package:arus/features/sensors/presentation/sensor_provider.dart';

import 'helpers/test_font_assets.dart';

// ============================================================
// FAKE REPOSITORY
// ============================================================

/// Repository game palsu: tanpa jaringan, 2 soal dengan 2 opsi (Kiri & Kanan).
/// Jawaban benar soal 1 & 2 = 'opt_1' (opsi Kiri) agar miring KIRI = jawaban benar.
class FakeGameRepository implements GameRepository {
  @override
  Future<List<GameQuestionModel>> fetchQuestions({
    required String mode,
    int limit = 5,
  }) async {
    return [
      _buildQuestion(1, 'opt_1'),
      _buildQuestion(2, 'opt_1'),
    ];
  }

  GameQuestionModel _buildQuestion(int no, String correctKey) {
    return GameQuestionModel(
      questionNo: no,
      productId: 'p$no',
      imageUrl: 'https://example.com/menu$no.jpg',
      categoryName: 'Minuman',
      promptTitle: 'Menu apakah yang ada pada gambar di atas?',
      options: [
        GameQuestionOption(key: 'opt_1', label: 'Kopi Susu', value: 'Kopi Susu'),
        GameQuestionOption(key: 'opt_2', label: 'Es Teh', value: 'Es Teh'),
      ],
      correctOptionKey: correctKey,
    );
  }

  @override
  Future<Map<String, dynamic>> submitSession({
    required String mode,
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int durationSec,
  }) async {
    return {'is_new_high_score': false};
  }

  @override
  Future<UserGameStats> fetchUserStats() async {
    return UserGameStats(
      bestGuessName: 0,
      bestGuessPrice: 0,
      totalGamesPlayed: 0,
      recentSessions: const [],
    );
  }
}

/// Repository sensor palsu: mencegah pemanggilan jaringan saat test.
class FakeSensorRepository implements SensorRepository {
  UserSettingsModel _settings = UserSettingsModel.defaultSettings(userId: 'u-test');

  @override
  Future<UserSettingsModel> getUserSettings() async => _settings;

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
  group('2-Way Gyroscope & Instant Trigger - Unit Tests', () {
    test('T-GYRO-U01: Miring Kiri & Miring Kanan terdeteksi dari sudut roll', () {
      // Posisi Netral
      expect(detect2WayTilt(roll: 0), isNull);
      expect(detect2WayTilt(roll: 12), isNull);
      expect(detect2WayTilt(roll: -12), isNull);

      // Miring KIRI (roll <= -22)
      expect(detect2WayTilt(roll: -30), Tilt2WayDirection.left);
      expect(Tilt2WayDirection.left.letter, 'A');
      expect(Tilt2WayDirection.left.optionIndex, 0);

      // Miring KANAN (roll >= 22)
      expect(detect2WayTilt(roll: 30), Tilt2WayDirection.right);
      expect(Tilt2WayDirection.right.letter, 'B');
      expect(Tilt2WayDirection.right.optionIndex, 1);
    });

    test('T-GYRO-U02: TiltInstantTrigger merespon instan tanpa delay 3 detik & mendebounce', () {
      final trigger = TiltInstantTrigger(threshold: 22.0);

      // Miring Kiri -> Picu instan
      final triggered = trigger.update(roll: -35);
      expect(triggered, Tilt2WayDirection.left);
      expect(trigger.isTriggered, isTrue);

      // Sampel berikutnya didebounce (tidak memicu ulang)
      expect(trigger.update(roll: -40), isNull);
      expect(trigger.update(roll: 35), isNull);

      // Reset untuk soal berikutnya
      trigger.reset();
      expect(trigger.isTriggered, isFalse);

      // Miring Kanan pada soal baru -> Picu instan Kanan
      expect(trigger.update(roll: 35), Tilt2WayDirection.right);
      expect(trigger.isTriggered, isTrue);
    });
  });

  group('2-Way Gyroscope & Combo - Widget Tests', () {
    Future<ProviderContainer> pumpGame(
      WidgetTester tester, {
      DateTime Function()? clock,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      enableGoogleFontsInTests();

      final container = ProviderContainer(
        overrides: [
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          sensorRepositoryProvider.overrideWithValue(FakeSensorRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: GameHomeScreen(clock: clock)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Masuk ke mode "Tebak Nama Menu".
      await tester.tap(find.text('Mode 1: Tebak Nama Menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return container;
    }

    testWidgets('T-GYRO-W01: Miring Kiri memilih jawaban seketika (instan) dan menambah skor',
        (tester) async {
      final container = await pumpGame(tester);

      // Pastikan sudah di playing view.
      expect(find.textContaining('Soal 1 dari'), findsOneWidget);
      expect(find.text('0 Poin'), findsOneWidget);

      // Miring ke KIRI (roll negatif) -> pilihan A (Kopi Susu).
      container.read(gyroscopeProvider.notifier).setTilt(pitch: 0, roll: -35);
      await tester.pump(const Duration(milliseconds: 50));

      // Jawaban terverifikasi seketika (instan), skor bertambah (100 dasar + sisa waktu x 10)
      expect(find.textContaining('Poin'), findsWidgets);
      final scoreFinder = find.textContaining('Poin').first;
      final scoreText = tester.widget<Text>(scoreFinder).data!;
      final scoreVal = int.parse(scoreText.split(' ').first);
      expect(scoreVal, greaterThan(150));

      // Habiskan jeda transisi antar soal
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Soal 2 dari'), findsOneWidget);

      // Soal 2: Miring Kiri lagi -> Jawaban benar kedua memicu COMBO 2X!
      container.read(gyroscopeProvider.notifier).setTilt(pitch: 0, roll: -35);
      await tester.pump(const Duration(milliseconds: 50));

      // Banner combo beruntun muncul di layar
      expect(find.textContaining('COMBO 2X'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
    });

    testWidgets('T-GYRO-W02: Kontrol sentuh tetap berfungsi mulus tanpa data sensor',
        (tester) async {
      await pumpGame(tester);

      // Touch fallback: tekan tombol pilihan A ("Kopi Susu")
      await tester.tap(find.text('Kopi Susu'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('200 Poin'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
    });

    testWidgets(
        'T-GYRO-W03: Sensor tanpa data ditandai tidak tersedia dan tombol sentuh tetap jalan',
        (tester) async {
      await pumpGame(tester);

      // Tunggu hingga deteksi sensor tidak tersedia
      for (var step = 0; step < 40; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Sensor tidak tersedia').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('Sensor tidak tersedia'), findsOneWidget);
      expect(find.textContaining('Gunakan tombol sentuh'), findsOneWidget);

      // Fallback sentuh tetap berfungsi
      await tester.tap(find.text('Kopi Susu'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('0 Poin'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1300));
    });
  });
}
