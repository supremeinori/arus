import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/operations/presentation/manager_menu_screen.dart';
import 'package:arus/features/operations/presentation/operations_hub_screen.dart';
import 'package:arus/features/pos/data/pos_catalog_repository.dart';
import 'package:arus/features/pos/presentation/pos_catalog_provider.dart';

import 'helpers/test_font_assets.dart';
import 'pos_flow_test.dart';

void main() {
  group('Manager Menu & Estimasi Profit Flow Widget Tests', () {
    setUpAll(() {
      enableGoogleFontsInTests();
    });

    const managerUser = UserModel(
      id: 'u-manager',
      name: 'Budi Manager',
      email: 'manager@arus.demo',
      role: UserRole.manager,
      outlets: [
        OutletSummary(id: 'out-1', name: 'Outlet Senopati', timezone: 'Asia/Jakarta'),
      ],
    );

    const ownerUser = UserModel(
      id: 'u-owner',
      name: 'Dewi Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
      outlets: [
        OutletSummary(id: 'out-1', name: 'Outlet Senopati', timezone: 'Asia/Jakarta'),
      ],
    );

    const sampleProduct = ProductModel(
      id: 'prod-1',
      sku: 'KOP-01',
      name: 'Kopi Susu Senopati',
      unit: 'cup',
      priceIdr: 20000,
      costIdr: 8000, // HPP nyata
      categoryName: 'Kopi',
      estimatedPortions: 30,
    );

    const catalogItem = PosCatalogItem(
      product: sampleProduct,
      isAvailable: true,
      maxPortions: 30,
    );

    testWidgets('OperationsHubScreen menampilkan tile Menu untuk Manager', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(managerUser))),
          ],
          child: const MaterialApp(home: OperationsHubScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menu'), findsOneWidget);
      expect(find.text('Daftar menu & estimasi profit'), findsOneWidget);
      expect(find.text('Kelola menu & harga'), findsNothing);
    });

    testWidgets('OperationsHubScreen menampilkan tile Produk untuk Owner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
          ],
          child: const MaterialApp(home: OperationsHubScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Produk'), findsOneWidget);
      expect(find.text('Kelola menu & harga'), findsOneWidget);
      expect(find.text('Daftar menu & estimasi profit'), findsNothing);
    });

    testWidgets('ManagerMenuScreen menampilkan UI menu dengan estimasi profit dan detail read-only',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(managerUser))),
            categoriesProvider.overrideWith((ref) async => [
                  const CategoryModel(id: 'cat-1', name: 'Kopi', productCount: 1),
                ]),
            posCatalogProvider.overrideWith((ref) async => [catalogItem]),
          ],
          child: const MaterialApp(home: ManagerMenuScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Header & Subtitle
      expect(find.text('Menu & Estimasi Profit'), findsOneWidget);
      expect(find.textContaining('Outlet Senopati • Mode Tinjauan (Read-Only)'), findsOneWidget);

      // Summary Banner KPI
      expect(find.text('Menu Tersedia'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('Rata-rata Margin'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Potensi Profit'), findsOneWidget);

      // Kartu Produk
      expect(find.text('Kopi Susu Senopati'), findsOneWidget);
      expect(find.text('Estimasi: 30 Porsi'), findsOneWidget);
      expect(find.textContaining('Rp 20.000'), findsOneWidget);
      // Badge Profit: 20.000 - 8.000 = 12.000 (60%)
      expect(find.textContaining('Profit: Rp 12.000 (60%)'), findsOneWidget);

      // Ketuk kartu untuk membuka BottomSheet Detail Analisis Profit
      await tester.tap(find.text('Kopi Susu Senopati'));
      await tester.pumpAndSettle();

      // Verifikasi isi BottomSheet
      expect(find.text('Analisis Harga & Estimasi Profit'), findsOneWidget);
      expect(find.text('Harga Jual Konsumen'), findsOneWidget);
      expect(find.text('HPP / Modal Resep'), findsOneWidget);
      expect(find.text('Estimasi Profit per Porsi'), findsOneWidget);
      expect(find.textContaining('Mode Manager: Tinjauan menu & profit bersifat read-only'), findsOneWidget);
    });
  });
}
