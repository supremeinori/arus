import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Pengaturan Kurs & Waktu',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Currency Section
          Text(
            'Mata Uang Tampilan (Multi-Currency)',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih mata uang untuk menampilkan seluruh laporan omzet dan harga produk.',
            style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentCurrency == 'IDR' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'IDR' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('Rupiah Indonesia (IDR)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Format standar: Rp 2.500.000', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'IDR',
                ),
                const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                ListTile(
                  leading: Icon(
                    currentCurrency == 'USD' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'USD' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('Dolar Amerika Serikat (USD)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Format internasional: \$155.00', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayCurrencyProvider.notifier).state = 'USD',
                ),
                const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                ListTile(
                  leading: Icon(
                    currentCurrency == 'EUR' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentCurrency == 'EUR' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('Euro Uni Eropa (EUR)', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Format ekspansi Eropa: € 145.00', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.currency_exchange_rounded, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pratinjau Omzet Toko (Contoh Rp 2.500.000):',
                        style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        convertedPreview,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
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
          Text(
            'Zona Waktu Operasional',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
          ),
          const SizedBox(height: 4),
          Text(
            'Menyesuaikan jam buka, laporan shift kasir, dan penutupan harian per cabang.',
            style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Jakarta' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Jakarta' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('WIB — Waktu Indonesia Barat', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Asia/Jakarta (UTC+7: Jakarta, Jogja, Solo, Surabaya)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jakarta',
                ),
                const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Makassar' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Makassar' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('WITA — Waktu Indonesia Tengah', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Asia/Makassar (UTC+8: Bali, Lombok, Makassar)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Makassar',
                ),
                const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Asia/Jayapura' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Asia/Jayapura' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('WIT — Waktu Indonesia Timur', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Asia/Jayapura (UTC+9: Maluku, Papua)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Asia/Jayapura',
                ),
                const Divider(height: 1, color: AppTheme.borderOutline, thickness: 1),
                ListTile(
                  leading: Icon(
                    currentTimezone == 'Europe/London' ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: currentTimezone == 'Europe/London' ? AppTheme.primaryBlue : const Color(0xFF94A3B8),
                  ),
                  title: Text('BST/GMT — London United Kingdom', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Europe/London (UTC+1: Oxford St, London)', style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B))),
                  onTap: () => ref.read(displayTimezoneProvider.notifier).state = 'Europe/London',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Operasional Saat Ini di Zona Terpilih:',
                        style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timePreview,
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryBlue,
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
