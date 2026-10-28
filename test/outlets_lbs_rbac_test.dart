import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/core/routing/app_router.dart';
import 'package:arus/features/outlets/data/outlets_repository.dart';
import 'package:arus/features/outlets/domain/outlet_models.dart';
import 'package:arus/features/outlets/presentation/outlets_provider.dart';
import 'package:arus/features/outlets/presentation/outlet_detail_screen.dart';
import 'package:arus/features/outlets/presentation/outlet_form_screen.dart';
import 'package:arus/features/outlets/presentation/widgets/outlet_map_widget.dart';

class FakeOutletsRepository implements OutletsRepository {
  bool deactivateCalled = false;
  String? lastDeactivatedId;

  @override
  Future<List<OutletModel>> getOutlets() async => [];

  @override
  Future<OutletModel> getOutletById(String id) async {
    return OutletModel(
      id: id,
      name: 'ARUS Cabang Uji',
      address: 'Jl. Uji Coba No. 1',
      latitude: -7.7828,
      longitude: 110.3670,
      timezone: 'Asia/Jakarta',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<OutletPerformanceModel>> getPerformance() async => [];

  @override
  Future<NearestOutletResult> getNearestOutlet(double lat, double lng) async {
    return const NearestOutletResult();
  }

  @override
  Future<OutletModel> createOutlet({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async {
    return OutletModel(
      id: 'out-new',
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<OutletModel> updateOutlet(
    String id, {
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? timezone,
    bool? isActive,
  }) async {
    return OutletModel(
      id: id,
      name: name ?? 'ARUS Cabang Uji',
      address: address ?? 'Jl. Uji Coba',
      latitude: latitude ?? -7.7828,
      longitude: 110.3670,
      timezone: timezone ?? 'Asia/Jakarta',
      isActive: isActive ?? true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<OutletModel> deactivateOutlet(String id) async {
    deactivateCalled = true;
    lastDeactivatedId = id;
    return OutletModel(
      id: id,
      name: 'ARUS Cabang Uji',
      address: 'Jl. Uji Coba',
      latitude: -7.7828,
      longitude: 110.3670,
      timezone: 'Asia/Jakarta',
      isActive: false,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  group('LBS Distance & Calculation Unit Tests', () {
    test('calculateStraightDistanceMeters dan estimateRoadDistanceMeters berfungsi akurat', () {
      final straight = calculateStraightDistanceMeters(-7.7829, 110.3671, -7.7928, 110.3658);
      expect(straight, greaterThan(900));
      expect(straight, lessThan(1300));

      final road = estimateRoadDistanceMeters(straight);
      expect(road, greaterThan(straight));
      expect(road, closeTo(straight * 1.35, 0.01));

      expect(formatDistance(500), '500 m');
      expect(formatDistance(1500), '1.5 km');
      expect(formatDistance(0), '0 m');
    });

    test('Handling koordinat nol (0.0, 0.0) tidak menghasilkan jarak palsu', () {
      final invalidDist = calculateStraightDistanceMeters(0.0, 0.0, -7.7828, 110.3670);
      expect(invalidDist, 0.0);
      expect(formatDistance(invalidDist), '0 m');
    });
  });

  group('Outlet Map & Location Picker Widget Tests', () {
    testWidgets('OutletLocationPickerWidget merender peta dan menampilkan koordinat awal', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: OutletLocationPickerWidget(
                initialLatitude: -7.7828,
                initialLongitude: 110.3670,
                onLocationSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Koordinat Cabang:'), findsOneWidget);
      expect(find.textContaining('-7.7828'), findsOneWidget);
      expect(find.byType(OutletLocationPickerWidget), findsOneWidget);
    });

    testWidgets('OutletFormScreen mengintegrasikan peta interaktif dan preset kota tanpa input manual koordinat', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
          ],
          child: const MaterialApp(
            home: OutletFormScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tambah Cabang Baru'), findsOneWidget);
      expect(find.textContaining('Lokasi Cabang pada Peta *'), findsWidgets);
      expect(find.byType(OutletLocationPickerWidget), findsOneWidget);

      final jakartaChip = find.text('Jakarta');
      expect(jakartaChip, findsOneWidget);
      await tester.tap(jakartaChip);
      await tester.pumpAndSettle();

      expect(find.text('Koordinat Terpilih'), findsOneWidget);
      expect(find.text('Jakarta'), findsOneWidget);
    });
  });

  group('Outlet Detail & Soft Delete RBAC Tests', () {
    const ownerUser = UserModel(
      id: 'u-owner-1',
      name: 'Rina Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
    );

    const managerUser = UserModel(
      id: 'u-mgr-1',
      name: 'Doni Manager',
      email: 'manager@arus.demo',
      role: UserRole.manager,
    );

    final activeOutlet = OutletModel(
      id: 'out-1',
      name: 'ARUS Cabang Sudirman',
      address: 'Jl. Jenderal Sudirman No. 10',
      latitude: -6.2146,
      longitude: 106.8215,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 15,
      assignedUsersCount: 3,
      createdAt: DateTime(2026, 1, 1),
    );

    testWidgets('Owner melihat tombol Edit dan tombol Nonaktifkan Cabang dengan dialog konfirmasi', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeOutletsRepository();

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
            outletDetailProvider('out-1').overrideWith((ref) async => activeOutlet),
            outletsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: OutletDetailScreen(outletId: 'out-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ARUS Cabang Sudirman'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('Nonaktifkan Cabang Ini'), findsOneWidget);
      expect(find.textContaining('Jarak dari Lokasi Anda (GPS):'), findsOneWidget);

      await tester.tap(find.text('Nonaktifkan Cabang Ini'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Penonaktifan Cabang'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Nonaktifkan'), findsOneWidget);

      await tester.tap(find.text('Nonaktifkan'));
      await tester.pumpAndSettle();

      expect(fakeRepo.deactivateCalled, isTrue);
      expect(fakeRepo.lastDeactivatedId, 'out-1');
    });

    testWidgets('Manager TIDAK melihat tombol Edit maupun tombol Nonaktifkan Cabang', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(managerUser);
              return notifier;
            }),
            outletDetailProvider('out-1').overrideWith((ref) async => activeOutlet),
          ],
          child: const MaterialApp(
            home: OutletDetailScreen(outletId: 'out-1'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ARUS Cabang Sudirman'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('Nonaktifkan Cabang Ini'), findsNothing);
      expect(find.text('Aktifkan Kembali Cabang Ini'), findsNothing);
    });
  });

  group('AppRouter RBAC Navigation Guard Tests', () {
    const ownerUser = UserModel(
      id: 'u-owner-1',
      name: 'Rina Owner',
      email: 'owner@arus.demo',
      role: UserRole.owner,
    );

    const managerUser = UserModel(
      id: 'u-mgr-1',
      name: 'Doni Manager',
      email: 'manager@arus.demo',
      role: UserRole.manager,
    );

    testWidgets('Manager dialihkan ke /shell jika mencoba navigasi langsung ke /outlets atau /catalog', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(
              ref.watch(authRepositoryProvider),
              ref.watch(secureStoreProvider),
            );
            notifier.state = AuthState.authenticated(managerUser);
            return notifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      router.go('/outlets');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(router.routeInformationProvider.value.uri.path, '/shell');

      router.go('/catalog');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, '/shell');
    });

    testWidgets('Owner diizinkan mengakses /outlets dan /catalog', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(
              ref.watch(authRepositoryProvider),
              ref.watch(secureStoreProvider),
            );
            notifier.state = AuthState.authenticated(ownerUser);
            return notifier;
          }),
          outletsRepositoryProvider.overrideWithValue(FakeOutletsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      router.go('/outlets');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, '/outlets');
    });
  });
}
