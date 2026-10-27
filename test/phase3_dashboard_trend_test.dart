import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/features/analytics/data/analytics_repository.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/dashboard/presentation/dashboard_screen.dart';
import 'package:arus/features/pos/data/pos_repository.dart';
import 'package:arus/features/pos/domain/pos_models.dart';

class MockApiClient extends Fake implements ApiClient {
  final Map<String, dynamic>? Function(String path, {Map<String, dynamic>? queryParameters})? onGet;
  final Map<String, dynamic>? Function(String path, {dynamic data})? onPost;

  MockApiClient({this.onGet, this.onPost});

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (onGet != null) {
      final res = onGet!(path, queryParameters: queryParameters);
      if (res != null) {
        return Response<T>(
          data: res as T,
          statusCode: 200,
          requestOptions: RequestOptions(path: path),
        );
      }
    }
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      message: 'Connection failed',
    );
  }
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.initialState);

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
  Future<void> applyDisplayCurrency(String currency) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDatabase.instance;

  setUp(() async {
    await localDb.clearLocalDatabase();
  });

  group('Phase 3 — Dashboard, History, and "Tren" Chart Tests', () {
    test('Skenario 1: Dashboard overview dan sales trend berhasil dimuat saat online', () async {
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/overview') {
            return {
              'data': {
                'revenue_idr': 500000,
                'subtotal_idr': 500000,
                'discount_idr': 0,
                'transaction_count': 10,
                'avg_basket_size_idr': 50000,
              }
            };
          }
          if (path == '/analytics/sales-trend') {
            return {
              'data': [
                {'date': '2026-10-21', 'revenue_idr': 100000, 'count': 2},
                {'date': '2026-10-22', 'revenue_idr': 200000, 'count': 4},
                {'date': '2026-10-23', 'revenue_idr': 0, 'count': 0},
                {'date': '2026-10-24', 'revenue_idr': 300000, 'count': 5},
                {'date': '2026-10-25', 'revenue_idr': 150000, 'count': 3},
                {'date': '2026-10-26', 'revenue_idr': 0, 'count': 0},
                {'date': '2026-10-27', 'revenue_idr': 400000, 'count': 8},
              ]
            };
          }
          return null;
        },
      );

      final repo = AnalyticsRepository(onlineClient, localDb);
      final overview = await repo.getOverview(outletId: 'out-1');
      expect(overview.revenueIdr, 500000);
      expect(overview.transactionCount, 10);
      expect(overview.isOffline, isFalse);
      expect(overview.pendingCount, 0);

      final trend = await repo.getSalesTrend(outletId: 'out-1', days: 7);
      expect(trend.length, 7);
      expect(trend.first.date, '2026-10-21');
      expect(trend.last.date, '2026-10-27');
    });

    test('Skenario 2: Overview online memasukkan pending transaksi lokal tanpa duplikasi', () async {
      final offlineTx = PosTransactionModel(
        id: 'tx-local-pending',
        receiptNo: 'REC-OFF-01',
        outletId: 'out-1',
        outletName: 'Outlet Utama',
        cashierName: 'Kasir B',
        subtotalIdr: 30000,
        discountIdr: 0,
        totalIdr: 30000,
        paymentMethod: 'cash',
        paidIdr: 30000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'client-req-1',
      );
      await localDb.saveOfflineTransaction(
        transaction: offlineTx,
        clientRequestId: 'client-req-1',
        isSynced: false,
      );

      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/overview') {
            return {
              'data': {
                'revenue_idr': 500000,
                'subtotal_idr': 500000,
                'discount_idr': 0,
                'transaction_count': 10,
                'avg_basket_size_idr': 50000,
              }
            };
          }
          return null;
        },
      );

      final repo = AnalyticsRepository(onlineClient, localDb);
      final overview = await repo.getOverview(outletId: 'out-1');
      expect(overview.revenueIdr, 530000);
      expect(overview.transactionCount, 11);
      expect(overview.pendingCount, 1);
      expect(overview.isOffline, isFalse);
    });

    test('Skenario 3: Overview dan Sales Trend fallback ke SQLite saat offline tanpa crash', () async {
      final offlineClient = MockApiClient();

      final tx1 = PosTransactionModel(
        id: 'tx-backup-1',
        receiptNo: 'REC-BKP-1',
        outletId: 'out-1',
        outletName: 'Outlet Utama',
        cashierName: 'Kasir Utama',
        subtotalIdr: 45000,
        discountIdr: 0,
        totalIdr: 45000,
        paymentMethod: 'cash',
        paidIdr: 50000,
        changeIdr: 5000,
        status: 'completed',
        createdAt: DateTime.now(),
      );
      await localDb.backupTransaction({
        'transaction_id': tx1.id,
        'receipt_no': tx1.receiptNo,
        'outlet_name': tx1.outletName,
        'total_idr': tx1.totalIdr,
        'payment_method': tx1.paymentMethod,
        'status': tx1.status,
        'raw_json': null,
        'created_at': tx1.createdAt.toIso8601String(),
      });

      final repo = AnalyticsRepository(offlineClient, localDb);
      final overview = await repo.getOverview(outletId: 'out-1');
      expect(overview.isOffline, isTrue);
      expect(overview.revenueIdr, 45000);
      expect(overview.transactionCount, 1);

      final trend = await repo.getSalesTrend(outletId: 'out-1', days: 7);
      expect(trend.length, 7);
      final todayRevenue = trend.last.revenueIdr;
      expect(todayRevenue, 45000);
    });

    test('Skenario 4: Deduplikasi ketat dual-key (ID dan clientRequestId) mencegah double-counting', () async {
      final offlineClient = MockApiClient();
      final now = DateTime.now();

      final tx = PosTransactionModel(
        id: 'tx-dup-1',
        receiptNo: 'REC-DUP-01',
        outletId: 'out-1',
        outletName: 'Outlet Utama',
        cashierName: 'Kasir Utama',
        subtotalIdr: 75000,
        discountIdr: 0,
        totalIdr: 75000,
        paymentMethod: 'cash',
        paidIdr: 75000,
        changeIdr: 0,
        status: 'completed',
        createdAt: now,
        clientRequestId: 'req-dup-1',
      );

      await localDb.saveOfflineTransaction(
        transaction: tx,
        clientRequestId: 'req-dup-1',
        isSynced: true,
      );
      await localDb.backupTransaction({
        'transaction_id': 'tx-dup-1',
        'receipt_no': 'REC-DUP-01',
        'outlet_name': 'Outlet Utama',
        'total_idr': 75000,
        'payment_method': 'cash',
        'status': 'completed',
        'raw_json': null,
        'created_at': now.toIso8601String(),
      });

      final repo = AnalyticsRepository(offlineClient, localDb);
      final overview = await repo.getOverview(outletId: 'out-1');
      expect(overview.revenueIdr, 75000);
      expect(overview.transactionCount, 1);
    });

    test('Skenario 5: Filter tanggal from & to dan isolasi cabang pada offline history', () async {
      final offlineClient = MockApiClient();
      final posRepo = PosRepository(offlineClient, localDb);

      await localDb.backupTransaction({
        'transaction_id': 'tx-branch1-today',
        'receipt_no': 'REC-B1-TODAY',
        'outlet_name': 'Outlet 1',
        'total_idr': 20000,
        'payment_method': 'cash',
        'status': 'completed',
        'raw_json': '{"id":"tx-branch1-today","receipt_no":"REC-B1-TODAY","outlet_id":"out-1","outlet_name":"Outlet 1","cashier_name":"Kasir","subtotal_idr":20000,"discount_idr":0,"total_idr":20000,"payment_method":"cash","paid_idr":20000,"change_idr":0,"status":"completed","created_at":"2026-10-27T10:00:00.000Z"}',
        'created_at': '2026-10-27T10:00:00.000Z',
      });

      await localDb.backupTransaction({
        'transaction_id': 'tx-branch2-today',
        'receipt_no': 'REC-B2-TODAY',
        'outlet_name': 'Outlet 2',
        'total_idr': 90000,
        'payment_method': 'cash',
        'status': 'completed',
        'raw_json': '{"id":"tx-branch2-today","receipt_no":"REC-B2-TODAY","outlet_id":"out-2","outlet_name":"Outlet 2","cashier_name":"Kasir","subtotal_idr":90000,"discount_idr":0,"total_idr":90000,"payment_method":"cash","paid_idr":90000,"change_idr":0,"status":"completed","created_at":"2026-10-27T11:00:00.000Z"}',
        'created_at': '2026-10-27T11:00:00.000Z',
      });

      await localDb.backupTransaction({
        'transaction_id': 'tx-branch1-past',
        'receipt_no': 'REC-B1-PAST',
        'outlet_name': 'Outlet 1',
        'total_idr': 35000,
        'payment_method': 'cash',
        'status': 'completed',
        'raw_json': '{"id":"tx-branch1-past","receipt_no":"REC-B1-PAST","outlet_id":"out-1","outlet_name":"Outlet 1","cashier_name":"Kasir","subtotal_idr":35000,"discount_idr":0,"total_idr":35000,"payment_method":"cash","paid_idr":35000,"change_idr":0,"status":"completed","created_at":"2026-10-10T10:00:00.000Z"}',
        'created_at': '2026-10-10T10:00:00.000Z',
      });

      final txList = await posRepo.getTransactions(
        outletId: 'out-1',
        from: '2026-10-27',
        to: '2026-10-27',
      );

      expect(txList.length, 1);
      expect(txList.first.id, 'tx-branch1-today');
      expect(txList.first.totalIdr, 20000);
    });

    test('Skenario 6: Riwayat transaksi offline menandai pending sync dengan benar', () async {
      final offlineClient = MockApiClient();
      final posRepo = PosRepository(offlineClient, localDb);

      final offlineTx = PosTransactionModel(
        id: 'tx-offline-item',
        receiptNo: 'REC-OFF-SYNC',
        outletId: 'out-1',
        outletName: 'Outlet Utama',
        cashierName: 'Kasir B',
        subtotalIdr: 15000,
        discountIdr: 0,
        totalIdr: 15000,
        paymentMethod: 'cash',
        paidIdr: 20000,
        changeIdr: 5000,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'client-req-sync',
      );
      await localDb.saveOfflineTransaction(
        transaction: offlineTx,
        clientRequestId: 'client-req-sync',
        isSynced: false,
      );

      final list = await posRepo.getTransactions(outletId: 'out-1');
      expect(list.any((t) => t.id == 'tx-offline-item' && t.isOfflinePending), isTrue);
    });

    testWidgets('Skenario 7: DashboardScreen menampilkan banner Mode Offline secara jujur', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-1',
        name: 'Rina Owner',
        email: 'owner@arus.demo',
        role: UserRole.owner,
      );

      const offlineKpi = AnalyticsOverviewModel(
        revenueIdr: 120000,
        subtotalIdr: 120000,
        discountIdr: 0,
        transactionCount: 3,
        avgBasketSizeIdr: 40000,
        isOffline: true,
        pendingCount: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(ownerUser))),
            analyticsOverviewProvider.overrideWith((ref) async => offlineKpi),
            salesTrendProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mode Offline'), findsOneWidget);
      expect(find.textContaining('Menampilkan data lokal. Ada 2 transaksi menunggu sinkronisasi.'), findsOneWidget);
      expect(find.text('Rp.120.000'), findsOneWidget);
    });

    testWidgets('Skenario 8: DashboardScreen visualisasi grafik Tren menampilkan bar terdistribusi', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const ownerUser = UserModel(
        id: 'u-owner-1',
        name: 'Rina Owner',
        email: 'owner@arus.demo',
        role: UserRole.owner,
      );

      const onlineKpi = AnalyticsOverviewModel(
        revenueIdr: 500000,
        subtotalIdr: 500000,
        discountIdr: 0,
        transactionCount: 10,
        avgBasketSizeIdr: 50000,
        isOffline: false,
        pendingCount: 0,
      );

      const trendPoints = [
        SalesTrendPoint(date: '2026-10-21', revenueIdr: 100000, count: 2),
        SalesTrendPoint(date: '2026-10-22', revenueIdr: 0, count: 0),
        SalesTrendPoint(date: '2026-10-23', revenueIdr: 400000, count: 8),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(ownerUser))),
            analyticsOverviewProvider.overrideWith((ref) async => onlineKpi),
            salesTrendProvider.overrideWith((ref) async => trendPoints),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tren'), findsOneWidget);
      // Tanggal 21, 22, 23 tertera sebagai label bar
      expect(find.text('21'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('23'), findsOneWidget);
    });
  });
}
