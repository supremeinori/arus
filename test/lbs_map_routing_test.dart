import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';
import 'package:arus/features/outlets/data/outlets_repository.dart';
import 'package:arus/features/outlets/data/routing_repository.dart';
import 'package:arus/features/outlets/domain/outlet_models.dart';
import 'package:arus/features/outlets/presentation/outlets_provider.dart';
import 'package:arus/features/outlets/presentation/outlet_list_screen.dart';
import 'package:arus/features/outlets/presentation/widgets/outlet_map_widget.dart';

class FakeRoutingDio extends Fake implements Dio {
  final Map<String, dynamic>? responseData;
  final bool shouldThrow;

  FakeRoutingDio({this.responseData, this.shouldThrow = false});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (shouldThrow) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        message: 'Koneksi ke OSRM routing service terputus',
      );
    }
    return Response<T>(
      data: (responseData ?? {
        'routes': [
          {
            'distance': 4850.0,
            'duration': 720.0,
            'geometry': {
              'coordinates': [
                [110.3670, -7.7828],
                [110.3700, -7.7850],
                [110.3750, -7.7900],
                [110.3800, -7.7950],
              ],
            },
          }
        ],
      }) as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class FakeOutletsRepo implements OutletsRepository {
  final List<OutletModel> outlets;
  final List<NearbyOutletItem> nearbyItems;

  FakeOutletsRepo({required this.outlets, required this.nearbyItems});

  @override
  Future<List<OutletModel>> getOutlets() async => outlets;

  @override
  Future<OutletModel> getOutletById(String id) async =>
      outlets.firstWhere((o) => o.id == id);

  @override
  Future<List<OutletPerformanceModel>> getPerformance() async {
    return outlets.map((o) => OutletPerformanceModel(
      outletId: o.id,
      name: o.name,
      address: o.address,
      latitude: o.latitude,
      longitude: o.longitude,
      timezone: o.timezone,
      revenue30dIdr: 50000000,
      transactionCount30d: 320,
      lowStockCount: 0,
      performanceStatus: 'optimal',
    )).toList();
  }

  @override
  Future<NearestOutletResult> getNearestOutlet(double lat, double lng) async {
    return NearestOutletResult(
      nearestOutlet: nearbyItems.firstOrNull,
      allOutletsSorted: nearbyItems,
    );
  }

  @override
  Future<OutletModel> createOutlet({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required String timezone,
  }) async => outlets.first;

  @override
  Future<OutletModel> updateOutlet(
    String id, {
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? timezone,
    bool? isActive,
  }) async => outlets.first;

  @override
  Future<OutletModel> deactivateOutlet(String id) async => outlets.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ownerUser = UserModel(
    id: 'u-owner-1',
    name: 'Inori Owner',
    email: 'owner@arus.id',
    role: UserRole.owner,
  );

  final testOutlets = [
    OutletModel(
      id: 'out-jogja-1',
      name: 'ARUS Malioboro',
      address: 'Jl. Malioboro No. 12, Yogyakarta',
      latitude: -7.7928,
      longitude: 110.3660,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 20,
      createdAt: DateTime.now(),
    ),
    OutletModel(
      id: 'out-jogja-2',
      name: 'ARUS Seturan',
      address: 'Jl. Seturan Raya No. 88, Sleman',
      latitude: -7.7710,
      longitude: 110.4090,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 18,
      createdAt: DateTime.now(),
    ),
    OutletModel(
      id: 'out-solo-1',
      name: 'ARUS Solo Slamet Riyadi',
      address: 'Jl. Slamet Riyadi No. 45, Surakarta',
      latitude: -7.5680,
      longitude: 110.8250,
      timezone: 'Asia/Jakarta',
      isActive: true,
      inventoryCount: 15,
      createdAt: DateTime.now(),
    ),
  ];

  final testNearbyItems = [
    const NearbyOutletItem(
      id: 'out-jogja-1',
      name: 'ARUS Malioboro',
      address: 'Jl. Malioboro No. 12, Yogyakarta',
      latitude: -7.7928,
      longitude: 110.3660,
      timezone: 'Asia/Jakarta',
      distanceKm: 1.1,
    ),
    const NearbyOutletItem(
      id: 'out-jogja-2',
      name: 'ARUS Seturan',
      address: 'Jl. Seturan Raya No. 88, Sleman',
      latitude: -7.7710,
      longitude: 110.4090,
      timezone: 'Asia/Jakarta',
      distanceKm: 5.2,
    ),
    const NearbyOutletItem(
      id: 'out-solo-1',
      name: 'ARUS Solo Slamet Riyadi',
      address: 'Jl. Slamet Riyadi No. 45, Surakarta',
      latitude: -7.5680,
      longitude: 110.8250,
      timezone: 'Asia/Jakarta',
      distanceKm: 58.4,
    ),
  ];

  group('RoutingRepository Unit & Fallback Tests', () {
    test('getRoute parses OSRM road network geometry, distance, and duration correctly', () async {
      final fakeDio = FakeRoutingDio();
      final repo = RoutingRepository(customDio: fakeDio);

      final route = await repo.getRoute(
        origin: const LatLng(-7.7828, 110.3670),
        destination: const LatLng(-7.7950, 110.3800),
      );

      expect(route.isFallback, false);
      expect(route.points.length, 4);
      expect(route.distanceMeters, 4850.0);
      expect(route.durationSeconds, 720.0);
      expect(route.formattedDuration, '12 mnt');
    });

    test('getRoute falls back cleanly without crash when routing server is offline / error', () async {
      final offlineDio = FakeRoutingDio(shouldThrow: true);
      final repo = RoutingRepository(customDio: offlineDio);

      final route = await repo.getRoute(
        origin: const LatLng(-7.7828, 110.3670),
        destination: const LatLng(-7.7950, 110.3800),
      );

      expect(route.isFallback, true);
      expect(route.points.length, 2); // Garis lurus origin ke destination
      expect(route.distanceMeters, greaterThan(0));
      expect(route.errorMessage, isNotNull);
    });

    test('getRoute handles identical origin and destination coordinates safely', () async {
      final repo = RoutingRepository(customDio: FakeRoutingDio());
      final point = const LatLng(-7.7828, 110.3670);

      final route = await repo.getRoute(origin: point, destination: point);

      expect(route.distanceMeters, 0);
      expect(route.durationSeconds, 0);
      expect(route.points.length, 2);
    });

    test('getRoute handles invalid zero coordinates (0.0, 0.0) safely without throwing', () async {
      final repo = RoutingRepository(customDio: FakeRoutingDio());

      final route = await repo.getRoute(
        origin: const LatLng(0.0, 0.0),
        destination: const LatLng(-7.7828, 110.3670),
      );

      expect(route.isFallback, true);
      expect(route.errorMessage, contains('tidak valid'));
    });
  });

  group('LBS Map & Owner Route Navigation Widget Tests', () {
    testWidgets('OutletMapWidget renders OpenStreetMap, auto-selects nearest branch, and displays route', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeOutletsRepo(outlets: testOutlets, nearbyItems: testNearbyItems);
      final fakeDio = FakeRoutingDio();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) {
            final n = AuthNotifier(ref.watch(authRepositoryProvider), ref.watch(secureStoreProvider));
            n.state = AuthState.authenticated(ownerUser);
            return n;
          }),
          outletsRepositoryProvider.overrideWithValue(fakeRepo),
          routingRepositoryProvider.overrideWithValue(RoutingRepository(customDio: fakeDio)),
          userCoordinatesProvider.overrideWith((ref) => (-7.7828, 110.3670)), // Malioboro GPS
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: OutletMapWidget(
                  nearestAsync: AsyncValue.data(
                    NearestOutletResult(
                      nearestOutlet: testNearbyItems.first,
                      allOutletsSorted: testNearbyItems,
                    ),
                  ),
                  performanceAsync: AsyncValue.data(
                    testOutlets.map((o) => OutletPerformanceModel(
                      outletId: o.id,
                      name: o.name,
                      address: o.address,
                      latitude: o.latitude,
                      longitude: o.longitude,
                      timezone: o.timezone,
                      revenue30dIdr: 10000000,
                      transactionCount30d: 50,
                      lowStockCount: 0,
                      performanceStatus: 'optimal',
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify FlutterMap with OpenStreetMap is rendered without error
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);

      // 2. Verify horizontal branch selector chips "Rute ke:" are rendered
      expect(find.text('Rute ke:'), findsOneWidget);
      expect(find.textContaining('ARUS Malioboro'), findsWidgets);
      expect(find.textContaining('ARUS Seturan'), findsWidgets);
      expect(find.textContaining('ARUS Solo Slamet Riyadi'), findsWidgets);

      // 3. Verify route polyline is rendered
      expect(find.byType(PolylineLayer), findsOneWidget);

      // 4. Verify bottom card details for selected nearest branch
      expect(find.text('ARUS Malioboro'), findsWidgets);
      expect(find.textContaining('Jalur:'), findsOneWidget);
      expect(find.text('Detail Cabang'), findsOneWidget);

      // 5. Select another branch (ARUS Seturan) from the chips
      await tester.tap(find.textContaining('ARUS Seturan'));
      await tester.pumpAndSettle();

      // Verify that ARUS Seturan is now selected
      expect(container.read(selectedLbsOutletIdProvider), 'out-jogja-2');
      expect(find.text('ARUS Seturan'), findsWidgets);
      expect(find.textContaining('Jl. Seturan Raya'), findsOneWidget);

      // 6. Select another branch (ARUS Solo Slamet Riyadi)
      await tester.tap(find.textContaining('ARUS Solo Slamet Riyadi'));
      await tester.pumpAndSettle();

      expect(container.read(selectedLbsOutletIdProvider), 'out-solo-1');
      expect(find.text('ARUS Solo Slamet Riyadi'), findsWidgets);
      expect(find.textContaining('Jl. Slamet Riyadi'), findsOneWidget);

      // 7. Tap "Tutup Rute" button
      await tester.tap(find.byTooltip('Tutup Rute'));
      await tester.pumpAndSettle();

      expect(container.read(selectedLbsOutletIdProvider), isNull);

      container.dispose();
    });

    testWidgets('OutletListScreen LBS Tab allows owner to select any branch and view route', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeOutletsRepo(outlets: testOutlets, nearbyItems: testNearbyItems);
      final fakeDio = FakeRoutingDio();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) {
            final n = AuthNotifier(ref.watch(authRepositoryProvider), ref.watch(secureStoreProvider));
            n.state = AuthState.authenticated(ownerUser);
            return n;
          }),
          outletsRepositoryProvider.overrideWithValue(fakeRepo),
          routingRepositoryProvider.overrideWithValue(RoutingRepository(customDio: fakeDio)),
          userCoordinatesProvider.overrideWith((ref) => (-7.7828, 110.3670)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const OutletListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to tab "Peta & LBS Terdekat"
      await tester.tap(find.text('Peta & LBS Terdekat'));
      await tester.pumpAndSettle();

      // Verify LBS elements
      expect(find.text('Simulasi Posisi Pengguna (LBS GPS)'), findsOneWidget);
      expect(find.text('CABANG TERDEKAT (LBS)'), findsOneWidget);
      expect(find.text('Rute Peta'), findsOneWidget);

      // Tap "Rute Peta" on CABANG TERDEKAT card
      await tester.tap(find.text('Rute Peta'));
      await tester.pumpAndSettle();
      expect(container.read(selectedLbsOutletIdProvider), 'out-jogja-1');

      // Scroll down to see list of all branches
      await tester.drag(find.byType(ListView).last, const Offset(0, -450));
      await tester.pumpAndSettle();

      // Verify list of all branches sorted by distance with "Lihat Rute" buttons
      expect(find.text('Seluruh Cabang Terurut Berdasarkan Jarak:'), findsOneWidget);
      expect(find.text('Lihat Rute'), findsWidgets);

      // Tap "Lihat Rute" on the 2nd branch (ARUS Seturan)
      final lihatRuteButtons = find.widgetWithText(OutlinedButton, 'Lihat Rute');
      expect(lihatRuteButtons, findsWidgets);

      await tester.tap(lihatRuteButtons.first);
      await tester.pumpAndSettle();

      // Verify selectedLbsOutletIdProvider is set to out-jogja-2
      expect(container.read(selectedLbsOutletIdProvider), 'out-jogja-2');

      container.dispose();
    });
  });
}
