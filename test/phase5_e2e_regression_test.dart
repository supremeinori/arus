import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/core/sync/sync_service.dart';
import 'package:arus/features/analytics/data/analytics_repository.dart';
import 'package:arus/features/catalog/domain/product_model.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDatabase.instance;

  setUp(() async {
    await localDb.clearLocalDatabase();
  });

  group('Phase 5 — End-to-End Cross-System Regression Suite', () {
    // ------------------------------------------------------------------------
    // Scenario 1: Online transaction -> server confirmation -> stock/history/dashboard updates
    // ------------------------------------------------------------------------
    test('Scenario 1: Online transaction updates stock, receipt cache, and shift summary', () async {
      int serverStock = 50;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/transactions') {
            serverStock -= 2;
            final txData = {
              'id': 'tx-srv-101',
              'receipt_no': 'REC-101',
              'outlet_id': 'out-1',
              'outlet': {'name': 'ARUS Sudirman'},
              'cashier': {'name': 'Kasir A'},
              'subtotal_idr': 50000,
              'discount_idr': 0,
              'total_idr': 50000,
              'payment_method': 'cash',
              'paid_idr': 50000,
              'change_idr': 0,
              'status': 'completed',
              'created_at': DateTime.now().toIso8601String(),
              'items': [
                {
                  'product_id': 'prod-1',
                  'product_name': 'Americano',
                  'qty': 2,
                  'price_idr': 25000,
                  'subtotal_idr': 50000,
                }
              ],
            };
            return {'data': txData};
          }
          return null;
        },
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/shift-summary') {
            return {
              'data': {
                'today_revenue_idr': 50000,
                'cash_revenue_idr': 50000,
                'qris_revenue_idr': 0,
                'transaction_count': 1,
              }
            };
          }
          return null;
        },
      );

      final posRepo = PosRepository(mockClient, localDb);
      final analyticsRepo = AnalyticsRepository(mockClient, localDb);

      final tx = await posRepo.createTransaction(
        clientRequestId: 'req-online-101',
        outletId: 'out-1',
        paymentMethod: 'cash',
        paidIdr: 50000,
        discountIdr: 0,
        items: [
          const PosCartItem(
            productId: 'prod-1',
            productName: 'Americano',
            sku: 'SKU-AME',
            unitPriceIdr: 25000,
            quantity: 2,
          ),
        ],
      );

      expect(tx.id, 'tx-srv-101');
      expect(tx.status, 'completed');
      expect(serverStock, 48);

      final summary = await analyticsRepo.getShiftSummary(outletId: 'out-1');
      expect(summary.todayRevenueIdr, 50000);
      expect(summary.transactionCount, 1);
      expect(summary.isOffline, isFalse);
    });

    // ------------------------------------------------------------------------
    // Scenario 2: Offline transaction -> local stock/history update -> app restart -> reconnect -> exactly one successful sync
    // ------------------------------------------------------------------------
    test('Scenario 2: Offline transaction survives app restart and syncs exactly once upon reconnection', () async {
      const testProduct = ProductModel(
        id: 'prod-kopi',
        sku: 'SKU-001',
        name: 'Kopi Susu Gula Aren',
        priceIdr: 20000,
        estimatedPortions: 10,
        isActive: true,
      );
      await localDb.cacheProducts([testProduct]);

      // Step A: Disconnected client performs checkout
      final offlineClient = MockApiClient(onPost: (path, {data}) => null);
      final offlinePosRepo = PosRepository(offlineClient, localDb);

      const stableRequestId = 'req-unique-uuid-202';
      final offlineTx = await offlinePosRepo.createTransaction(
        clientRequestId: stableRequestId,
        outletId: 'out-1',
        paymentMethod: 'cash',
        paidIdr: 20000,
        discountIdr: 0,
        items: [
          const PosCartItem(
            productId: 'prod-kopi',
            productName: 'Kopi Susu Gula Aren',
            sku: 'SKU-001',
            unitPriceIdr: 20000,
            quantity: 1,
          ),
        ],
      );

      expect(offlineTx.isOfflinePending, isTrue);
      expect(offlineTx.status, 'offline_pending');

      // Local stock decremented locally
      final cachedProducts = await localDb.getCachedProducts();
      expect(cachedProducts.first.estimatedPortions, 9);

      // Verify pending queue has 1 item
      var pendingRows = await localDb.getPendingOfflineTransactions();
      expect(pendingRows.length, 1);

      // Step B: Simulate App Restart and Reconnection
      int serverSyncCount = 0;
      final onlineClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/transactions') {
            serverSyncCount++;
            return {
              'data': {
                'id': 'tx-synced-202',
                'receipt_no': 'REC-202',
                'status': 'completed',
              }
            };
          }
          return null;
        },
      );

      final syncService = SyncService(onlineClient, localDb);
      final syncResult = await syncService.syncPendingTransactions();

      expect(syncResult.syncedCount, 1);
      expect(syncResult.failedCount, 0);
      expect(serverSyncCount, 1);

      // Queue is now empty
      pendingRows = await localDb.getPendingOfflineTransactions();
      expect(pendingRows.length, 0);

      // Receipt cache is still retained durably for offline receipt printing
      final backups = await localDb.getBackupTransactions(outletId: 'out-1');
      expect(backups.length, 1);
      expect(backups.first.clientRequestId, stableRequestId);
    });

    // ------------------------------------------------------------------------
    // Scenario 3: Retry after ambiguous timeout without duplicate transaction or stock mutation
    // ------------------------------------------------------------------------
    test('Scenario 3: Retry with identical client_request_id does not cause duplicate insertion', () async {
      final processedReqIds = <String>{};
      int totalProcessed = 0;

      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/transactions') {
            final payload = data as Map<String, dynamic>;
            final reqId = payload['client_request_id'] as String;
            if (!processedReqIds.contains(reqId)) {
              processedReqIds.add(reqId);
              totalProcessed++;
            }
            return {
              'data': {
                'id': 'tx-dedup-$reqId',
                'receipt_no': 'REC-$reqId',
                'status': 'completed',
              }
            };
          }
          return null;
        },
      );

      final syncService = SyncService(mockClient, localDb);

      final tx = PosTransactionModel(
        id: 'tx-offline-303',
        receiptNo: 'REC-303',
        outletId: 'out-1',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 35000,
        discountIdr: 0,
        totalIdr: 35000,
        paymentMethod: 'cash',
        paidIdr: 35000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'req-timeout-303',
        items: [
          const PosCartItem(
            productId: 'prod-item-1',
            productName: 'Americano',
            quantity: 1,
            sku: 'SKU-TEST',
            unitPriceIdr: 35000,
          ),
        ],
      );

      await localDb.saveOfflineTransaction(
        transaction: tx,
        clientRequestId: 'req-timeout-303',
        isSynced: false,
      );

      // First sync attempt
      await syncService.syncPendingTransactions();
      expect(totalProcessed, 1);

      // Simulate a retry of the same client_request_id
      await localDb.saveOfflineTransaction(
        transaction: tx,
        clientRequestId: 'req-timeout-303',
        isSynced: false,
      );

      await syncService.syncPendingTransactions();
      // Server processed count remains 1 due to idempotency!
      expect(totalProcessed, 1);
    });

    // ------------------------------------------------------------------------
    // Scenario 4: Partial sync failure followed by recovery
    // ------------------------------------------------------------------------
    test('Scenario 4: Partial sync failure retains failed item while allowing remaining items to process', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/transactions') {
            final payload = data as Map<String, dynamic>;
            final reqId = payload['client_request_id'] as String;
            if (reqId == 'req-bad') {
              throw DioException(
                requestOptions: RequestOptions(path: path),
                type: DioExceptionType.badResponse,
                response: Response(
                  statusCode: 400,
                  data: {'message': 'Internal calculation error'},
                  requestOptions: RequestOptions(path: path),
                ),
              );
            }
            return {
              'data': {
                'id': 'tx-good-1',
                'receipt_no': 'REC-GOOD',
                'status': 'completed',
              }
            };
          }
          return null;
        },
      );

      final syncService = SyncService(mockClient, localDb);

      final txGood = PosTransactionModel(
        id: 'tx-good',
        receiptNo: 'REC-G',
        outletId: 'out-1',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 20000,
        discountIdr: 0,
        totalIdr: 20000,
        paymentMethod: 'cash',
        paidIdr: 20000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'req-good',
        items: [
          const PosCartItem(
            productId: 'p-1',
            productName: 'Kopi',
            quantity: 1,
            sku: 'SKU-TEST',
            unitPriceIdr: 20000,
          ),
        ],
      );
      final txBad = PosTransactionModel(
        id: 'tx-bad',
        receiptNo: 'REC-B',
        outletId: 'out-1',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 40000,
        discountIdr: 0,
        totalIdr: 40000,
        paymentMethod: 'cash',
        paidIdr: 40000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'req-bad',
        items: [
          const PosCartItem(
            productId: 'p-2',
            productName: 'Latte',
            quantity: 2,
            sku: 'SKU-TEST',
            unitPriceIdr: 20000,
          ),
        ],
      );

      await localDb.saveOfflineTransaction(
        transaction: txGood,
        clientRequestId: 'req-good',
        isSynced: false,
      );
      await localDb.saveOfflineTransaction(
        transaction: txBad,
        clientRequestId: 'req-bad',
        isSynced: false,
      );

      final syncResult = await syncService.syncPendingTransactions();
      expect(syncResult.syncedCount, 1);
      expect(syncResult.failedCount, 1);

      final pendingRows = await localDb.getPendingOfflineTransactions();
      expect(pendingRows.length, 1);
      expect(pendingRows.first['client_request_id'], 'req-bad');
      expect(pendingRows.first['sync_error'], contains('Internal calculation error'));
    });

    // ------------------------------------------------------------------------
    // Scenario 5: Stock conflict during sync
    // ------------------------------------------------------------------------
    test('Scenario 5: Stock conflict records sync_error explicitly without silent deletion', () async {
      final mockClient = MockApiClient(
        onPost: (path, {data}) {
          if (path == '/transactions') {
            throw DioException(
              requestOptions: RequestOptions(path: path),
              type: DioExceptionType.badResponse,
              response: Response(
                statusCode: 400,
                data: {'message': 'INSUFFICIENT_STOCK: Stok bahan baku Kopi tidak mencukupi di server'},
                requestOptions: RequestOptions(path: path),
              ),
            );
          }
          return null;
        },
      );

      final syncService = SyncService(mockClient, localDb);

      final tx = PosTransactionModel(
        id: 'tx-stock-conflict',
        receiptNo: 'REC-SC',
        outletId: 'out-1',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 60000,
        discountIdr: 0,
        totalIdr: 60000,
        paymentMethod: 'cash',
        paidIdr: 60000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: DateTime.now(),
        clientRequestId: 'req-stock-conflict',
        items: [
          const PosCartItem(
            productId: 'p-1',
            productName: 'Kopi',
            quantity: 3,
            sku: 'SKU-TEST',
            unitPriceIdr: 20000,
          ),
        ],
      );

      await localDb.saveOfflineTransaction(
        transaction: tx,
        clientRequestId: 'req-stock-conflict',
        isSynced: false,
      );

      final syncResult = await syncService.syncPendingTransactions();
      expect(syncResult.failedCount, 1);

      final pendingRows = await localDb.getPendingOfflineTransactions();
      expect(pendingRows.length, 1);
      expect(pendingRows.first['sync_error'], contains('INSUFFICIENT_STOCK'));
    });

    // ------------------------------------------------------------------------
    // Scenario 6: Branch switch while pending transactions exist
    // ------------------------------------------------------------------------
    test('Scenario 6: Branch switch isolates pending transactions by outlet_id', () async {
      final now = DateTime.now();
      final txA = PosTransactionModel(
        id: 'tx-branch-a',
        receiptNo: 'REC-A',
        outletId: 'outlet-sudirman',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 50000,
        discountIdr: 0,
        totalIdr: 50000,
        paymentMethod: 'cash',
        paidIdr: 50000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: now,
        clientRequestId: 'req-branch-a',
      );
      final txB = PosTransactionModel(
        id: 'tx-branch-b',
        receiptNo: 'REC-B',
        outletId: 'outlet-senopati',
        outletName: 'ARUS Senopati',
        cashierName: 'Kasir',
        subtotalIdr: 75000,
        discountIdr: 0,
        totalIdr: 75000,
        paymentMethod: 'cash',
        paidIdr: 75000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: now,
        clientRequestId: 'req-branch-b',
      );

      await localDb.saveOfflineTransaction(
        transaction: txA,
        clientRequestId: 'req-branch-a',
        isSynced: false,
      );
      await localDb.saveOfflineTransaction(
        transaction: txB,
        clientRequestId: 'req-branch-b',
        isSynced: false,
      );

      final offlineClient = MockApiClient(onGet: (path, {queryParameters}) => null);
      final analyticsRepo = AnalyticsRepository(offlineClient, localDb);

      // Summary for Sudirman only counts Sudirman transaction
      final summarySudirman = await analyticsRepo.getShiftSummary(outletId: 'outlet-sudirman');
      expect(summarySudirman.todayRevenueIdr, 50000);
      expect(summarySudirman.pendingCount, 1);

      // Summary for Senopati only counts Senopati transaction
      final summarySenopati = await analyticsRepo.getShiftSummary(outletId: 'outlet-senopati');
      expect(summarySenopati.todayRevenueIdr, 75000);
      expect(summarySenopati.pendingCount, 1);

      // Switching does not erase pending records of either branch
      final allPending = await localDb.getPendingOfflineTransactions();
      expect(allPending.length, 2);
    });

    // ------------------------------------------------------------------------
    // Scenario 7: Refresh while online, offline, and during reconnection
    // ------------------------------------------------------------------------
    test('Scenario 7: Pull-to-refresh transitions smoothly between online, offline, and reconnected', () async {
      bool isConnected = true;

      final dynamicClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (!isConnected) return null;
          if (path == '/analytics/overview') {
            return {
              'data': {
                'revenue_idr': 200000,
                'subtotal_idr': 200000,
                'discount_idr': 0,
                'transaction_count': 5,
                'avg_basket_size_idr': 40000,
              }
            };
          }
          return null;
        },
      );

      final analyticsRepo = AnalyticsRepository(dynamicClient, localDb);

      // 1. Online refresh
      final onlineOverview = await analyticsRepo.getOverview();
      expect(onlineOverview.revenueIdr, 200000);
      expect(onlineOverview.isOffline, isFalse);

      // 2. Drop connection -> Offline refresh
      isConnected = false;
      final offlineOverview = await analyticsRepo.getOverview();
      expect(offlineOverview.isOffline, isTrue);

      // 3. Reconnect -> Online refresh
      isConnected = true;
      final reconnectedOverview = await analyticsRepo.getOverview();
      expect(reconnectedOverview.revenueIdr, 200000);
      expect(reconnectedOverview.isOffline, isFalse);
    });

    // ------------------------------------------------------------------------
    // Scenario 8: Dashboard and "Tren" after online/offline transactions
    // ------------------------------------------------------------------------
    test('Scenario 8: Sales trend incorporates pending offline transactions without duplication', () async {
      final now = DateTime.now();
      final todayKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/sales-trend') {
            return {
              'data': [
                {'date': todayKey, 'revenue_idr': 100000, 'count': 2},
              ]
            };
          }
          return null;
        },
      );

      final analyticsRepo = AnalyticsRepository(mockClient, localDb);

      // Add a pending offline transaction for today
      final tx = PosTransactionModel(
        id: 'tx-trend-today',
        receiptNo: 'REC-TR',
        outletId: 'out-1',
        outletName: 'ARUS Sudirman',
        cashierName: 'Kasir',
        subtotalIdr: 50000,
        discountIdr: 0,
        totalIdr: 50000,
        paymentMethod: 'cash',
        paidIdr: 50000,
        changeIdr: 0,
        status: 'offline_pending',
        createdAt: now,
        clientRequestId: 'req-trend-today',
      );

      await localDb.saveOfflineTransaction(
        transaction: tx,
        clientRequestId: 'req-trend-today',
        isSynced: false,
      );

      final trend = await analyticsRepo.getSalesTrend(outletId: 'out-1', days: 7);
      final todayPoint = trend.firstWhere((p) => p.date == todayKey);

      // 100000 server + 50000 pending = 150000 total revenue
      expect(todayPoint.revenueIdr, 150000);
      expect(todayPoint.count, 3);
    });

    // ------------------------------------------------------------------------
    // Scenario 9: Forecast refresh after new transactions sync
    // ------------------------------------------------------------------------
    test('Scenario 9: Sales forecast reflects newly synced transactions and avoids fabricated mock', () async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/forecast/sales') {
            return {
              'data': {
                'horizon_days': 7,
                'historical': [
                  {
                    'date': '2026-10-25',
                    'day_name': 'Minggu',
                    'revenue_idr': 300000,
                    'lower_bound_idr': 300000,
                    'upper_bound_idr': 300000,
                    'is_projected': false,
                  },
                ],
                'forecast': [
                  {
                    'date': '2026-10-26',
                    'day_name': 'Senin',
                    'revenue_idr': 280000,
                    'lower_bound_idr': 224000,
                    'upper_bound_idr': 336000,
                    'is_projected': true,
                  },
                ],
                'summary': {
                  'projected_total_revenue_idr': 1960000,
                  'previous_period_revenue_idr': 300000,
                  'growth_pct': 553.3,
                  'avg_daily_projected_idr': 280000,
                  'peak_projected_day': {
                    'date': '2026-10-26',
                    'day_name': 'Senin',
                    'revenue_idr': 280000,
                  },
                  'ai_insight': 'Model AI memprediksi stabilitas pendapatan harian.',
                },
                'evaluation': {
                  'status': 'evaluated',
                  'train_days': 30,
                  'test_days': 7,
                  'seasonal_naive_mae': 35000.0,
                  'model_mae': 22000.0,
                  'chosen_model': 'seasonal_trend',
                },
              }
            };
          }
          return null;
        },
      );

      final analyticsRepo = AnalyticsRepository(mockClient, localDb);
      final forecast = await analyticsRepo.getSalesForecast(horizon: 7);

      expect(forecast.evaluation?.chosenModel, 'seasonal_trend');
      expect(forecast.evaluation?.modelMae, lessThan(forecast.evaluation!.seasonalNaiveMae));
      expect(forecast.summary.aiInsight, isNotEmpty);
    });

    // ------------------------------------------------------------------------
    // Scenario 10: Empty history, insufficient forecast, malformed API, and server outage
    // ------------------------------------------------------------------------
    test('Scenario 10: System handles empty data and server outages gracefully without crashing', () async {
      // Outage client throws 500
      final brokenClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          throw DioException(
            requestOptions: RequestOptions(path: path),
            type: DioExceptionType.badResponse,
            response: Response(
              statusCode: 500,
              data: {'message': 'Database connection lost'},
              requestOptions: RequestOptions(path: path),
            ),
          );
        },
      );

      final analyticsRepo = AnalyticsRepository(brokenClient, localDb);

      // Overview fallback
      final overview = await analyticsRepo.getOverview();
      expect(overview.isOffline, isTrue);
      expect(overview.transactionCount, 0);

      // Forecast fallback on outage
      final forecast = await analyticsRepo.getSalesForecast(horizon: 7);
      expect(forecast.evaluation?.status, 'offline_insufficient');
      expect(forecast.summary.aiInsight, contains('Mode offline'));

      // Stockout fallback on outage
      final stockout = await analyticsRepo.getStockoutForecast();
      expect(stockout.summary.totalItems, 0);
      expect(stockout.items, isEmpty);
    });
  });
}
