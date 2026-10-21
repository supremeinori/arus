import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/analytics/presentation/leaderboard_screen.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/dashboard/presentation/dashboard_screen.dart';
import 'package:arus/features/pos/domain/pos_models.dart';
import 'package:arus/features/pos/presentation/pos_catalog_provider.dart';
import 'package:arus/features/pos/presentation/pos_history_screen.dart';

void main() {
  group('Leaderboard Menu Terlaris & Riwayat Transaksi (Dashboard)', () {
    const sampleLeaderboard = [
      TopSellingProductModel(
        rank: 1,
        productId: 'p-1',
        productName: 'Kopi Susu Gula Aren',
        categoryName: 'Coffee',
        quantitySold: 45,
        totalRevenueIdr: 900000,
        unitPriceIdr: 20000,
      ),
      TopSellingProductModel(
        rank: 2,
        productId: 'p-2',
        productName: 'Matcha Latte Oatmilk',
        categoryName: 'Non-Coffee',
        quantitySold: 28,
        totalRevenueIdr: 784000,
        unitPriceIdr: 28000,
      ),
      TopSellingProductModel(
        rank: 3,
        productId: 'p-3',
        productName: 'Croissant Butter',
        categoryName: 'Bakery',
        quantitySold: 19,
        totalRevenueIdr: 475000,
        unitPriceIdr: 25000,
      ),
    ];

    const sampleKpi = AnalyticsOverviewModel(
      revenueIdr: 2500000,
      subtotalIdr: 2500000,
      discountIdr: 0,
      transactionCount: 50,
      avgBasketSizeIdr: 50000,
    );

    testWidgets('Dashboard menampilkan 3 menu terlaris dari API leaderboard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-lb',
        name: 'Rina Owner',
        email: 'owner.lb@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
            analyticsOverviewProvider.overrideWith((ref) async => sampleKpi),
            salesTrendProvider.overrideWith((ref) async => const <SalesTrendPoint>[]),
            leaderboardProvider.overrideWith((ref) async => sampleLeaderboard),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Nama menu + jumlah terjual berasal dari data leaderboard, bukan katalog.
      expect(find.text('Kopi Susu Gula Aren'), findsOneWidget);
      expect(find.text('45 terjual'), findsOneWidget);
      expect(find.text('Matcha Latte Oatmilk'), findsOneWidget);
      expect(find.text('28 terjual'), findsOneWidget);
      // Badge peringkat memakai rank dari backend.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('LeaderboardScreen menampilkan peringkat, jumlah terjual, dan omzet', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-lb2',
        name: 'Rina Owner',
        email: 'owner.lb2@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
          OutletSummary(id: 'out-2', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
            leaderboardProvider.overrideWith((ref) async => sampleLeaderboard),
          ],
          child: const MaterialApp(
            home: LeaderboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Menu Terlaris'), findsOneWidget);
      expect(find.text('Kopi Susu Gula Aren'), findsOneWidget);
      expect(find.text('45 terjual'), findsOneWidget);
      expect(find.text('Matcha Latte Oatmilk'), findsOneWidget);
      expect(find.text('Croissant Butter'), findsOneWidget);
      // Badge peringkat lengkap.
      expect(find.text('#3'), findsOneWidget);
    });

    testWidgets('LeaderboardScreen untuk Manager TIDAK punya filter cabang', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const managerUser = UserModel(
        id: 'u-mgr-lb',
        name: 'Doni Manager',
        email: 'doni.lb@arus.demo',
        role: UserRole.manager,
        outlets: [
          OutletSummary(id: 'out-mgr', name: 'Kopi Arus - Cikini', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(managerUser))),
            leaderboardProvider.overrideWith((ref) async => sampleLeaderboard),
          ],
          child: const MaterialApp(
            home: LeaderboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Label cabang terkunci ke cabang manager.
      expect(find.textContaining('Di "Kopi Arus - Cikini" pada "Hari Ini".'), findsOneWidget);

      // Buka sheet filter: hanya periode waktu, tanpa pilihan cabang.
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Periode Waktu'), findsOneWidget);
      expect(find.text('PILIH CABANG OUTLET'), findsNothing);
      expect(find.text('Semua Cabang'), findsNothing);
      expect(find.text('PILIH HARI / PERIODE'), findsOneWidget);
    });

    testWidgets('PosHistoryScreen mode dashboard menampilkan baris filter cabang & periode', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-hist',
        name: 'Rina Owner',
        email: 'owner.hist@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
        ],
      );

      final sampleTx = [
        PosTransactionModel(
          id: 'tx-1',
          receiptNo: 'INV-20261021-0001',
          outletId: 'out-1',
          outletName: 'Kopi Arus - Sudirman',
          cashierName: 'Kasir',
          subtotalIdr: 45000,
          discountIdr: 0,
          totalIdr: 45000,
          paymentMethod: 'cash',
          paidIdr: 50000,
          changeIdr: 5000,
          status: 'completed',
          createdAt: DateTime(2026, 10, 21, 10, 30),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
            dashboardHistoryProvider.overrideWith((ref) async => sampleTx),
          ],
          child: const MaterialApp(
            home: PosHistoryScreen(useDashboardFilters: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.textContaining('Di "Semua Cabang" pada "Hari Ini".'), findsOneWidget);
      expect(find.text('Ubah'), findsOneWidget);
      expect(find.text('INV-20261021-0001'), findsOneWidget);
    });

    testWidgets('PosHistoryScreen mode POS tidak menampilkan baris filter dashboard', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const staffUser = UserModel(
        id: 'u-staff-hist',
        name: 'Kasir Budi',
        email: 'kasir.hist@arus.demo',
        role: UserRole.staff,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(staffUser))),
            posHistoryProvider.overrideWith((ref) async => const <PosTransactionModel>[]),
          ],
          child: const MaterialApp(
            home: PosHistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Ubah'), findsNothing);
      expect(find.text('Belum ada transaksi pada periode ini.'), findsOneWidget);
    });

    testWidgets('LeaderboardScreen untuk Owner punya filter cabang', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-lb3',
        name: 'Rina Owner',
        email: 'owner.lb3@arus.demo',
        role: UserRole.owner,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Kopi Arus - Sudirman', timezone: 'Asia/Jakarta'),
          OutletSummary(id: 'out-2', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
            leaderboardProvider.overrideWith((ref) async => sampleLeaderboard),
          ],
          child: const MaterialApp(
            home: LeaderboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Leaderboard Menu'), findsOneWidget);
      expect(find.text('PILIH CABANG OUTLET'), findsOneWidget);
      expect(find.text('Semua Cabang'), findsOneWidget);
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
  Future<void> applyDisplayCurrency(String currency) async {}

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
