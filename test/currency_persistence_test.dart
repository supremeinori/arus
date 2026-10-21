import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arus/core/auth/biometric_service.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/storage/prefs_store.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/core/utils/money_formatter.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/domain/auth_response.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/settings/domain/currency_models.dart';
import 'package:arus/features/settings/presentation/currency_provider.dart';
import 'package:arus/shared/widgets/app_widgets.dart';

/// Adapter HTTP yang merekam request PATCH ke backend.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  final List<String> methods = [];
  final List<Map<String, dynamic>> bodies = [];
  bool failNext = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    methods.add(options.method);
    final raw = options.data;
    bodies.add(
      raw is Map<String, dynamic>
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'raw': raw?.toString()},
    );

    if (failNext) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'gagal menyimpan'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {
          'display_currency': (bodies.last['display_currency'] ?? 'IDR'),
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSecureStore extends Fake implements SecureStore {
  final Map<String, String> written = {};

  @override
  Future<String?> getAccessToken() async => 'test-token';

  @override
  Future<String?> getRefreshToken() async => 'test-refresh-token';

  @override
  Future<bool> isSessionExpired() async => false;

  @override
  Future<bool> isBiometricEnabled() async => false;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
    bool? biometricEnabled,
  }) async {
    written['user_json'] = userJson;
  }

  @override
  Future<void> setUserJson(String value) async {
    written['user_json'] = value;
  }
}

class _FakeLocalDb extends Fake implements LocalDatabase {
  final Map<String, String> sessions = {};
  final Map<String, String> currencies = {};

  @override
  Future<void> saveUserSession({
    required UserModel user,
    required String accessToken,
    String? refreshToken,
  }) async {
    sessions[user.id] = jsonEncode(user.toJson());
  }

  @override
  Future<void> updateDisplayCurrencySetting(String userId, String currency) async {
    currencies[userId] = currency;
  }

  @override
  Future<LocalSessionSettings?> getSessionSettings(String userId) async => null;

  @override
  Future<LocalSessionSettings?> getLatestSessionSettings() async => null;

  @override
  Future<UserModel?> getCachedUser() async => null;

  @override
  Future<void> clearSession([String? userId]) async {
    sessions.clear();
  }
}

class _FakeBiometricService extends Fake implements BiometricService {
  @override
  Future<bool> authenticate({String localizedReason = ''}) async => true;
}

/// Auth notifier mock untuk simulasi pergantian akun.
class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.initialState);

  @override
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {}

  @override
  Future<void> logout() async {
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

UserModel _user({
  required String id,
  String currency = 'IDR',
}) {
  return UserModel(
    id: id,
    name: 'User $id',
    email: '$id@arus.demo',
    role: UserRole.owner,
    settings: UserSettingsSummary(displayCurrency: currency),
  );
}

const CurrencyRateModel _rates = CurrencyRateModel(
  base: 'IDR',
  asOf: '2026-10-20',
  rates: {
    'IDR': 1,
    'USD': 0.000062,
    'EUR': 0.000058,
    'SGD': 0.0000833,
    'JPY': 0.00943,
    'MYR': 0.00028,
    'GBP': 0.000049,
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Penyimpanan & persistensi mata uang', () {
    test(
      'T-CUR-FLT-01: memilih mata uang menyimpan ke User.display_currency lewat API dan state langsung berubah',
      () async {
        final adapter = _RecordingAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
          ..httpClientAdapter = adapter;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(_FakeSecureStore()),
            localDbProvider.overrideWithValue(_FakeLocalDb()),
            apiClientProvider.overrideWithValue(
              ApiClient(secureStore: _FakeSecureStore(), customDio: dio),
            ),
            fxRatesProvider.overrideWith((ref) async => _rates),
            authProvider.overrideWith(
              (ref) => _MockAuthNotifier(
                AuthState.authenticated(_user(id: 'user-a')),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(displayCurrencyProvider), 'IDR');

        final ok = await container
            .read(displayCurrencyProvider.notifier)
            .setCurrency('USD');

        expect(ok, isTrue, reason: 'penyimpanan ke backend harus berhasil');
        expect(
          container.read(displayCurrencyProvider),
          'USD',
          reason: 'state Riverpod harus langsung berubah tanpa reload',
        );

        // Permintaan benar-benar dikirim ke backend
        expect(adapter.methods, contains('PATCH'));
        expect(adapter.paths, contains('/users/me/settings'));
        final body = adapter.bodies.firstWhere(
          (b) => b.containsKey('display_currency'),
        );
        expect(body['display_currency'], 'USD');
      },
    );

    test(
      'T-CUR-FLT-02: bila backend gagal, state dikembalikan ke nilai sebelumnya',
      () async {
        final adapter = _RecordingAdapter()..failNext = true;
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5000/api'))
          ..httpClientAdapter = adapter;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(_FakeSecureStore()),
            localDbProvider.overrideWithValue(_FakeLocalDb()),
            apiClientProvider.overrideWithValue(
              ApiClient(secureStore: _FakeSecureStore(), customDio: dio),
            ),
            fxRatesProvider.overrideWith((ref) async => _rates),
            authProvider.overrideWith(
              (ref) => _MockAuthNotifier(
                AuthState.authenticated(_user(id: 'user-a')),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final ok = await container
            .read(displayCurrencyProvider.notifier)
            .setCurrency('EUR');

        expect(ok, isFalse, reason: 'gagal menyimpan harus dilaporkan');
        expect(
          container.read(displayCurrencyProvider),
          'IDR',
          reason: 'state harus balik ke nilai sebelumnya',
        );
      },
    );

    test(
      'T-CUR-FLT-03: preferensi antar akun tidak tercampur',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = PrefsStore(prefs);

        await store.setDisplayCurrencyFor('user-a', 'USD');
        await store.setDisplayCurrencyFor('user-b', 'EUR');

        expect(store.displayCurrencyFor('user-a'), 'USD');
        expect(store.displayCurrencyFor('user-b'), 'EUR');

        // Ganti akun pada perangkat yang sama -> nilai ikut berganti
        final notifier = _MockAuthNotifier(
          AuthState.authenticated(_user(id: 'user-a', currency: 'USD')),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(_FakeSecureStore()),
            localDbProvider.overrideWithValue(_FakeLocalDb()),
            fxRatesProvider.overrideWith((ref) async => _rates),
            authProvider.overrideWith((ref) => notifier),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(displayCurrencyProvider), 'USD');

        notifier.state = AuthState.authenticated(
          _user(id: 'user-b', currency: 'EUR'),
        );
        container.listen(displayCurrencyProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(displayCurrencyProvider),
          'EUR',
          reason: 'akun berikutnya tidak boleh memakai preferensi akun lain',
        );
      },
    );

    test(
      'T-CUR-FLT-04: preferensi dari server dipakai saat login (persistensi antar sesi)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStoreProvider.overrideWithValue(_FakeSecureStore()),
            localDbProvider.overrideWithValue(_FakeLocalDb()),
            biometricServiceProvider.overrideWithValue(_FakeBiometricService()),
            fxRatesProvider.overrideWith((ref) async => _rates),
            authRepositoryProvider.overrideWith(
              (ref) => _FakeAuthRepository(
                _user(id: 'user-a', currency: 'SGD'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final loggedIn = await container
            .read(authProvider.notifier)
            .login('user-a@arus.demo', 'password123');

        expect(loggedIn, isTrue);
        expect(
          container.read(authProvider).user?.settings.displayCurrency,
          'SGD',
        );
        expect(
          container.read(displayCurrencyProvider),
          'SGD',
          reason: 'pilihan dari database harus langsung dipakai setelah login',
        );
      },
    );

    testWidgets(
      'T-CUR-FLT-05: nominal di seluruh halaman mengikuti mata uang terpilih',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              secureStoreProvider.overrideWithValue(_FakeSecureStore()),
              localDbProvider.overrideWithValue(_FakeLocalDb()),
              fxRatesProvider.overrideWith((ref) async => _rates),
              displayCurrencyProvider.overrideWith(
                () => _MockDisplayCurrencyNotifier('USD'),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    MoneyText(100000),
                    MoneyText(2500000),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 100.000 IDR -> $6.20 ; 2.500.000 IDR -> $155.00
        expect(find.textContaining('6.20'), findsOneWidget);
        expect(find.textContaining('155.00'), findsOneWidget);
        expect(find.textContaining('Rp'), findsNothing);
      },
    );
  });

  group('Formatter terpusat', () {
    test('MoneyFormatter memakai kurs live dan fallback', () {
      expect(MoneyFormatter.format(100000, currency: 'IDR'), contains('100.000'));
      expect(
        MoneyFormatter.format(100000, currency: 'USD', rates: const {'USD': 0.000062}),
        contains('6.20'),
      );
      expect(
        MoneyFormatter.format(100000, currency: 'EUR', rates: const {'EUR': 0.000058}),
        contains('5,80'),
      );
      // Tanpa kurs live -> memakai fallback terpusat
      expect(
        MoneyFormatter.format(100000, currency: 'USD'),
        contains('5.59'),
      );
      // Nominal IDR tidak pernah berubah
      expect(
        MoneyFormatter.format(100000, currency: 'USD', rates: const {'USD': 0.000062}),
        isNot(contains('100.000')),
      );
    });
  });
}

/// Auth repository palsu: login selalu sukses dengan preferensi tertentu.
class _FakeAuthRepository extends AuthRepository {
  final UserModel _user;

  _FakeAuthRepository(this._user) : super(_unusedClient);

  static final ApiClient _unusedClient = ApiClient(
    secureStore: _FakeSecureStore(),
  );

  @override
  Future<AuthResponse> login(String email, String password) async {
    return AuthResponse(
      accessToken: 'access',
      refreshToken: 'refresh',
      expiresIn: 900,
      user: _user,
    );
  }
}

/// Notifier display currency untuk widget test.
class _MockDisplayCurrencyNotifier extends DisplayCurrencyNotifier {
  final String _fixedCurrency;

  _MockDisplayCurrencyNotifier(this._fixedCurrency);

  @override
  String build() => _fixedCurrency;

  @override
  Future<bool> setCurrency(String currency) async {
    state = currency;
    return true;
  }
}
