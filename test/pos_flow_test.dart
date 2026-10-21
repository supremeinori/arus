import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/pos/data/pos_catalog_repository.dart';
import 'package:arus/features/pos/presentation/pos_catalog_provider.dart';
import 'package:arus/features/pos/presentation/pos_screen.dart';

void main() {
  group('POS & Checkout Flow Widget Tests (Milestone 6)', () {
    const sampleProduct = ProductModel(
      id: 'prod-1',
      sku: 'KOP-01',
      name: 'Es Kopi Susu Senja',
      unit: 'cup',
      priceIdr: 18000,
      categoryName: 'Kopi',
      estimatedPortions: 25,
    );

    const catalogItem = PosCatalogItem(
      product: sampleProduct,
      isAvailable: true,
      maxPortions: 25,
    );

    testWidgets('PosScreen menampilkan produk katalog dan menambahkan item ke keranjang saat diklik', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff',
        name: 'Siti Kasir',
        email: 'staff@arus.demo',
        role: UserRole.staff,
        outlets: [
          OutletSummary(id: 'out-1', name: 'Outlet Tebet', timezone: 'Asia/Jakarta'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifierMock(AuthState.authenticated(staffUser));
              return notifier;
            }),
            categoriesProvider.overrideWith((ref) async => [
                  const CategoryModel(id: 'cat-1', name: 'Kopi', productCount: 1),
                ]),
            // PosScreen membaca posCatalogProvider (katalog kasir online),
            // bukan productListProvider — override yang benar agar grid tampil
            // tanpa jaringan/sqlite.
            posCatalogProvider.overrideWith((ref) async => [catalogItem]),
          ],
          child: const MaterialApp(
            home: PosScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Es Kopi Susu Senja'), findsOneWidget);
      expect(find.textContaining('Rp 18.000'), findsOneWidget);

      // Bottom bar SELALU tampil (anti hit-test crash): sebelum ada item,
      // tombol Checkout disabled dan ada hint.
      expect(find.text('Ketuk menu untuk menambah'), findsOneWidget);
      final checkoutBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Checkout'),
      );
      expect(checkoutBtn.onPressed, isNull);

      // Tap produk untuk menambahkan ke keranjang
      await tester.tap(find.text('Es Kopi Susu Senja'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sekarang bar checkout aktif dengan 1 item
      expect(find.text('1 Item Terpilih'), findsOneWidget);
      final checkoutBtnAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Checkout'),
      );
      expect(checkoutBtnAfter.onPressed, isNotNull);
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
