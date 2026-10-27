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
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
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
  Future<bool> authenticateWithBiometric() async => true;

  @override
  Future<void> toggleBiometric(bool enabled) async {}

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

class MockShakeEventNotifier extends StateNotifier<DateTime?> implements ShakeEventNotifier {
  MockShakeEventNotifier() : super(null);

  @override
  void reset() {}

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
            selectedOutletFilterProvider.overrideWith((ref) => 'out-1'),
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
      expect(find.text('Pilih Cabang:'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Biji Kopi Arabika'), findsOneWidget);
      expect(find.textContaining('500 gram'), findsOneWidget);
      expect(find.textContaining('Rp 150 / gram'), findsOneWidget);
      expect(find.text('Tambah Bahan'), findsOneWidget);
    });

    testWidgets('InventoryListScreen untuk Manager TIDAK bisa memilih cabang (terkunci pada cabang penugasan oleh Owner)', (tester) async {
      const managerUser = UserModel(
        id: 'u-mgr-1',
        name: 'Doni Manager',
        email: 'doni@arus.com',
        role: UserRole.manager,
        outlets: [
          OutletSummary(
            id: 'out-jogja-1',
            name: 'ARUS Malioboro',
            timezone: 'Asia/Jakarta',
            address: 'Jl. Malioboro No. 12',
          ),
        ],
      );

      final sampleIngredient = IngredientModel(
        id: 'ing-1',
        outletId: 'out-jogja-1',
        outletName: 'ARUS Malioboro',
        name: 'Biji Kopi House Blend',
        unit: 'gram',
        stockQty: 850,
        reorderLevel: 200,
        costPerUnit: 180,
        status: 'ok',
        updatedAt: DateTime.now(),
      );

      final allOutlets = [
        OutletModel(
          id: 'out-jogja-1',
          name: 'ARUS Malioboro',
          address: 'Jl. Malioboro No. 12',
          latitude: -7.7928,
          longitude: 110.3660,
          timezone: 'Asia/Jakarta',
          isActive: true,
          createdAt: DateTime.now(),
        ),
        OutletModel(
          id: 'out-jogja-2',
          name: 'ARUS Seturan',
          address: 'Jl. Seturan No. 88',
          latitude: -7.7710,
          longitude: 110.4090,
          timezone: 'Asia/Jakarta',
          isActive: true,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(managerUser))),
            outletsListProvider.overrideWith((ref) async => allOutlets),
            ingredientsListProvider.overrideWith((ref) async => [sampleIngredient]),
            shakeEventProvider.overrideWith((ref) => MockShakeEventNotifier()),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Manager TIDAK boleh melihat dropdown 'Pilih Cabang:'
      expect(find.text('Pilih Cabang:'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);

      // 2. Manager melihat indikator cabang ditugaskan yang terkunci
      expect(find.text('Cabang Ditugaskan:'), findsOneWidget);
      expect(find.text('ARUS Malioboro'), findsOneWidget);
      expect(find.text('Terkunci'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // 3. Manager TIDAK dapat melihat cabang lain di selector (misal ARUS Seturan)
      expect(find.text('ARUS Seturan'), findsNothing);

      // 4. Data bahan baku untuk cabang penugasan tetap muncul
      expect(find.text('Biji Kopi House Blend'), findsOneWidget);
      expect(find.textContaining('850 gram'), findsOneWidget);
      expect(find.text('Tambah Bahan'), findsOneWidget);
    });

    testWidgets('InventoryListScreen untuk Manager yang belum di-assign cabang menampilkan pesan peringatan', (tester) async {
      const managerNoOutlet = UserModel(
        id: 'u-mgr-2',
        name: 'Randi Manager',
        email: 'randi@arus.com',
        role: UserRole.manager,
        outlets: [], // Belum di-assign
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => AuthNotifierMock(AuthState.authenticated(managerNoOutlet))),
            outletsListProvider.overrideWith((ref) async => []),
            ingredientsListProvider.overrideWith((ref) async => []),
            shakeEventProvider.overrideWith((ref) => MockShakeEventNotifier()),
          ],
          child: const MaterialApp(
            home: InventoryListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Manager tidak punya dropdown dan melihat pesan bahwa belum ditugaskan oleh Owner
      expect(find.text('Pilih Cabang:'), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('Belum ada cabang yang ditugaskan oleh Owner.'), findsOneWidget);
    });
  });
}
