import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
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
            productListProvider.overrideWith((ref) async => [sampleProduct]),
          ],
          child: const MaterialApp(
            home: PosScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Es Kopi Susu Senja'), findsOneWidget);
      expect(find.textContaining('Rp 18.000'), findsOneWidget);

      // Sebelum diklik, bar keranjang bawah belum muncul
      expect(find.text('Checkout'), findsNothing);

      // Tap produk untuk menambahkan ke keranjang
      await tester.tap(find.text('Es Kopi Susu Senja'));
      await tester.pumpAndSettle();

      // Sekarang bar checkout muncul dengan 1 item
      expect(find.text('1 Item Terpilih'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
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
