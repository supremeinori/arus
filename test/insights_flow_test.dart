import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/insights/domain/insight_models.dart';
import 'package:arus/features/insights/presentation/insights_provider.dart';
import 'package:arus/features/insights/presentation/insights_screen.dart';

void main() {
  group('Decision Support Insights Flow Widget Tests (Milestone 8)', () {
    final sampleInsights = [
      BusinessInsightModel(
        id: 'ins-1',
        ruleCode: 'LOW_STOCK',
        severity: 'warning',
        title: 'Stok Menipis: Susu UHT di Outlet Tebet',
        message: 'Sisa stok 2 liter (batas aman minimum: 5 liter).',
        recommendation: 'Segera lakukan pengadaan stok.',
        status: 'new',
        createdAt: DateTime.now(),
      ),
    ];

    testWidgets('InsightsScreen menampilkan rekomendasi dari Rule Engine dan tombol aksi', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            insightsListProvider.overrideWith((ref) async => sampleInsights),
          ],
          child: const MaterialApp(
            home: InsightsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rekomendasi'), findsOneWidget);
      expect(find.text('Stok Menipis: Susu UHT di Outlet Tebet'), findsOneWidget);
      expect(find.text('LOW_STOCK'), findsOneWidget);
      expect(find.textContaining('Rekomendasi: Segera lakukan pengadaan stok.'), findsOneWidget);
      expect(find.text('Tindak Lanjuti'), findsOneWidget);
      expect(find.text('Abaikan'), findsOneWidget);
    });
  });
}
