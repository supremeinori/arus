import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/profile/presentation/profile_screen.dart';
import 'package:arus/features/feedback/presentation/feedback_screen.dart';
import 'package:arus/core/storage/local_db.dart';

class FakeApiClient extends Fake implements ApiClient {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: {'status': 'ok', 'data': []} as T,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: {
        'status': 'ok',
        'data': {'id': 'fb-test-01'},
      } as T,
    );
  }
}

class MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  bool toggleBiometricCalled = false;
  bool lastToggleValue = false;
  bool logoutCalled = false;

  MockAuthNotifier(super.initialState);

  @override
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {
    toggleBiometricCalled = true;
    lastToggleValue = enabled;
    final currentUser = state.user;
    if (currentUser != null) {
      final updatedSettings = currentUser.settings.copyWith(biometricEnabled: enabled);
      state = AuthState.authenticated(currentUser.copyWith(settings: updatedSettings));
    }
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = AuthState.unauthenticated();
  }

  @override
  Future<UserModel?> getPersistedUser() async => state.user;

  @override
  void setUnauthenticated([String? message]) {
    state = AuthState.unauthenticated(message);
  }

  @override
  void restoreSessionInstant(UserModel user, [String? refreshToken]) {
    state = AuthState.authenticated(user);
  }

  @override
  Future<void> applyDisplayCurrency(String currency) async {
    final user = state.user;
    if (user == null) return;
    state = AuthState.authenticated(
      user.copyWith(
        settings: user.settings.copyWith(displayCurrency: currency),
      ),
    );
  }
}

void main() {
  group('Phase 1 Blueprint Validation (ARUS_DESAIN_ADDER.md)', () {
    test('T-P1-01: UserModel memuat avatar_url dan pengaturan biometrik dengan benar', () {
      final userMap = {
        'id': 'usr-001',
        'name': 'Budi Santoso',
        'email': 'budi@arus.id',
        'role': 'owner',
        'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
        'settings': {
          'currency': 'IDR',
          'timezone': 'WIB',
          'biometric_enabled': true,
        },
        'outlets': [
          {'id': 'out-1', 'name': 'Cabang Utama'}
        ],
      };

      final user = UserModel.fromJson(userMap);
      expect(user.id, 'usr-001');
      expect(user.avatarUrl, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200');
      expect(user.settings.biometricEnabled, isTrue);

      final copy = user.copyWith(avatarUrl: 'https://new-avatar.png');
      expect(copy.avatarUrl, 'https://new-avatar.png');
      expect(copy.name, 'Budi Santoso');
    });

    test('T-P1-02: LocalSessionSettings SQLite model serializes and deserializes accurately', () {
      const settings = LocalSessionSettings(
        userId: 'u-123',
        name: 'Siti Staff',
        email: 'siti@arus.id',
        role: 'staff',
        avatarUrl: 'https://avatar.test/siti.png',
        biometricEnabled: true,
        displayCurrency: 'USD',
        displayTimezone: 'WIT',
      );

      final map = settings.toMap();
      expect(map['user_id'], 'u-123');
      expect(map['avatar_url'], 'https://avatar.test/siti.png');
      expect(map['biometric_enabled'], 1);
      expect(map['display_currency'], 'USD');
      expect(map['display_timezone'], 'WIT');

      final fromMap = LocalSessionSettings.fromMap(map);
      expect(fromMap.userId, 'u-123');
      expect(fromMap.avatarUrl, 'https://avatar.test/siti.png');
      expect(fromMap.biometricEnabled, isTrue);
      expect(fromMap.displayCurrency, 'USD');
      expect(fromMap.displayTimezone, 'WIT');
    });

    testWidgets('T-P1-03: ProfileScreen menampilkan avatar, pintu pengaturan, navigasi feedback, dan logout', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      const testUser = UserModel(
        id: 'u-owner-1',
        name: 'Ahmad Owner',
        email: 'ahmad@arus.id',
        role: UserRole.owner,
        avatarUrl: null, // Will use letter avatar fallback
        settings: UserSettingsSummary(biometricEnabled: false),
      );

      late MockAuthNotifier authNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              authNotifier = MockAuthNotifier(AuthState.authenticated(testUser));
              return authNotifier;
            }),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Validasi Profil & Inisial Nama
      expect(find.text('Ahmad Owner'), findsOneWidget);
      expect(find.text('ahmad@arus.id'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // Letter avatar initial

      // 2. Kurs, Waktu, dan Sidik Jari sudah dipindah ke layar Pengaturan,
      //    jadi Profil hanya menyisakan satu pintu masuk ke sana.
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Login Sidik Jari (Biometrik)'), findsNothing);
      expect(find.text('Pengaturan Kurs'), findsNothing);
      expect(find.text('Pengaturan Waktu'), findsNothing);

      // 3. Validasi Keberadaan Tombol Saran & Kesan Kuliah PAM
      expect(find.text('Saran & Kesan Kuliah PAM'), findsOneWidget);

      // 4. Validasi Tombol Keluar (Logout)
      expect(find.text('Keluar Akun'), findsOneWidget);
      await tester.tap(find.text('Keluar Akun'));
      await tester.pumpAndSettle();

      // Konfirmasi dialog muncul
      expect(find.text('Keluar dari Akun?'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(authNotifier.logoutCalled, isTrue);
    });

    testWidgets('T-P1-04: FeedbackScreen memvalidasi input & menyimpan data kesan dan saran PAM', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApiClient()),
          ],
          child: const MaterialApp(
            home: FeedbackScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Saran & Kesan Kuliah PAM'), findsOneWidget);
      expect(find.text('Praktikum Aplikasi Mobile (PAM)'), findsOneWidget);

      // Coba simpan saat input kosong -> validasi snackbar muncul
      await tester.tap(find.text('Simpan & Kirim Masukan'));
      await tester.pump();
      expect(find.text('Harap lengkapi kolom Kesan dan Saran.'), findsOneWidget);

      // Isi form Kesan & Saran
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'Mata kuliah PAM sangat bermanfaat dan membuka wawasan arsitektur mobile.');
      await tester.enterText(textFields.at(1), 'Semoga studi kasus offline-first dan cloud sync diperbanyak.');
      await tester.pumpAndSettle();

      // Submit feedback (offline fallback jika backend mock tidak override API)
      await tester.tap(find.text('Simpan & Kirim Masukan'));
      await tester.pumpAndSettle();

      // Verifikasi feedback tersimpan ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pam_feedback_kesan'), 'Mata kuliah PAM sangat bermanfaat dan membuka wawasan arsitektur mobile.');
      expect(prefs.getString('pam_feedback_saran'), 'Semoga studi kasus offline-first dan cloud sync diperbanyak.');
      expect(prefs.getString('pam_feedback_date'), isNotNull);
    });
  });
}
