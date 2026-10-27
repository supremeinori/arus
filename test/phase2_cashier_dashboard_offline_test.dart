import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/network/app_exception.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/sync/sync_service.dart';
import 'package:arus/features/analytics/data/analytics_repository.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/dashboard/presentation/shift_summary_screen.dart';
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
      return Response<T>(
        data: res as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw DioException(
      requestOptions: RequestOptions(path: path),
      type: DioExceptionType.connectionError,
      message: 'Connection failed',
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (onPost != null) {
      final res = onPost!(path, data: data);
      return Response<T>(
        data: res as T,
        statusCode: 200,
        requestOptions: RequestOptions(path: path),
      );
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
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Corrective Patch: Cashier Dashboard Offline Tests', () {
    final localDb = LocalDatabase.instance;

    setUp(() async {
      await localDb.clearLocalDatabase();
    });

    test('Skenario 1: Dashboard berhasil menampilkan data shift saat online', () async {
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => {
          'data': {
            'today_revenue_idr': 150000,
            'cash_revenue_idr': 100000,
            'qris_revenue_idr': 50000,
            'transaction_count': 6,
          }
        },
      );

      final repo = AnalyticsRepository(onlineClient, localDb);
      final shift = await repo.getShiftSummary(outletId: 'out-sudirman');

      expect(shift.isOffline, isFalse);
      expect(shift.isDataAvailable, isTrue);
      expect(shift.todayRevenueIdr, equals(150000));
      expect(shift.cashRevenueIdr, equals(100000));
      expect(shift.qrisRevenueIdr, equals(50000));
      expect(shift.transactionCount, equals(6));
      expect(shift.pendingCount, equals(0));
    });

    test('Skenario 2: Setelah koneksi terputus, dashboard tetap menampilkan data lokal yang tersedia', () async {
      final now = DateTime.now();
      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-offline-1',
          receiptNo: 'OFF-001',
          outletId: 'out-sudirman',
          outletName: 'ARUS Coffee Sudirman',
          cashierName: 'Siti Kasir',
          subtotalIdr: 40000,
          discountIdr: 0,
          totalIdr: 40000,
          paymentMethod: 'cash',
          paidIdr: 40000,
          changeIdr: 0,
          status: 'completed',
          createdAt: now,
        ),
        clientRequestId: 'req-001',
        isSynced: true,
      );

      final offlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => throw const AppException('Koneksi terputus'),
      );

      final repo = AnalyticsRepository(offlineClient, localDb);
      final shift = await repo.getShiftSummary(outletId: 'out-sudirman');

      expect(shift.isOffline, isTrue);
      expect(shift.isDataAvailable, isTrue);
      expect(shift.todayRevenueIdr, equals(40000));
      expect(shift.cashRevenueIdr, equals(40000));
      expect(shift.qrisRevenueIdr, equals(0));
      expect(shift.transactionCount, equals(1));
    });

    test('Skenario 3: Transaksi baru diterima secara lokal saat offline langsung memperbarui angka dashboard', () async {
      final now = DateTime.now();
      final offlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => throw const AppException('Koneksi terputus'),
      );
      final repo = AnalyticsRepository(offlineClient, localDb);

      // Transaksi 1: Tunai Rp 30.000
      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-offline-new-1',
          receiptNo: 'OFF-NEW-1',
          outletId: 'out-sudirman',
          outletName: 'ARUS Coffee Sudirman',
          cashierName: 'Siti Kasir',
          subtotalIdr: 30000,
          discountIdr: 0,
          totalIdr: 30000,
          paymentMethod: 'cash',
          paidIdr: 30000,
          changeIdr: 0,
          status: 'offline_pending',
          createdAt: now,
          isOfflinePending: true,
        ),
        clientRequestId: 'req-new-1',
        isSynced: false,
      );

      var shift = await repo.getShiftSummary(outletId: 'out-sudirman');
      expect(shift.todayRevenueIdr, equals(30000));
      expect(shift.transactionCount, equals(1));
      expect(shift.pendingCount, equals(1));

      // Transaksi 2 diterima saat offline: QRIS Rp 25.000
      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-offline-new-2',
          receiptNo: 'OFF-NEW-2',
          outletId: 'out-sudirman',
          outletName: 'ARUS Coffee Sudirman',
          cashierName: 'Siti Kasir',
          subtotalIdr: 25000,
          discountIdr: 0,
          totalIdr: 25000,
          paymentMethod: 'qris_simulated',
          paidIdr: 25000,
          changeIdr: 0,
          status: 'offline_pending',
          createdAt: now,
          isOfflinePending: true,
        ),
        clientRequestId: 'req-new-2',
        isSynced: false,
      );

      // Angka langsung terakumulasi: Rp 55.000, 2 transaksi (1 cash, 1 qris, 2 pending)
      shift = await repo.getShiftSummary(outletId: 'out-sudirman');
      expect(shift.todayRevenueIdr, equals(55000));
      expect(shift.cashRevenueIdr, equals(30000));
      expect(shift.qrisRevenueIdr, equals(25000));
      expect(shift.transactionCount, equals(2));
      expect(shift.pendingCount, equals(2));
    });

    testWidgets('Skenario 4: Status offline terlihat jelas dan menampilkan indikator pending sinkronisasi', (tester) async {
      const staffUser = UserModel(
        id: 'u-staff-1',
        name: 'Siti Kasir',
        email: 'siti@arus.demo',
        role: UserRole.staff,
        outlets: [
          OutletSummary(id: 'out-sudirman', name: 'ARUS Sudirman', timezone: 'WIB'),
        ],
      );

      const offlineShift = ShiftSummaryModel(
        todayRevenueIdr: 75000,
        cashRevenueIdr: 50000,
        qrisRevenueIdr: 25000,
        transactionCount: 3,
        isOffline: true,
        pendingCount: 2,
        isDataAvailable: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(AuthState.authenticated(staffUser))),
            shiftSummaryProvider.overrideWith((ref) async => offlineShift),
          ],
          child: const MaterialApp(
            home: ShiftSummaryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi banner Mode Offline tampil dengan jujur
      expect(find.text('Mode Offline'), findsOneWidget);
      expect(find.textContaining('Menampilkan penjualan dari data lokal perangkat ini'), findsOneWidget);

      // Verifikasi indikator pending sinkronisasi tampil
      expect(find.textContaining('2 transaksi lokal menunggu sinkronisasi'), findsOneWidget);

      // Verifikasi angka penjualan lokal tampil
      expect(find.textContaining('75.000'), findsOneWidget);
      expect(find.text('3 Transaksi'), findsOneWidget);
    });

    test('Skenario 5 & 6: Data bertahan saat restart, tersinkronisasi saat koneksi pulih tanpa dihitung dua kali', () async {
      final now = DateTime.now();
      const clientReqId = 'req-restart-sync-001';

      // Transaksi disimpan saat offline
      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-restart-1',
          receiptNo: 'OFF-RESTART-1',
          outletId: 'out-sudirman',
          outletName: 'Sudirman',
          cashierName: 'Siti',
          subtotalIdr: 60000,
          discountIdr: 0,
          totalIdr: 60000,
          paymentMethod: 'cash',
          paidIdr: 60000,
          changeIdr: 0,
          status: 'offline_pending',
          createdAt: now,
          items: [
            const PosCartItem(productId: 'prod-1', productName: 'Kopi', sku: 'K-01', unitPriceIdr: 60000, quantity: 1),
          ],
          isOfflinePending: true,
          clientRequestId: clientReqId,
        ),
        clientRequestId: clientReqId,
        isSynced: false,
      );

      // Simulasi buka ulang aplikasi saat offline (membaca database lokal)
      final offlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => throw const AppException('Koneksi terputus'),
      );
      final offlineRepo = AnalyticsRepository(offlineClient, localDb);
      var shift = await offlineRepo.getShiftSummary(outletId: 'out-sudirman');
      expect(shift.todayRevenueIdr, equals(60000));
      expect(shift.pendingCount, equals(1));

      // Koneksi pulih: lakukan sinkronisasi
      final onlineClient = MockApiClient(
        onPost: (path, {data}) => {
          'statusCode': 201,
          'data': {
            'id': 'srv-confirmed-1',
            'receipt_no': 'REC-CONFIRMED-1',
            'client_request_id': clientReqId,
            'status': 'completed',
          }
        },
        onGet: (path, {queryParameters}) => {
          'data': {
            'today_revenue_idr': 60000, // Server menghitung 1 transaksi yang sama
            'cash_revenue_idr': 60000,
            'qris_revenue_idr': 0,
            'transaction_count': 1,
          }
        },
      );

      final syncService = SyncService(onlineClient, localDb);
      final syncResult = await syncService.syncPendingTransactions();
      expect(syncResult.syncedCount, equals(1));

      // Ambil kembali shift summary dari server online
      final onlineRepo = AnalyticsRepository(onlineClient, localDb);
      shift = await onlineRepo.getShiftSummary(outletId: 'out-sudirman');

      // Tidak ada duplikasi: total tetap Rp 60.000, 1 transaksi, pending = 0
      expect(shift.isOffline, isFalse);
      expect(shift.todayRevenueIdr, equals(60000));
      expect(shift.transactionCount, equals(1));
      expect(shift.pendingCount, equals(0));
    });

    test('Skenario 7: Sinkronisasi tidak menghapus cache operasional atau transaksi pending lainnya', () async {
      // 1. Simpan produk ke cache operasional
      const testProduct = ProductModel(
        id: 'p-cache-1',
        sku: 'SKU-C1',
        name: 'Croissant Coklat',
        priceIdr: 28000,
        estimatedPortions: 12,
      );
      await localDb.cacheProducts([testProduct]);

      // 2. Simpan 2 transaksi offline di antrean lokal
      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-first',
          receiptNo: 'OFF-FIRST',
          outletId: 'out-sudirman',
          outletName: 'Sudirman',
          cashierName: 'Kasir',
          subtotalIdr: 28000,
          discountIdr: 0,
          totalIdr: 28000,
          paymentMethod: 'cash',
          paidIdr: 28000,
          changeIdr: 0,
          status: 'offline_pending',
          createdAt: DateTime.now(),
          items: [
            const PosCartItem(productId: 'p-cache-1', productName: 'Croissant', sku: 'SKU-C1', unitPriceIdr: 28000, quantity: 1),
          ],
        ),
        clientRequestId: 'client-req-first',
        isSynced: false,
      );

      await localDb.saveOfflineTransaction(
        transaction: PosTransactionModel(
          id: 'tx-second-fail',
          receiptNo: 'OFF-FAIL',
          outletId: 'out-sudirman',
          outletName: 'Sudirman',
          cashierName: 'Kasir',
          subtotalIdr: 56000,
          discountIdr: 0,
          totalIdr: 56000,
          paymentMethod: 'cash',
          paidIdr: 56000,
          changeIdr: 0,
          status: 'offline_pending',
          createdAt: DateTime.now(),
          items: [
            const PosCartItem(productId: 'p-cache-1', productName: 'Croissant', sku: 'SKU-C1', unitPriceIdr: 28000, quantity: 2),
          ],
        ),
        clientRequestId: 'client-req-fail',
        isSynced: false,
      );

      // 3. Sync client: 1 sukses, 1 gagal (error 400)
      final client = MockApiClient(
        onPost: (path, {data}) {
          final payload = data as Map<String, dynamic>;
          if (payload['client_request_id'] == 'client-req-first') {
            return {
              'statusCode': 201,
              'data': {'id': 'srv-1', 'receipt_no': 'REC-1', 'status': 'completed'}
            };
          }
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(statusCode: 400, requestOptions: RequestOptions(path: path)),
          );
        },
      );

      final syncService = SyncService(client, localDb);
      await syncService.syncPendingTransactions();

      // Verifikasi: Cache produk operasional TETAP UTUH (tidak dihapus)
      final cachedProducts = await localDb.getCachedProducts();
      expect(cachedProducts.any((p) => p.id == 'p-cache-1'), isTrue);

      // Verifikasi: Transaksi kedua yang gagal TETAP TERSIMPAN di antrean pending
      final pendingQueue = await localDb.getPendingOfflineTransactions();
      expect(pendingQueue.any((t) => t['client_request_id'] == 'client-req-fail'), isTrue);
    });

    test('Skenario 8: Jika belum ada data lokal sama sekali untuk hari ini dan offline, tampilkan status jujur tanpa mengarang angka', () async {
      final offlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => throw const AppException('Koneksi terputus'),
      );

      final repo = AnalyticsRepository(offlineClient, localDb);
      final shift = await repo.getShiftSummary(outletId: 'out-sudirman');

      // Status jujur: isDataAvailable = false, isOffline = true
      expect(shift.isOffline, isTrue);
      expect(shift.isDataAvailable, isFalse);
    });
  });
}
