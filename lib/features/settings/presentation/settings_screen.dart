import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/timezone_converter.dart';
import 'currency_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCurrency = ref.watch(displayCurrencyProvider);
    final currentTimezone = ref.watch(displayTimezoneProvider);
    final ratesAsync = ref.watch(fxRatesProvider);

    final rates = ratesAsync.value?.rates;

    const sampleOmzetIdr = 2500000;
    final convertedPreview = MoneyFormatter.format(
      sampleOmzetIdr,
      currency: currentCurrency,
      rates: rates,
    );

    final nowUtc = DateTime.now().toUtc();
    final timePreview = TimezoneConverter.formatTime(nowUtc, currentTimezone);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Kurs & Waktu'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Currency Section
          const Text(
            'Mata Uang Tampilan (Multi-Currency)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih mata uang untuk menampilkan seluruh laporan omzet dan harga produk.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentCurrency == 'IDR' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'IDR' ? AppTheme.primaryBlue : Colors.grey,
                  ),
                  title: const Text('Rupiah Indonesia (IDR)'),
                  subtitle: const Text('Format standar: Rp 2.500.000'),
                  onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'IDR',
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    currentCurrency == 'USD' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'USD' ? AppTheme.primaryBlue : Colors.grey,
                  ),
                  title: const Text('Dolar Amerika Serikat (USD)'),
                  subtitle: const Text('Format internasional: \$155.00'),
                  onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'USD',
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    currentCurrency == 'EUR' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'EUR' ? AppTheme.primaryBlue : Colors.grey,
                  ),
                  title: const Text('Euro Uni Eropa (EUR)'),
                  subtitle: const Text('Format ekspansi Eropa: € 145.00'),
                  onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'EUR',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Live Preview Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pratinjau Omzet Toko (Contoh Rp 2.500.000):',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        convertedPreview,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Timezone Section
          const Text(
            'Zona Waktu Operasional',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Menyesuaikan jam buka, laporan shift kasir, dan penutupan harian per cabang.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Jakarta' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Jakarta' ? Colors.teal : Colors.grey,
                  ),
                  title: const Text('WIB — Waktu Indonesia Barat'),
                  subtitle: const Text('Asia/Jakarta (UTC+7: Jakarta, Jogja, Solo, Surabaya)'),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jakarta',
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Makassar' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Makassar' ? Colors.teal : Colors.grey,
                  ),
                  title: const Text('WITA — Waktu Indonesia Tengah'),
                  subtitle: const Text('Asia/Makassar (UTC+8: Bali, Lombok, Makassar)'),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Makassar',
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Jayapura' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Jayapura' ? Colors.teal : Colors.grey,
                  ),
                  title: const Text('WIT — Waktu Indonesia Timur'),
                  subtitle: const Text('Asia/Jayapura (UTC+9: Maluku, Papua)'),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jayapura',
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Europe/London' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Europe/London' ? Colors.teal : Colors.grey,
                  ),
                  title: const Text('BST/GMT — London United Kingdom'),
                  subtitle: const Text('Europe/London (UTC+1: Oxford St, London)'),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Europe/London',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Colors.teal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jam Operasional Saat Ini di Zona Terpilih:',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timePreview,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
