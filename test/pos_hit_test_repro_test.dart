import 'package:flutter/gestures.dart';
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

class AuthNotifierMock extends StateNotifier<AuthState>
    implements AuthNotifier {
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

void main() {
  testWidgets(
      'REPRO tap pertama menu kasir tidak boleh lempar hit-test error',
      (tester) async {
    const sampleProduct = ProductModel(
      id: 'prod-1',
      sku: 'KOP-01',
      name: 'Es Kopi Susu Senja',
      unit: 'cup',
      priceIdr: 18000,
      categoryName: 'Kopi',
      imageUrl: '/images/kopi.png', // path relatif seeder (bukan URL valid)
      estimatedPortions: 25,
    );
    const item = PosCatalogItem(
      product: sampleProduct,
      isAvailable: true,
      maxPortions: 25,
    );
    const staffUser = UserModel(
      id: 'u-staff',
      name: 'Siti Kasir',
      email: 'staff@arus.demo',
      role: UserRole.staff,
      outlets: [
        OutletSummary(
            id: 'out-1', name: 'Outlet Tebet', timezone: 'Asia/Jakarta'),
      ],
    );

    final errors = <FlutterErrorDetails>[];
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d);
    addTearDown(() => FlutterError.onError = oldHandler);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
              (ref) => AuthNotifierMock(AuthState.authenticated(staffUser))),
          categoriesProvider.overrideWith((ref) async => [
                const CategoryModel(id: 'cat-1', name: 'Kopi', productCount: 1),
              ]),
          // Override langsung: tanpa jaringan, tanpa sqlite.
          posCatalogProvider.overrideWith((ref) async => [item]),
        ],
        child: const MaterialApp(home: PosScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Es Kopi Susu Senja'), findsOneWidget);

    // Simulasi mouse desktop hover persis sebelum tap (jalur MouseTracker).
    final center = tester.getCenter(find.text('Es Kopi Susu Senja'));
    final mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.moveTo(center);
    await tester.pump();

    await tester.tap(find.text('Es Kopi Susu Senja'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final hitTestErrors = errors
        .where((e) =>
            e.toString().contains('Cannot hit test a render box') ||
            e.toString().contains('mouse_tracker'))
        .toList();
    expect(hitTestErrors, isEmpty,
        reason: 'Hit-test crash muncul: $hitTestErrors');
    expect(find.text('1 Item Terpilih'), findsOneWidget);
  });
}
