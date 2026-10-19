import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  group('Analytics & Dashboard Flow Widget Tests (Milestone 7)', () {
    const sampleKpi = AnalyticsOverviewModel(
      revenueIdr: 2500000,
      subtotalIdr: 2500000,
      discountIdr: 0,
      transactionCount: 50,
      avgBasketSizeIdr: 50000,
      totalCostIdr: 1000000,
      grossProfitIdr: 1500000,
      grossMarginPct: 60,
    );

    const sampleTrend = [
      SalesTrendPoint(date: '2026-10-01', revenueIdr: 300000, count: 6),
      SalesTrendPoint(date: '2026-10-02', revenueIdr: 450000, count: 9),
    ];

    testWidgets('DashboardScreen menampilkan kartu metrik KPI dan estimasi margin untuk Owner', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner',
        name: 'Rina Owner',
        email: 'owner@arus.demo',
        role: UserRole.owner,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifierMock(AuthState.authenticated(ownerUser));
              return notifier;
            }),
            analyticsOverviewProvider.overrideWith((ref) async => sampleKpi),
            salesTrendProvider.overrideWith((ref) async => sampleTrend),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Arus'), findsOneWidget);
      expect(find.text('Omzet'), findsOneWidget);
      expect(find.text('Rp.2.500.000'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      expect(find.text('Lihat riwayat'), findsOneWidget);
      expect(find.text('Masalah'), findsOneWidget);
      expect(find.text('Lihat Masalah'), findsOneWidget);

      // Verifikasi Teks Dinamis Cabang & Periode Hari
      expect(find.textContaining('Di "Semua Cabang" pada "Hari Ini".'), findsOneWidget);

      // Verifikasi Seluruh Section Sesuai Wireframe
      expect(find.text('Terlaris'), findsOneWidget);
      expect(find.text('Tren'), findsOneWidget);
      expect(find.text('Peringatan'), findsOneWidget);
      expect(find.text('Lihat Semua'), findsWidgets);
    });

    testWidgets('DashboardScreen memungkinkan Owner memilih cabang dan filter hari', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const multiOutletOwner = UserModel(
        id: 'u-owner-multi',
        name: 'Pak Budi',
        email: 'budi@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
          OutletSummary(id: 'out-2', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta'),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(multiOutletOwner))),
          analyticsOverviewProvider.overrideWith((ref) async => sampleKpi),
          salesTrendProvider.overrideWith((ref) async => sampleTrend),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Default label text
      expect(find.textContaining('Di "Semua Cabang" pada "Hari Ini".'), findsOneWidget);
      expect(container.read(selectedOutletFilterProvider), isNull);

      // Buka kotak filter via icon filter
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();

      // Kotak filter terbuka
      expect(find.text('Kotak Filter Bisnis'), findsOneWidget);
      expect(find.text('Terapkan Filter'), findsOneWidget);

      // Buka dropdown cabang dan pilih Senopati
      await tester.tap(find.text('Semua Cabang').last);
      await tester.pumpAndSettle();
      expect(find.text('Kopi Arus - Senopati').last, findsOneWidget);
      await tester.tap(find.text('Kopi Arus - Senopati').last);
      await tester.pumpAndSettle();

      // Pilih hari 'Kemarin'
      await tester.tap(find.text('Kemarin').last);
      await tester.pumpAndSettle();

      // Terapkan filter
      await tester.tap(find.text('Terapkan Filter'));
      await tester.pumpAndSettle();

      // State provider outlet dan date filter berubah
      expect(container.read(selectedOutletFilterProvider), 'out-2');
      expect(container.read(selectedDateFilterProvider), DashboardDateFilter.yesterday);
      expect(find.textContaining('Di "Kopi Arus - Senopati" pada "Kemarin".'), findsOneWidget);
    });

    testWidgets('DashboardScreen tidak mengalami RenderFlex overflow pada viewport sempit (mobile)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longOutletOwner = UserModel(
        id: 'u-owner-long',
        name: 'Pak Budi',
        email: 'budi@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(
            id: 'out-long',
            name: 'Kopi Arus - Cabang Sangat Panjang Sekali Sudirman HQ Mall Grand Indonesia',
            timezone: 'Asia/Jakarta',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(longOutletOwner))),
          analyticsOverviewProvider.overrideWith((ref) async => sampleKpi),
          salesTrendProvider.overrideWith((ref) async => sampleTrend),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pilih cabang panjang
      await tester.tap(find.text('Semua Cabang'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Kopi Arus - Cabang Sangat Panjang').last);
      await tester.pumpAndSettle();

      // Tidak ada overflow dan kartu utama tetap ter-render
      expect(find.text('Omzet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class AuthNotifierMock extends StateNotifier<AuthState> implements AuthNotifier {
  AuthNotifierMock(super.initialState);

  @override
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {}

  @override
  Future<void> logout() async {}

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
