import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/sync/sync_service.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
import 'package:arus/features/pos/data/pos_catalog_repository.dart';
import 'package:arus/features/pos/data/pos_repository.dart';
import 'package:arus/features/pos/domain/pos_models.dart';
import 'package:arus/features/pos/presentation/pos_provider.dart';

// Mock ApiClient for testing
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: Offline POS and Reliable Synchronization', () {
    final localDb = LocalDatabase.instance;

    setUp(() async {
      // Clear entire local DB / memory stores before each test
      await localDb.clearLocalDatabase();
    });

    test('T-PHASE2-01: PosCatalogRepository offline fallback muat produk dari cache lokal', () async {
      // 1. Simpan produk ke cache lokal
      const testProduct = ProductModel(
        id: 'prod-test-1',
        sku: 'SKU-001',
        name: 'Kopi Susu Gula Aren',
        priceIdr: 22000,
        estimatedPortions: 15,
        isActive: true,
      );
      await localDb.cacheProducts([testProduct]);

      // 2. Mock ApiClient yang selalu melempar error koneksi (offline)
      final offlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => throw DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionError,
          message: 'No internet connection',
        ),
      );

      final catalogRepo = PosCatalogRepository(offlineClient, localDb);
      final catalog = await catalogRepo.getCatalog('outlet-1');

      // 3. Verifikasi produk berhasil dimuat dari cache lokal SQLite
      expect(catalog.isNotEmpty, isTrue);
      expect(catalog.first.product.id, equals('prod-test-1'));
      expect(catalog.first.product.name, equals('Kopi Susu Gula Aren'));
      expect(catalog.first.isAvailable, isTrue);
      expect(catalog.first.maxPortions, equals(15));
    });

    test('T-PHASE2-02: Offline checkout mengurangi stok lokal secara instan dan menyimpan clientRequestId yang stabil', () async {
      const testProduct = ProductModel(
        id: 'prod-stock-1',
        sku: 'SKU-002',
        name: 'Matcha Latte',
        priceIdr: 25000,
        estimatedPortions: 10,
        isActive: true,
      );
      await localDb.cacheProducts([testProduct]);

      // Buat offline repository (mock client yang offline)
      final offlineClient = MockApiClient(
        onPost: (path, {data}) => throw DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionError,
          message: 'Offline mode',
        ),
      );
      final posRepo = PosRepository(offlineClient, localDb);

      const stableRequestId = 'req-unique-uuid-12345';
      final offlineTx = await posRepo.createTransaction(
        clientRequestId: stableRequestId,
        outletId: 'out-sudirman',
        paymentMethod: 'cash',
        paidIdr: 50000,
        discountIdr: 0,
        items: [
          const PosCartItem(
            productId: 'prod-stock-1',
            productName: 'Matcha Latte',
            sku: 'SKU-002',
            unitPriceIdr: 25000,
            quantity: 3,
          ),
        ],
      );

      // Verifikasi transaksi offline tersimpan dengan flag isOfflinePending dan clientRequestId stabil
      expect(offlineTx.isOfflinePending, isTrue);
      expect(offlineTx.status, equals('offline_pending'));
      expect(offlineTx.clientRequestId, equals(stableRequestId));

      // Verifikasi stok lokal langsung berkurang secara instan (10 - 3 = 7)
      final cachedList = await localDb.getCachedProducts();
      final updatedProduct = cachedList.firstWhere((p) => p.id == 'prod-stock-1');
      expect(updatedProduct.estimatedPortions, equals(7));

      // Verifikasi katalog POS offline langsung merefleksikan sisa stok (maxPortions = 7) tanpa perlu sync
      final catalogRepo = PosCatalogRepository(offlineClient, localDb);
      final catalog1 = await catalogRepo.getCatalog('out-sudirman');
      final catalogItem1 = catalog1.firstWhere((c) => c.product.id == 'prod-stock-1');
      expect(catalogItem1.maxPortions, equals(7));
      expect(catalogItem1.isAvailable, isTrue);

      // Transaksi kedua: beli sisa seluruh stok (7 porsi) secara offline
      const secondRequestId = 'req-unique-uuid-67890';
      await posRepo.createTransaction(
        clientRequestId: secondRequestId,
        outletId: 'out-sudirman',
        paymentMethod: 'cash',
        paidIdr: 175000,
        discountIdr: 0,
        items: [
          const PosCartItem(
            productId: 'prod-stock-1',
            productName: 'Matcha Latte',
            sku: 'SKU-002',
            unitPriceIdr: 25000,
            quantity: 7,
          ),
        ],
      );

      // Verifikasi stok lokal langsung 0 (habis) secara instan tanpa perlu sync
      final cachedList2 = await localDb.getCachedProducts();
      final updatedProduct2 = cachedList2.firstWhere((p) => p.id == 'prod-stock-1');
      expect(updatedProduct2.estimatedPortions, equals(0));

      // Verifikasi katalog POS offline langsung menandai produk Habis (isAvailable: false, maxPortions: 0)
      final catalog2 = await catalogRepo.getCatalog('out-sudirman');
      final catalogItem2 = catalog2.firstWhere((c) => c.product.id == 'prod-stock-1');
      expect(catalogItem2.maxPortions, equals(0));
      expect(catalogItem2.isAvailable, isFalse);

      // Verifikasi keranjang POS menolak penambahan produk yang sudah habis
      final cartNotifier = PosCartNotifier();
      final addResult = cartNotifier.addProduct(catalogItem2.product, maxPortions: catalogItem2.maxPortions);
      expect(addResult, isFalse);
      expect(cartNotifier.state.items.isEmpty, isTrue);

      // Verifikasi antrean pending transaksi lokal berisi transaksi ini
      final pendingList = await localDb.getPendingOfflineTransactions();
      expect(pendingList.any((t) => t['client_request_id'] == stableRequestId), isTrue);
      expect(pendingList.any((t) => t['client_request_id'] == secondRequestId), isTrue);
    });

    test('T-PHASE2-03: PosRepository.getTransactions menggabungkan transaksi pending offline ke riwayat saat online', () async {
      // Siapkan transaksi pending di antrean lokal
      final now = DateTime.now();
      final localTx = PosTransactionModel(
        id: 'offline-tx-999',
        receiptNo: 'OFF-20261027-999',
        outletId: 'out-sudirman',
        outletName: 'ARUS Coffee Sudirman',
        cashierName: 'Kasir Sudirman',
        subtotalIdr: 25000,
        discountIdr: 0,
        totalIdr: 25000,
        paymentMethod: 'cash',
        paidIdr: 30000,
        changeIdr: 5000,
        status: 'offline_pending',
        createdAt: now,
        isOfflinePending: true,
        clientRequestId: 'req-pending-merge-001',
      );
      await localDb.saveOfflineTransaction(
        transaction: localTx,
        clientRequestId: 'req-pending-merge-001',
        isSynced: false,
      );

      // Server hanya mengembalikan transaksi lama yang sudah settled
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => {
          'data': [
            {
              'id': 'server-tx-001',
              'receipt_no': 'REC-20261027-001',
              'outlet_id': 'out-sudirman',
              'outlet': {'name': 'ARUS Coffee Sudirman'},
              'cashier': {'name': 'Kasir Sudirman'},
              'subtotal_idr': 50000,
              'discount_idr': 0,
              'total_idr': 50000,
              'payment_method': 'cash',
              'paid_idr': 50000,
              'change_idr': 0,
              'status': 'completed',
              'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
              'items': [],
            }
          ]
        },
      );

      final posRepo = PosRepository(onlineClient, localDb);
      final history = await posRepo.getTransactions(outletId: 'out-sudirman');

      // Riwayat harus berisi transaksi offline pending di atas + transaksi server
      expect(history.length, equals(2));
      expect(history.first.clientRequestId, equals('req-pending-merge-001'));
      expect(history.first.isOfflinePending, isTrue);
      expect(history.last.id, equals('server-tx-001'));
    });

    test('T-PHASE2-04: PosRepository.getTransactions menduplikasi transaksi yang sudah ada di server', () async {
      // Simpan transaksi lokal yang clientRequestId-nya ternyata SUDAH dikonfirmasi server
      const sameClientReqId = 'req-already-synced-001';
      final localTx = PosTransactionModel(
        id: 'offline-tx-already-done',
        receiptNo: 'OFF-20261027-888',
        outletId: 'out-sudirman',
        outletName: 'ARUS Coffee Sudirman',
        cashierName: 'Kasir Sudirman',
        subtotalIdr: 25000,
        discountIdr: 0,
        totalIdr: 25000,
        paymentMethod: 'cash',
        paidIdr: 25000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        isOfflinePending: true,
        clientRequestId: sameClientReqId,
      );
      await localDb.saveOfflineTransaction(
        transaction: localTx,
        clientRequestId: sameClientReqId,
        isSynced: false,
      );

      // Server mengembalikan transaksi yang sama dengan client_request_id tersebut
      final onlineClient = MockApiClient(
        onGet: (path, {queryParameters}) => {
          'data': [
            {
              'id': 'server-tx-confirmed',
              'receipt_no': 'REC-SERVER-888',
              'client_request_id': sameClientReqId,
              'outlet_id': 'out-sudirman',
              'outlet': {'name': 'ARUS Coffee Sudirman'},
              'cashier': {'name': 'Kasir Sudirman'},
              'subtotal_idr': 25000,
              'discount_idr': 0,
              'total_idr': 25000,
              'payment_method': 'cash',
              'paid_idr': 25000,
              'change_idr': 0,
              'status': 'completed',
              'created_at': DateTime.now().toIso8601String(),
              'items': [],
            }
          ]
        },
      );

      final posRepo = PosRepository(onlineClient, localDb);
      final history = await posRepo.getTransactions(outletId: 'out-sudirman');

      // Hanya ada 1 item di list (tidak ada duplikasi)
      expect(history.length, equals(1));
      expect(history.first.id, equals('server-tx-confirmed'));
      expect(history.first.receiptNo, equals('REC-SERVER-888'));
    });

    test('T-PHASE2-05: SyncService berhasil sinkronisasi dan menangani konflik stok HTTP 400 tanpa crash', () async {
      // 1. Siapkan 2 transaksi offline di antrean lokal
      final txSuccess = PosTransactionModel(
        id: 'tx-sync-success',
        receiptNo: 'OFF-SUCCESS-1',
        outletId: 'out-sudirman',
        outletName: 'Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 20000,
        discountIdr: 0,
        totalIdr: 20000,
        paymentMethod: 'cash',
        paidIdr: 20000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        items: [
          const PosCartItem(productId: 'prod-1', productName: 'Kopi', sku: 'K-01', unitPriceIdr: 20000, quantity: 1),
        ],
      );

      final txConflict = PosTransactionModel(
        id: 'tx-sync-conflict',
        receiptNo: 'OFF-CONFLICT-1',
        outletId: 'out-sudirman',
        outletName: 'Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 40000,
        discountIdr: 0,
        totalIdr: 40000,
        paymentMethod: 'cash',
        paidIdr: 40000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        items: [
          const PosCartItem(productId: 'prod-2', productName: 'Sirup Mahal', sku: 'S-01', unitPriceIdr: 40000, quantity: 2),
        ],
      );

      await localDb.saveOfflineTransaction(
        transaction: txSuccess,
        clientRequestId: 'client-req-success-1',
        isSynced: false,
      );
      await localDb.saveOfflineTransaction(
        transaction: txConflict,
        clientRequestId: 'client-req-conflict-1',
        isSynced: false,
      );

      // 2. Mock ApiClient: 1 sukses (201/200), 1 konflik stok HTTP 400
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          final payload = data as Map<String, dynamic>;
          if (payload['client_request_id'] == 'client-req-success-1') {
            return {
              'statusCode': 201,
              'data': {
                'id': 'srv-tx-1',
                'receipt_no': 'REC-SRV-SUCCESS-1',
                'status': 'completed',
              }
            };
          }
          // Konflik stok: server mengembalikan error 400 INSUFFICIENT_STOCK
          throw DioException(
            requestOptions: RequestOptions(path: path),
            response: Response(
              statusCode: 400,
              requestOptions: RequestOptions(path: path),
              data: {
                'error': {
                  'code': 'INSUFFICIENT_STOCK',
                  'message': 'Stok bahan baku tidak mencukupi untuk memenuhi pesanan.',
                }
              },
            ),
          );
        },
      );

      final syncService = SyncService(mockClient, localDb);
      final result = await syncService.syncPendingTransactions();

      // Verifikasi ringkasan sinkronisasi: 1 synced, 1 failed
      expect(result.syncedCount, equals(1));
      expect(result.failedCount, equals(1));

      // Verifikasi status error terekam di record lokal tanpa crash
      final pendingQueue = await localDb.getPendingOfflineTransactions();
      final failedItem = pendingQueue.firstWhere((t) => t['client_request_id'] == 'client-req-conflict-1');
      expect(failedItem['sync_error'], contains('Stok bahan baku tidak mencukupi'));
    });
  });
}
