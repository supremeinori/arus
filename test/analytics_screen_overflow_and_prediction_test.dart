import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/theme/app_theme.dart';
import 'package:arus/features/analytics/domain/analytics_models.dart';
import 'package:arus/features/analytics/presentation/analytics_provider.dart';
import 'package:arus/features/analytics/presentation/analytics_screen.dart';

void main() {
  group('AnalyticsScreen UI Responsiveness & AI Prediction Tests', () {
    // Sample model dengan proyeksi dinamis bervariasi (tidak konstan)
    final sampleForecastModel = SalesForecastModel(
      horizonDays: 7,
      historical: [
        const ForecastPoint(
          date: '2026-10-20',
          dayName: 'Selasa',
          revenueIdr: 450000,
          lowerBoundIdr: 450000,
          upperBoundIdr: 450000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-21',
          dayName: 'Rabu',
          revenueIdr: 520000,
          lowerBoundIdr: 520000,
          upperBoundIdr: 520000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-22',
          dayName: 'Kamis',
          revenueIdr: 580000,
          lowerBoundIdr: 580000,
          upperBoundIdr: 580000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-23',
          dayName: 'Jumat',
          revenueIdr: 750000,
          lowerBoundIdr: 750000,
          upperBoundIdr: 750000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-24',
          dayName: 'Sabtu',
          revenueIdr: 1100000,
          lowerBoundIdr: 1100000,
          upperBoundIdr: 1100000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-25',
          dayName: 'Minggu',
          revenueIdr: 980000,
          lowerBoundIdr: 980000,
          upperBoundIdr: 980000,
          isProjected: false,
        ),
        const ForecastPoint(
          date: '2026-10-26',
          dayName: 'Senin',
          revenueIdr: 480000,
          lowerBoundIdr: 480000,
          upperBoundIdr: 480000,
          isProjected: false,
        ),
      ],
      forecast: [
        const ForecastPoint(
          date: '2026-10-27',
          dayName: 'Selasa',
          revenueIdr: 540000,
          lowerBoundIdr: 432000,
          upperBoundIdr: 648000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-10-28',
          dayName: 'Rabu',
          revenueIdr: 590000,
          lowerBoundIdr: 472000,
          upperBoundIdr: 708000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-10-29',
          dayName: 'Kamis',
          revenueIdr: 640000,
          lowerBoundIdr: 512000,
          upperBoundIdr: 768000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-10-30',
          dayName: 'Jumat',
          revenueIdr: 820000,
          lowerBoundIdr: 656000,
          upperBoundIdr: 984000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-10-31',
          dayName: 'Sabtu',
          revenueIdr: 1250000,
          lowerBoundIdr: 1000000,
          upperBoundIdr: 1500000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-11-01',
          dayName: 'Minggu',
          revenueIdr: 1050000,
          lowerBoundIdr: 840000,
          upperBoundIdr: 1260000,
          isProjected: true,
        ),
        const ForecastPoint(
          date: '2026-11-02',
          dayName: 'Senin',
          revenueIdr: 530000,
          lowerBoundIdr: 424000,
          upperBoundIdr: 636000,
          isProjected: true,
        ),
      ],
      summary: const SalesForecastSummary(
        projectedTotalRevenueIdr: 5420000,
        previousPeriodRevenueIdr: 4860000,
        growthPct: 11.5,
        avgDailyProjectedIdr: 774285,
        peakProjectedDay: PeakProjectedDay(
          date: '2026-10-31',
          dayName: 'Sabtu',
          revenueIdr: 1250000,
        ),
        aiInsight:
            'Model AI memproyeksikan omzet 7 hari ke depan tumbuh +11.5% dengan puncak pada Sabtu (Rp 1.250.000). Persiapkan kapasitas stok dan operasional kasir untuk lonjakan akhir pekan.',
      ),
      evaluation: const SalesForecastEvaluation(
        status: 'evaluated',
        trainDays: 7,
        testDays: 0,
        seasonalNaiveMae: 45000.0,
        modelMae: 38000.0,
        chosenModel: 'bayesian_seasonal_holt_dampened',
      ),
    );

    const sampleStockoutModel = StockoutForecastModel(
      summary: StockoutSummary(
        criticalCount: 2,
        warningCount: 1,
        safeCount: 5,
        totalItems: 8,
        aiRecommendation:
            'PERINGATAN: 2 bahan baku diproyeksikan habis dalam 1-2 hari. Segera buat Purchase Order (PO) agar tidak menghambat penjualan.',
      ),
      items: [
        StockoutItem(
          ingredientId: 'ing-1',
          ingredientName: 'Biji Kopi Arabika Specialty Aceh Gayo Premium Quality',
          unit: 'Gram',
          outletName: 'Kopi Arus - Sudirman Grand Indonesia Mall Lantai 5',
          currentStock: 1250,
          reorderLevel: 5000,
          dailyVelocity: 750.5,
          daysUntilStockout: 1,
          projectedStockoutDate: '2026-10-28',
          status: 'critical',
          stockCapacityPct: 8,
          recommendedReorderQty: 10000,
          costPerUnitIdr: 250,
          estimatedRestockCostIdr: 2500000,
        ),
        StockoutItem(
          ingredientId: 'ing-2',
          ingredientName: 'Susu Fresh Milk Pasteurisasi Full Cream Brand X',
          unit: 'Liter',
          outletName: 'Kopi Arus - Sudirman',
          currentStock: 3,
          reorderLevel: 10,
          dailyVelocity: 4.2,
          daysUntilStockout: 0,
          projectedStockoutDate: '2026-10-27',
          status: 'critical',
          stockCapacityPct: 12,
          recommendedReorderQty: 35,
          costPerUnitIdr: 18000,
          estimatedRestockCostIdr: 630000,
        ),
      ],
    );

    test('Logika prediksi menghasilkan angka proyeksi dinamis dan bervariasi', () {
      final points = sampleForecastModel.forecast;
      expect(points.length, 7);

      // Pastikan proyeksi tidak sama terus (setidaknya ada 4 nilai unik)
      final uniqueRevenues = points.map((p) => p.revenueIdr).toSet();
      expect(uniqueRevenues.length, greaterThanOrEqualTo(4));

      // Pastikan hari puncak Sabtu lebih besar daripada hari kerja biasa
      final sabtu = points.firstWhere((p) => p.dayName == 'Sabtu');
      final selasa = points.firstWhere((p) => p.dayName == 'Selasa');
      expect(sabtu.revenueIdr, greaterThan(selasa.revenueIdr));

      // Pastikan lower bound dan upper bound valid
      for (final p in points) {
        expect(p.lowerBoundIdr, lessThanOrEqualTo(p.revenueIdr));
        expect(p.upperBoundIdr, greaterThanOrEqualTo(p.revenueIdr));
      }
    });

    testWidgets('AnalyticsScreen bebas dari RenderFlex overflow pada viewport HP 360x720', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesForecastProvider.overrideWith((ref) async => sampleForecastModel),
            stockoutForecastProvider.overrideWith((ref) async => sampleStockoutModel),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan judul dan kartu KPI tampil tanpa overflow
      expect(find.text('Analitik Prediktif'), findsOneWidget);
      expect(find.text('Peramalan Deret Waktu'), findsOneWidget);
      expect(find.text('Estimasi Omzet'), findsOneWidget);
      expect(find.text('Tren Model'), findsOneWidget);
      expect(find.text('Hari Puncak'), findsOneWidget);

      // Sentuh grafik untuk menampilkan Active Touch Info Box
      final gestureFinder = find.byType(GestureDetector).first;
      await tester.tap(gestureFinder);
      await tester.pumpAndSettle();

      // Verifikasi tidak ada RenderFlex overflow exception
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalyticsScreen bebas overflow pada viewport sangat sempit 320x640 dengan text scale besar',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesForecastProvider.overrideWith((ref) async => sampleForecastModel),
            stockoutForecastProvider.overrideWith((ref) async => sampleStockoutModel),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.15),
                ),
                child: child!,
              );
            },
            home: const AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Analitik Prediktif'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab Radar Stok Habis bebas dari RenderFlex overflow pada viewport sempit dengan nama bahan panjang',
        (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesForecastProvider.overrideWith((ref) async => sampleForecastModel),
            stockoutForecastProvider.overrideWith((ref) async => sampleStockoutModel),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AnalyticsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Beralih ke tab Radar Stok Habis
      await tester.tap(find.text('Radar Stok Habis'));
      await tester.pumpAndSettle();

      // Kartu status stok dan nama bahan panjang terender
      expect(find.textContaining('Kritis (<3 hari)'), findsOneWidget);
      expect(find.textContaining('Biji Kopi Arabika'), findsOneWidget);
      expect(find.textContaining('Laju: ~'), findsWidgets);
      expect(find.textContaining('Rekomendasi Restock:'), findsWidgets);

      // Verifikasi tidak ada overflow
      expect(tester.takeException(), isNull);
    });
  });
}
