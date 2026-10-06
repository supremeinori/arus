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

      expect(find.text('Halo, Rina Owner'), findsOneWidget);
      expect(find.text('Total Omset'), findsOneWidget);
      expect(find.textContaining('Rp 2.500.000'), findsOneWidget);
      expect(find.text('50'), findsOneWidget); // Transaksi
      expect(find.textContaining('Rp 50.000'), findsOneWidget); // Basket size

      // Owner melihat estimasi margin
      expect(find.textContaining('Estimasi Margin (60%)'), findsOneWidget);
      expect(find.textContaining('Rp 1.500.000'), findsOneWidget);
    });
  });
}

class AuthNotifierMock extends StateNotifier<AuthState> implements AuthNotifier {
  AuthNotifierMock(super.initialState);

  @override
  Future<void> checkAuth() async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<void> logout() async {}
}
