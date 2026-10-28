import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:arus/core/network/api_client.dart';
import 'package:arus/core/storage/local_db.dart';
import 'package:arus/features/analytics/data/analytics_repository.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/analytics/presentation/analytics_screen.dart';

class MockApiClient extends Fake implements ApiClient {
  final Map<String, dynamic>? Function(String path, {Map<String, dynamic>? queryParameters})? onGet;

  MockApiClient({this.onGet});

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final localDb = LocalDatabase.instance;

  setUp(() async {
    await localDb.clearLocalDatabase();
  });

  group('Phase 4 — Time Series Forecasting & Backtesting Tests', () {
    test('Skenario 1: Online Sales Forecast with Holdout Evaluation parsing', () async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/forecast/sales') {
            return {
              'data': {
                'horizon_days': 7,
                'historical': [
                  {
                    'date': '2026-10-20',
                    'day_name': 'Selasa',
                    'revenue_idr': 100000,
                    'lower_bound_idr': 100000,
                    'upper_bound_idr': 100000,
                    'is_projected': false,
                  },
                  {
                    'date': '2026-10-21',
                    'day_name': 'Rabu',
                    'revenue_idr': 120000,
                    'lower_bound_idr': 120000,
                    'upper_bound_idr': 120000,
                    'is_projected': false,
                  },
                ],
                'forecast': [
                  {
                    'date': '2026-10-22',
                    'day_name': 'Kamis',
                    'revenue_idr': 110000,
                    'lower_bound_idr': 90000,
                    'upper_bound_idr': 130000,
                    'is_projected': true,
                  },
                ],
                'summary': {
                  'projected_total_revenue_idr': 110000,
                  'previous_period_revenue_idr': 220000,
                  'growth_pct': -50.0,
                  'avg_daily_projected_idr': 110000,
                  'peak_projected_day': {
                    'date': '2026-10-22',
                    'day_name': 'Kamis',
                    'revenue_idr': 110000,
                  },
                  'ai_insight': 'Model Seasonal-Trend menunjukkan stabilitas.',
                },
                'evaluation': {
                  'status': 'evaluated',
                  'train_days': 30,
                  'test_days': 7,
                  'seasonal_naive_mae': 25000.0,
                  'model_mae': 18000.0,
                  'chosen_model': 'seasonal_trend',
                },
              }
            };
          }
          return null;
        },
      );

      final repo = AnalyticsRepository(mockClient, localDb);
      final forecast = await repo.getSalesForecast(horizon: 7);

      expect(forecast.horizonDays, 7);
      expect(forecast.historical.length, 2);
      expect(forecast.forecast.length, 1);
      expect(forecast.forecast.first.revenueIdr, 110000);
      expect(forecast.forecast.first.isProjected, isTrue);
      expect(forecast.evaluation, isNotNull);
      expect(forecast.evaluation!.status, 'evaluated');
      expect(forecast.evaluation!.trainDays, 30);
      expect(forecast.evaluation!.testDays, 7);
      expect(forecast.evaluation!.modelMae, 18000.0);
      expect(forecast.evaluation!.seasonalNaiveMae, 25000.0);
      expect(forecast.evaluation!.chosenModel, 'seasonal_trend');
    });

    test('Skenario 2: Online Insufficient History handling without synthetic fabrication', () async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/forecast/sales') {
            return {
              'data': {
                'horizon_days': 7,
                'historical': [
                  {
                    'date': '2026-10-26',
                    'day_name': 'Senin',
                    'revenue_idr': 50000,
                    'lower_bound_idr': 50000,
                    'upper_bound_idr': 50000,
                    'is_projected': false,
                  },
                ],
                'forecast': [
                  {
                    'date': '2026-10-27',
                    'day_name': 'Selasa',
                    'revenue_idr': 50000,
                    'lower_bound_idr': 40000,
                    'upper_bound_idr': 60000,
                    'is_projected': true,
                  },
                ],
                'summary': {
                  'projected_total_revenue_idr': 350000,
                  'previous_period_revenue_idr': 50000,
                  'growth_pct': 0.0,
                  'avg_daily_projected_idr': 50000,
                  'peak_projected_day': {
                    'date': '2026-10-27',
                    'day_name': 'Selasa',
                    'revenue_idr': 50000,
                  },
                  'ai_insight': 'Data historis penjualan belum mencukupi (minimal 3 hari aktif). Menggunakan estimasi rata-rata dasar.',
                },
                'evaluation': {
                  'status': 'insufficient_history',
                  'train_days': 1,
                  'test_days': 0,
                  'seasonal_naive_mae': 0.0,
                  'model_mae': 0.0,
                  'chosen_model': 'naive_mean',
                },
              }
            };
          }
          return null;
        },
      );

      final repo = AnalyticsRepository(mockClient, localDb);
      final forecast = await repo.getSalesForecast(horizon: 7);

      expect(forecast.evaluation?.status, 'insufficient_history');
      expect(forecast.evaluation?.chosenModel, 'naive_mean');
      expect(forecast.summary.aiInsight, contains('minimal 3 hari aktif'));
    });

    test('Skenario 3: Stockout forecast returns empty cleanly when no ingredients exist', () async {
      final mockClient = MockApiClient(
        onGet: (path, {queryParameters}) {
          if (path == '/analytics/forecast/stockout') {
            return {
              'data': {
                'summary': {
                  'critical_count': 0,
                  'warning_count': 0,
                  'safe_count': 0,
                  'total_items': 0,
                  'ai_recommendation': 'Belum ada data bahan baku terdaftar untuk outlet ini.',
                },
                'items': [],
              }
            };
          }
          return null;
        },
      );

      final repo = AnalyticsRepository(mockClient, localDb);
      final stockout = await repo.getStockoutForecast();

      expect(stockout.summary.totalItems, 0);
      expect(stockout.items, isEmpty);
      expect(stockout.summary.aiRecommendation, contains('Belum ada data bahan baku terdaftar'));
    });

    test('Skenario 4: Offline fallback for Sales Forecast with 0 transactions', () async {
      final offlineClient = MockApiClient(onGet: (path, {queryParameters}) => null);
      final repo = AnalyticsRepository(offlineClient, localDb);

      final forecast = await repo.getSalesForecast(horizon: 7);

      expect(forecast.horizonDays, 7);
      expect(forecast.historical.length, 7);
      expect(forecast.forecast.length, 7);
      expect(forecast.summary.projectedTotalRevenueIdr, 0);
      expect(forecast.evaluation?.status, 'offline_insufficient');
      expect(forecast.summary.aiInsight, contains('Mode offline'));
    });

    test('Skenario 5: Offline fallback for Sales Forecast with local transactions', () async {
      final now = DateTime.now();
      // Simpan transaksi di 3 hari berbeda
      for (int i = 1; i <= 3; i++) {
        final txDate = now.subtract(Duration(days: i));
        await localDb.backupTransaction({
          'transaction_id': 'tx-offline-$i',
          'outlet_id': 'out-1',
          'payment_method': 'cash',
          'total_idr': 100000,
          'status': 'completed',
          'created_at': txDate.toIso8601String(),
        });
      }

      final offlineClient = MockApiClient(onGet: (path, {queryParameters}) => null);
      final repo = AnalyticsRepository(offlineClient, localDb);

      final forecast = await repo.getSalesForecast(outletId: 'out-1', horizon: 7);

      expect(forecast.horizonDays, 7);
      expect(forecast.forecast.length, 7);
      expect(forecast.summary.previousPeriodRevenueIdr, 300000);
      expect(forecast.summary.projectedTotalRevenueIdr, greaterThan(0));
      expect(forecast.evaluation?.status, 'offline_local_dow');
      expect(forecast.summary.aiInsight, contains('Mode offline: Proyeksi dihitung'));
    });

    test('Skenario 6: Offline fallback for Stockout Forecast returns safe empty state', () async {
      final offlineClient = MockApiClient(onGet: (path, {queryParameters}) => null);
      final repo = AnalyticsRepository(offlineClient, localDb);

      final stockout = await repo.getStockoutForecast(outletId: 'out-1');

      expect(stockout.summary.totalItems, 0);
      expect(stockout.items, isEmpty);
      expect(stockout.summary.aiRecommendation, contains('Mode offline'));
    });

    testWidgets('Skenario 7: UI renders forecasting view properly without crash', (tester) async {
      final mockModel = SalesForecastModel(
        horizonDays: 7,
        historical: [
          const ForecastPoint(
            date: '2026-10-20',
            dayName: 'Selasa',
            revenueIdr: 100000,
            lowerBoundIdr: 100000,
            upperBoundIdr: 100000,
            isProjected: false,
          ),
          const ForecastPoint(
            date: '2026-10-21',
            dayName: 'Rabu',
            revenueIdr: 150000,
            lowerBoundIdr: 150000,
            upperBoundIdr: 150000,
            isProjected: false,
          ),
        ],
        forecast: [
          const ForecastPoint(
            date: '2026-10-22',
            dayName: 'Kamis',
            revenueIdr: 120000,
            lowerBoundIdr: 100000,
            upperBoundIdr: 140000,
            isProjected: true,
          ),
        ],
        summary: const SalesForecastSummary(
          projectedTotalRevenueIdr: 120000,
          previousPeriodRevenueIdr: 250000,
          growthPct: -52.0,
          avgDailyProjectedIdr: 120000,
          peakProjectedDay: PeakProjectedDay(
            date: '2026-10-22',
            dayName: 'Kamis',
            revenueIdr: 120000,
          ),
          aiInsight: 'Model AI memprediksi tren stabil.',
        ),
        evaluation: const SalesForecastEvaluation(
          status: 'evaluated',
          trainDays: 30,
          testDays: 7,
          chosenModel: 'seasonal_trend',
        ),
      );

      const mockStockout = StockoutForecastModel(
        summary: StockoutSummary(
          criticalCount: 0,
          warningCount: 0,
          safeCount: 1,
          totalItems: 1,
          aiRecommendation: 'Stok bahan baku terpantau aman.',
        ),
        items: [
          StockoutItem(
            ingredientId: 'ing-1',
            ingredientName: 'Biji Kopi Arabika',
            unit: 'gram',
            outletName: 'Outlet Utama',
            currentStock: 5000,
            reorderLevel: 1000,
            dailyVelocity: 100.0,
            daysUntilStockout: 50,
            projectedStockoutDate: '2026-12-16',
            status: 'safe',
            stockCapacityPct: 80,
            recommendedReorderQty: 2000,
            costPerUnitIdr: 200,
            estimatedRestockCostIdr: 400000,
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesForecastProvider.overrideWith((ref) => Future.value(mockModel)),
            stockoutForecastProvider.overrideWith((ref) => Future.value(mockStockout)),
          ],
          child: const ShadApp(
            home: AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Analitik Prediktif'), findsOneWidget);
      expect(find.text('Peramalan Deret Waktu'), findsOneWidget);
      expect(find.text('Estimasi Omzet'), findsOneWidget);
      expect(find.text('Tren Model'), findsOneWidget);
      expect(find.text('Hari Puncak'), findsOneWidget);
      expect(find.text('Grafik Proyeksi Omzet'), findsOneWidget);
      expect(find.text('Rincian Proyeksi Harian'), findsOneWidget);
      expect(find.text('Model AI memprediksi tren stabil.'), findsOneWidget);

      // Switch to Radar Stok Tab
      await tester.tap(find.text('Radar Stok Habis'));
      await tester.pumpAndSettle();

      expect(find.text('Kritis (<3 hari)'), findsOneWidget);
      expect(find.text('Waspada (3-6 hr)'), findsOneWidget);
      expect(find.text('Aman (>7 hari)'), findsOneWidget);
      expect(find.text('Biji Kopi Arabika'), findsOneWidget);
    });
  });
}
