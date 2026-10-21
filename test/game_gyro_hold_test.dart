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

/// Repository game palsu: tanpa jaringan, 2 soal dengan 4 opsi.
/// Jawaban benar soal 1 = 'opt_1' (opsi A) agar miring ATAS = jawaban benar.
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
        GameQuestionOption(key: 'opt_3', label: 'Kopi Hitam', value: 'Kopi Hitam'),
        GameQuestionOption(key: 'opt_4', label: 'Matcha Latte', value: 'Matcha Latte'),
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
  group('Gyroscope Hold-to-Answer - Unit Tests', () {
    test('T-GYRO-U01: Empat arah miring terdeteksi dan dipetakan ke huruf A/B/C/D', () {
      // Miring ATAS: ujung atas menjauh pengguna -> pitch positif.
      expect(detectTiltDirection(pitch: 45, roll: 0), TiltDirection.up);
      // Miring KANAN: tepi kanan turun -> roll positif.
      expect(detectTiltDirection(pitch: 0, roll: 45), TiltDirection.right);
      // Miring KIRI: tepi kiri turun -> roll negatif.
      expect(detectTiltDirection(pitch: 0, roll: -45), TiltDirection.left);
      // Miring BAWAH: ujung atas ke pengguna -> pitch negatif.
      expect(detectTiltDirection(pitch: -45, roll: 0), TiltDirection.down);

      expect(TiltDirection.up.letter, 'A');
      expect(TiltDirection.right.letter, 'B');
      expect(TiltDirection.left.letter, 'C');
      expect(TiltDirection.down.letter, 'D');
      expect(TiltDirection.up.optionIndex, 0);
      expect(TiltDirection.down.optionIndex, 3);
    });

    test('T-GYRO-U02: Posisi netral, sudut kecil, dan HP tidak portret tidak memicu arah', () {
      // HP dipegang tegak portrait = netral.
      expect(detectTiltDirection(pitch: 0, roll: 0), isNull);
      // Getaran kecil di bawah ambang 30 derajat.
      expect(detectTiltDirection(pitch: 8, roll: -6), isNull);
      expect(detectTiltDirection(pitch: -12, roll: 10), isNull);
      // HP landscape (roll -90) / HP rebah datar (pitch -90) -> tidak valid.
      expect(detectTiltDirection(pitch: 0, roll: -90), isNull);
      expect(detectTiltDirection(pitch: -90, roll: 0), isNull);
    });

    test('T-GYRO-U03: Miring diagonal yang nyaris sama dianggap ambigu', () {
      // 40 derajat kanan vs 35 derajat atas -> ambigu, tidak ada jawaban dipicu.
      expect(detectTiltDirection(pitch: 35, roll: 40), isNull);
      // 50 derajat kanan vs 25 derajat atas -> sumbu dominan menang.
      expect(detectTiltDirection(pitch: 25, roll: 50), TiltDirection.right);
    });

    test('T-GYRO-U04: Toleransi menjaga arah aktif saat sudut turun sedikit', () {
      // Sudut 22 derajat masih di atas ambang toleransi (30 - 10) -> arah aktif bertahan.
      expect(
        detectTiltDirection(pitch: 22, roll: 0, activeDirection: TiltDirection.up),
        TiltDirection.up,
      );
      // Sudut 15 derajat sudah di bawah toleransi -> tahan dibatalkan.
      expect(
        detectTiltDirection(pitch: 15, roll: 0, activeDirection: TiltDirection.up),
        isNull,
      );
    });

    test('T-GYRO-U05: Tahan 3 detik mengunci jawaban dan tidak bisa terkunci dua kali', () {
      final tracker = TiltHoldTracker();
      final t0 = DateTime(2026, 10, 21, 10, 0, 0);

      // Durasi default tetap 3 detik (aturan main).
      expect(tracker.holdDuration, const Duration(seconds: 3));

      // Awal: belum ada arah.
      expect(tracker.direction, isNull);
      expect(tracker.update(detected: null, now: t0), isFalse);
      expect(tracker.progressAt(t0), 0.0);

      // Mulai tahan arah atas.
      expect(tracker.update(detected: TiltDirection.up, now: t0), isTrue);
      expect(tracker.direction, TiltDirection.up);
      expect(tracker.isLocked, isFalse);

      // Progres berjalan seiring waktu.
      expect(
        tracker.update(detected: TiltDirection.up, now: t0.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(tracker.progressAt(t0.add(const Duration(seconds: 1))), closeTo(1 / 3, 0.001));

      // Belum 3 detik -> belum terkunci.
      expect(
        tracker.update(detected: TiltDirection.up, now: t0.add(const Duration(milliseconds: 2990))),
        isFalse,
      );
      expect(tracker.isLocked, isFalse);

      // Lewat 3 detik -> terkunci.
      expect(
        tracker.update(detected: TiltDirection.up, now: t0.add(const Duration(seconds: 3))),
        isTrue,
      );
      expect(tracker.isLocked, isTrue);
      expect(tracker.lockedDirection, TiltDirection.up);
      expect(tracker.progressAt(t0.add(const Duration(seconds: 3))), 1.0);

      // Sampel lanjutan setelah terkunci diabaikan (cegah jawaban ganda).
      expect(
        tracker.update(detected: TiltDirection.left, now: t0.add(const Duration(seconds: 4))),
        isFalse,
      );
      expect(tracker.lockedDirection, TiltDirection.up);
    });

    test('T-GYRO-U06: Perubahan arah mereset progres, posisi netral membatalkan tahan', () {
      final tracker = TiltHoldTracker();
      final t0 = DateTime(2026, 10, 21, 10, 0, 0);

      tracker.update(detected: TiltDirection.up, now: t0);
      tracker.update(detected: TiltDirection.up, now: t0.add(const Duration(seconds: 2)));
      expect(tracker.progressAt(t0.add(const Duration(seconds: 2))), closeTo(2 / 3, 0.001));

      // Ganti arah -> progres reset ke 0 dan timer diulang.
      expect(
        tracker.update(
            detected: TiltDirection.right, now: t0.add(const Duration(seconds: 2, milliseconds: 100))),
        isTrue,
      );
      expect(tracker.direction, TiltDirection.right);
      expect(tracker.progressAt(t0.add(const Duration(seconds: 2, milliseconds: 100))), 0.0);
      expect(tracker.isLocked, isFalse);

      // Kembali netral -> tahan dibatalkan.
      expect(
        tracker.update(detected: null, now: t0.add(const Duration(seconds: 3))),
        isTrue,
      );
      expect(tracker.direction, isNull);
      expect(tracker.progressAt(t0.add(const Duration(seconds: 3))), 0.0);
      expect(tracker.isLocked, isFalse);

      // Reset total (ganti soal / selesai).
      tracker.update(detected: TiltDirection.down, now: t0);
      tracker.reset();
      expect(tracker.direction, isNull);
      expect(tracker.isLocked, isFalse);
      expect(tracker.lockedDirection, isNull);
    });
  });

  group('Gyroscope Hold-to-Answer - Widget Tests', () {
    /// Render game pada mode "Tebak Nama Menu".
    ///
    /// [clock] diinjeksikan ke [GameHomeScreen] sebagai sumber waktu logika
    /// tahan. Dengan begitu durasi tahan 3 detik bisa diverifikasi tanpa
    /// menunggu jam dinding (deterministik & cepat).
    Future<ProviderContainer> pumpGame(
      WidgetTester tester, {
      DateTime Function()? clock,
    }) async {
      // Layar phone tinggi supaya seluruh konten (header + panel + 4 tombol) muat.
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

    testWidgets('T-GYRO-W01: Tahan miring 3 detik mengunci jawaban dan menambah skor',
        (tester) async {
      // Jam simulasi untuk logika tahan (tidak menunggu jam dinding).
      var now = DateTime.now();
      final container = await pumpGame(tester, clock: () => now);

      // Pastikan sudah di playing view.
      expect(find.textContaining('Soal 1 dari'), findsOneWidget);
      expect(find.text('0 Poin'), findsOneWidget);

      // Miring ke ATAS (pitch positif) -> pilihan A.
      container.read(gyroscopeProvider.notifier).setTilt(pitch: 45, roll: 0);
      await tester.pump(const Duration(milliseconds: 50));

      // Panel menampilkan arah yang sedang ditahan.
      expect(find.textContaining('Tahan: Atas (A)'), findsOneWidget);

      // Tahan 3 detik. Perangkat nyata mengirim sampel sensor terus-menerus,
      // jadi simulasi juga mengirim sampel baru di setiap langkah.
      for (var step = 1; step <= 40; step++) {
        now = now.add(const Duration(milliseconds: 100));
        container.read(gyroscopeProvider.notifier).setTilt(pitch: 45, roll: 0);
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Jawaban terkunci lewat gyroscope').evaluate().isNotEmpty) {
          break;
        }
      }

      // Jawaban terkunci lewat gyroscope.
      expect(find.textContaining('Jawaban terkunci lewat gyroscope'), findsOneWidget);
      // Skor: 100 + sisa waktu (10 - 3 detik terpakai) x 10 = 170 Poin.
      expect(find.text('170 Poin'), findsOneWidget);

      // Ganti soal: status gyro harus di-reset.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Soal 2 dari'), findsOneWidget);
      expect(find.textContaining('Jawaban terkunci lewat gyroscope'), findsNothing);

      // Netralkan kemiringan -> tahan dibatalkan, panel kembali ke legenda.
      container.read(gyroscopeProvider.notifier).setTilt(pitch: 0, roll: 0);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Miringkan HP & tahan 3 detik untuk menjawab'), findsOneWidget);
      expect(find.textContaining('Tahan:'), findsNothing);
    });

    testWidgets('T-GYRO-W02: Kontrol sentuh tetap berfungsi tanpa data sensor', (tester) async {
      await pumpGame(tester);

      // Tanpa sampel sensor, panel menampilkan status inisialisasi sensor.
      expect(find.textContaining('Mengaktifkan sensor gyroscope'), findsOneWidget);

      // Touch fallback: tekan pilihan A (jawaban benar untuk soal 1).
      await tester.tap(find.text('Kopi Susu'));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('200 Poin'), findsOneWidget);

      // Habiskan jeda antar soal (1,2 detik) supaya tidak ada timer menggantung.
      await tester.pump(const Duration(milliseconds: 1300));
    });

    testWidgets(
        'T-GYRO-W03: Sensor tanpa data ditandai tidak tersedia dan tombol sentuh tetap jalan',
        (tester) async {
      await pumpGame(tester);

      // Tidak ada sampel sensor sama sekali -> setelah ~2,5 detik polling
      // status sensor berubah menjadi "tidak tersedia".
      for (var step = 0; step < 40; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.textContaining('Sensor tidak tersedia').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('Sensor tidak tersedia'), findsOneWidget);
      expect(find.textContaining('Gunakan tombol jawaban'), findsOneWidget);

      // Fallback sentuh tetap berfungsi: tekan pilihan A (jawaban benar).
      await tester.tap(find.text('Kopi Susu'));
      await tester.pump(const Duration(milliseconds: 50));

      // Skor naik (jawaban benar), bukan 0 Poin.
      expect(find.text('0 Poin'), findsNothing);
      final scoreLabel = tester.widget<Text>(find.textContaining('Poin').first).data!;
      expect(int.parse(scoreLabel.split(' ').first), greaterThan(100));

      // Habiskan jeda antar soal (1,2 detik) supaya tidak ada timer menggantung.
      await tester.pump(const Duration(milliseconds: 1300));
    });
  });
}
