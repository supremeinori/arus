import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/presentation/login_screen.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';
import 'package:arus/features/shell/presentation/main_shell.dart';

void main() {
  group('Auth & Role Shell Widget Tests (Milestone 3)', () {
    testWidgets('LoginScreen menampilkan form, tombol masuk, dan quick-fill chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.textContaining('Masuk ke ARUS'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email & Password
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Kasir'), findsOneWidget);

      // Tap chip Kasir
      await tester.tap(find.text('Kasir'));
      await tester.pump();

      expect(find.text('staff@arus.demo'), findsOneWidget);
    });

    testWidgets('MainShell untuk Staff menampilkan 4 tab (Beranda, Kasir, Stok, Lainnya)', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff',
        name: 'Siti Kasir',
        email: 'staff@arus.demo',
        role: UserRole.staff,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(staffUser);
              return notifier;
            }),
            inventoryListProvider.overrideWith((ref) async => []),
            categoriesProvider.overrideWith((ref) async => []),
            productListProvider.overrideWith((ref) async => []),
            shiftSummaryProvider.overrideWith((ref) async => const ShiftSummaryModel(
                  todayRevenueIdr: 0,
                  cashRevenueIdr: 0,
                  qrisRevenueIdr: 0,
                  transactionCount: 0,
                )),
          ],
          child: const MaterialApp(
            home: MainShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Kasir'), findsOneWidget);
      expect(find.text('Stok'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);

      // Pastikan tab khusus Owner/Manager (Operasi, AI, Analitik) TIDAK muncul
      expect(find.text('Operasi'), findsNothing);
      expect(find.text('AI'), findsNothing);
      expect(find.text('Analitik'), findsNothing);
    });

    testWidgets('MainShell untuk Owner menampilkan 5 tab (Beranda, Operasi, AI, Analitik, Lainnya)', (tester) async {
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
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(ownerUser);
              return notifier;
            }),
            analyticsOverviewProvider.overrideWith((ref) async => const AnalyticsOverviewModel(
                  revenueIdr: 0,
                  subtotalIdr: 0,
                  discountIdr: 0,
                  transactionCount: 0,
                  avgBasketSizeIdr: 0,
                )),
            salesTrendProvider.overrideWith((ref) async => []),
            peakHoursProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: MainShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "Beranda" ada di BottomNav label (judul Beranda berulang dihilangkan sesuai spesifikasi Anti-AI-Slop)
      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Operasi'), findsOneWidget);
      expect(find.text('Analitik'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
      // AI Companion Floating Action Button
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
