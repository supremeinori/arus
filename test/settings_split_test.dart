import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/profile/presentation/profile_screen.dart';
import 'package:arus/features/settings/domain/currency_models.dart';
import 'package:arus/features/settings/presentation/currency_provider.dart';
import 'package:arus/features/settings/presentation/currency_settings_screen.dart';
import 'package:arus/features/settings/presentation/time_settings_screen.dart';

class _MockAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
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
}

/// Override sederhana untuk [displayCurrencyProvider] di unit test.
class _MockDisplayCurrencyNotifier extends DisplayCurrencyNotifier {
  final String _fixedCurrency;
  _MockDisplayCurrencyNotifier(this._fixedCurrency);

  @override
  String build() => _fixedCurrency;

  @override
  Future<void> setCurrency(String currency) async {
    state = currency;
  }
}

void main() {
  const mockRates = CurrencyRateModel(
    base: 'IDR',
    asOf: '2026-10-06',
    rates: {'USD': 0.000062, 'EUR': 0.000058},
  );

  group('Pemisahan Widget Pengaturan Kurs & Waktu', () {
    testWidgets(
      'CurrencySettingsScreen hanya menampilkan domain kurs',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              fxRatesProvider.overrideWith((ref) async => mockRates),
            ],
            child: const MaterialApp(home: CurrencySettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Hasil pengaturan kurs
        expect(find.text('Pengaturan Kurs'), findsOneWidget);
        expect(find.text('Mata Uang Tampilan (Multi-Currency)'), findsOneWidget);
        expect(find.text('Rupiah Indonesia (IDR)'), findsOneWidget);
        expect(find.text('Dolar Amerika Serikat (USD)'), findsOneWidget);
        expect(find.text('Euro Uni Eropa (EUR)'), findsOneWidget);
        expect(find.text('Kalkulator Konversi Nominal'), findsOneWidget);
        expect(find.textContaining('Pratinjau Omzet Toko'), findsOneWidget);

        // Domain waktu tidak boleh ikut di layar kurs
        expect(find.text('Zona Waktu Operasional'), findsNothing);
        expect(find.text('WIB — Waktu Indonesia Barat'), findsNothing);
      },
    );

    testWidgets(
      'TimeSettingsScreen hanya menampilkan domain waktu',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: TimeSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Hasil pengaturan waktu
        expect(find.text('Pengaturan Waktu'), findsOneWidget);
        expect(find.text('Zona Waktu Operasional'), findsOneWidget);
        expect(find.text('WIB — Waktu Indonesia Barat'), findsOneWidget);
        expect(find.text('WITA — Waktu Indonesia Tengah'), findsOneWidget);
        expect(find.text('WIT — Waktu Indonesia Timur'), findsOneWidget);
        expect(find.text('BST/GMT — London United Kingdom'), findsOneWidget);
        expect(
          find.textContaining('Jam Operasional Saat Ini'),
          findsOneWidget,
        );

        // Domain kurs tidak boleh ikut di layar waktu
        expect(find.text('Mata Uang Tampilan (Multi-Currency)'), findsNothing);
        expect(find.text('Rupiah Indonesia (IDR)'), findsNothing);
        expect(find.text('Kalkulator Konversi Nominal'), findsNothing);
      },
    );

    testWidgets(
      'ProfileScreen memisahkan tile Kurs dan Waktu beserta hasil aktifnya',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const testUser = UserModel(
          id: 'u-owner-1',
          name: 'Ahmad Owner',
          email: 'ahmad@arus.id',
          role: UserRole.owner,
          avatarUrl: null,
          settings: UserSettingsSummary(biometricEnabled: false),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                (ref) => _MockAuthNotifier(AuthState.authenticated(testUser)),
              ),
              displayCurrencyProvider.overrideWith(() => _MockDisplayCurrencyNotifier('USD')),
              displayTimezoneProvider.overrideWith((ref) => 'Asia/Makassar'),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Dua widget terpisah, bukan satu tile gabungan
        expect(find.text('Pengaturan Kurs'), findsOneWidget);
        expect(find.text('Pengaturan Waktu'), findsOneWidget);
        expect(find.text('Pengaturan Kurs & Waktu'), findsNothing);

        // Hasil pengaturan aktif tiap domain tampil di tile masing-masing
        expect(find.text('USD'), findsOneWidget);
        expect(find.text('WITA'), findsOneWidget);
      },
    );
  });
}
