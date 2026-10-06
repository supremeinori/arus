import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/core/utils/money_formatter.dart';
import 'package:arus/core/utils/timezone_converter.dart';
import 'package:arus/features/settings/domain/currency_models.dart';
import 'package:arus/features/settings/presentation/currency_provider.dart';
import 'package:arus/features/settings/presentation/settings_screen.dart';

void main() {
  group('Currency & Timezone Flow Tests (Milestone 13)', () {
    test('MoneyFormatter mengonversi IDR, USD, dan EUR dengan akurat', () {
      const sampleRates = {
        'USD': 0.000062,
        'EUR': 0.000058,
      };

      final formattedIdr = MoneyFormatter.format(100000, currency: 'IDR');
      expect(formattedIdr, contains('100.000'));

      final formattedUsd = MoneyFormatter.format(100000, currency: 'USD', rates: sampleRates);
      expect(formattedUsd, contains('\$6.20'));

      final formattedEur = MoneyFormatter.format(100000, currency: 'EUR', rates: sampleRates);
      expect(formattedEur, contains('5,80'));
    });

    test('TimezoneConverter menambahkan label dan offset yang sesuai', () {
      final baseUtc = DateTime.utc(2026, 10, 6, 12, 0); // 12:00 UTC

      final wib = TimezoneConverter.formatTime(baseUtc, 'Asia/Jakarta');
      expect(wib, '19:00 WIB'); // +7 jam

      final wita = TimezoneConverter.formatTime(baseUtc, 'Asia/Makassar');
      expect(wita, '20:00 WITA'); // +8 jam

      final london = TimezoneConverter.formatTime(baseUtc, 'Europe/London');
      expect(london, '13:00 BST (London)'); // +1 jam
    });

    testWidgets('SettingsScreen menampilkan radio tile mata uang dan live preview', (tester) async {
      final mockRates = const CurrencyRateModel(
        base: 'IDR',
        asOf: '2026-10-06',
        rates: {'USD': 0.000062, 'EUR': 0.000058},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fxRatesProvider.overrideWith((ref) async => mockRates),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pengaturan Kurs & Waktu'), findsOneWidget);
      expect(find.text('Rupiah Indonesia (IDR)'), findsOneWidget);
      expect(find.text('Dolar Amerika Serikat (USD)'), findsOneWidget);
      expect(find.text('Euro Uni Eropa (EUR)'), findsOneWidget);
      expect(find.text('WIB — Waktu Indonesia Barat'), findsOneWidget);
      expect(find.text('BST/GMT — London United Kingdom'), findsOneWidget);
      expect(find.textContaining('Pratinjau Omzet Toko'), findsOneWidget);
    });
  });
}
