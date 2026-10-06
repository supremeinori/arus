import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/inventory/domain/inventory_models.dart';
import 'package:arus/features/inventory/presentation/inventory_list_screen.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';

void main() {
  group('Inventory Flow Widget Tests (Milestone 5)', () {
    final sampleStock = [
      InventoryStockItem(
        outletId: 'out-1',
        outletName: 'Outlet Tebet',
        productId: 'prod-1',
        sku: 'KOP-01',
        productName: 'Kopi Susu Senja',
        unit: 'cup',
        priceIdr: 18000,
        costIdr: 7000,
        quantity: 3,
        reorderLevel: 5,
        avgLeadTimeDays: 2,
        isLowStock: true,
        updatedAt: DateTime.now(),
      ),
    ];

    testWidgets('InventoryListScreen menampilkan item stok dan badge peringatan menipis', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff',
        name: 'Siti Staff',
        email: 'siti@arus.com',
        role: UserRole.staff,
      );

      final staffStock = [
        InventoryStockItem(
          outletId: 'out-1',
          outletName: 'Outlet Tebet',
          productId: 'prod-1',
          sku: 'KOP-01',
          productName: 'Kopi Susu Senja',
          unit: 'cup',
          priceIdr: 18000,
          costIdr: null, // Staff disembunyikan
          quantity: 3,
          reorderLevel: 5,
          avgLeadTimeDays: 2,
          isLowStock: true,
          updatedAt: DateTime.now(),
        ),
      ];

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
            inventoryListProvider.overrideWith((ref) async => staffStock),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cek apakah produk dan badge stok muncul
      expect(find.text('Kopi Susu Senja'), findsOneWidget);
      expect(find.textContaining('3 cup'), findsOneWidget);
      expect(find.text('Stok di bawah batas minimum (5 cup)'), findsOneWidget);
      expect(find.text('Opname'), findsOneWidget);

      // Staff tidak boleh melihat HPP (cost_idr)
      expect(find.textContaining('HPP:'), findsNothing);
    });

    testWidgets('InventoryListScreen untuk Owner menampilkan HPP produk', (tester) async {
      const ownerUser = UserModel(
        id: 'u-owner',
        name: 'Budi Owner',
        email: 'budi@arus.com',
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
            inventoryListProvider.overrideWith((ref) async => sampleStock),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kopi Susu Senja'), findsOneWidget);
      expect(find.textContaining('HPP: Rp 7.000'), findsOneWidget);
    });
  });
}
