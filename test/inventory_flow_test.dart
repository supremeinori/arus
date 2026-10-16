import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/catalog/presentation/catalog_provider.dart';
import 'package:arus/features/inventory/domain/inventory_models.dart';
import 'package:arus/features/inventory/presentation/inventory_list_screen.dart';
import 'package:arus/features/inventory/presentation/inventory_provider.dart';
import 'package:arus/features/outlets/domain/outlet_models.dart';
import 'package:arus/features/outlets/presentation/outlets_provider.dart';
import 'package:arus/features/sensors/presentation/sensor_provider.dart';

class AuthNotifierMock extends StateNotifier<AuthState> implements AuthNotifier {
  AuthNotifierMock(super.initialState);

  @override
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {}

  @override
  Future<bool> login(String email, String password) async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<void> setShakeRefreshEnabled(bool enabled) async {}

  @override
  Future<void> setTiltEnabled(bool enabled) async {}

  @override
  Future<void> setShakeThreshold(double threshold) async {}

  @override
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {}
}

class MockShakeEventNotifier extends StateNotifier<DateTime?> implements ShakeEventNotifier {
  MockShakeEventNotifier() : super(null);

  @override
  void reset() {}

  @override
  void triggerManualShake() {}

  @override
  void triggerShake() {}
}

void main() {
  group('Inventory Flow Widget Tests (Modul 2 Refactor)', () {
    testWidgets('InventoryListScreen untuk Staff menampilkan stok dan estimasi porsi menu', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff',
        name: 'Siti Staff',
        email: 'siti@arus.com',
        role: UserRole.staff,
      );

      const sampleProduct = ProductModel(
        id: 'prod-1',
        sku: 'KOP-01',
        name: 'Kopi Susu Senja',
        unit: 'cup',
        priceIdr: 18000,
        estimatedPortions: 3,
        categoryName: 'Kopi',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(staffUser))),
            productListProvider.overrideWith((ref) async => [sampleProduct]),
            shakeEventProvider.overrideWith((ref) => MockShakeEventNotifier()),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Stok & Estimasi Porsi'), findsOneWidget);
      expect(find.text('Kopi Susu Senja'), findsOneWidget);
      expect(find.text('3 Porsi'), findsOneWidget);
      expect(find.text('Tambah Bahan'), findsNothing);
    });

    testWidgets('InventoryListScreen untuk Owner menampilkan Bahan Baku cabang dan modal HPP', (tester) async {
      const ownerUser = UserModel(
        id: 'u-owner',
        name: 'Budi Owner',
        email: 'budi@arus.com',
        role: UserRole.owner,
      );

      final sampleIngredient = IngredientModel(
        id: 'ing-1',
        outletId: 'out-1',
        outletName: 'Outlet Tebet',
        name: 'Biji Kopi Arabika',
        unit: 'gram',
        stockQty: 500,
        reorderLevel: 100,
        costPerUnit: 150,
        status: 'ok',
        updatedAt: DateTime.now(),
      );

      final sampleOutlet = OutletModel(
        id: 'out-1',
        name: 'Outlet Tebet',
        address: 'Jl. Tebet Raya',
        latitude: -6.2,
        longitude: 106.8,
        timezone: 'Asia/Jakarta',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(ownerUser))),
            outletsListProvider.overrideWith((ref) async => [sampleOutlet]),
            selectedInventoryOutletProvider.overrideWith((ref) => 'out-1'),
            ingredientsListProvider.overrideWith((ref) async => [sampleIngredient]),
            shakeEventProvider.overrideWith((ref) => MockShakeEventNotifier()),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bahan Baku & Inventaris'), findsOneWidget);
      expect(find.text('Biji Kopi Arabika'), findsOneWidget);
      expect(find.textContaining('500 gram'), findsOneWidget);
      expect(find.textContaining('Rp 150 / gram'), findsOneWidget);
      expect(find.text('Tambah Bahan'), findsOneWidget);
    });
  });
}
