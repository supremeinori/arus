import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/domain/category_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/catalog/presentation/product_list_screen.dart';

void main() {
  group('Catalog Flow Widget Tests (Milestone 4)', () {
    const sampleProduct = ProductModel(
      id: 'prod-1',
      sku: 'KOP-01',
      name: 'Es Kopi Susu Aren',
      unit: 'cup',
      priceIdr: 22000,
      costIdr: 9000,
      categoryName: 'Kopi',
    );

    testWidgets('Owner melihat daftar produk, HPP, dan tombol Tambah Produk', (tester) async {
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
            categoriesProvider.overrideWith((ref) async => [
                  const CategoryModel(id: 'cat-1', name: 'Kopi', productCount: 1),
                ]),
            productListProvider.overrideWith((ref) async => [sampleProduct]),
          ],
          child: const MaterialApp(
            home: ProductListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Katalog Produk'), findsOneWidget);
      expect(find.text('Es Kopi Susu Aren'), findsOneWidget);
      expect(find.text('KOP-01'), findsOneWidget);
      expect(find.textContaining('Rp 22.000'), findsOneWidget);

      // Owner melihat HPP dan tombol tambah
      expect(find.textContaining('HPP: Rp 9.000'), findsOneWidget);
      expect(find.text('Tambah Produk'), findsOneWidget);
    });

    testWidgets('Staff melihat daftar produk tapi HPP dan tombol Tambah disembunyikan', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff',
        name: 'Siti Kasir',
        email: 'staff@arus.demo',
        role: UserRole.staff,
      );

      // Staff receives product without costIdr
      const staffProduct = ProductModel(
        id: 'prod-1',
        sku: 'KOP-01',
        name: 'Es Kopi Susu Aren',
        unit: 'cup',
        priceIdr: 22000,
        costIdr: null, // Hidden
        categoryName: 'Kopi',
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
            categoriesProvider.overrideWith((ref) async => [
                  const CategoryModel(id: 'cat-1', name: 'Kopi', productCount: 1),
                ]),
            productListProvider.overrideWith((ref) async => [staffProduct]),
          ],
          child: const MaterialApp(
            home: ProductListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Es Kopi Susu Aren'), findsOneWidget);
      expect(find.textContaining('Rp 22.000'), findsOneWidget);

      // Staff TIDAK melihat HPP dan TIDAK melihat tombol tambah
      expect(find.textContaining('HPP:'), findsNothing);
      expect(find.text('Tambah Produk'), findsNothing);
    });
  });
}
