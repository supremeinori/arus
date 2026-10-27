import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/timezone_converter.dart';
import '../currency_provider.dart';

/// Jam UTC snapshot (aturan E21: DateTime.now tidak boleh menentukan struktur
/// di dalam build — sumber jam terpusat di provider ini, bukan di build()).
/// Disengaja snapshot sekali (bukan stream periodik) agar tidak ada timer
/// pending di widget test; refresh via pull/rebuild atau invalidate provider.
final settingsClockProvider = StateProvider<DateTime>((ref) {
  return DateTime.now().toUtc();
});

/// Section pengaturan waktu: zona waktu operasional + pratinjau jam saat ini.
///
/// Dipisah dari [CurrencySettingsSection] supaya tiap domain pengaturan punya
/// widget mandiri (aturan E23: widget class, bukan helper method).
class TimeSettingsSection extends ConsumerWidget {
  const TimeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTimezone = ref.watch(displayTimezoneProvider);
    final nowUtc = ref.watch(settingsClockProvider);
    final timePreview = TimezoneConverter.formatTime(nowUtc, currentTimezone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Zona Waktu Operasional
        Text(
          'Zona Waktu Operasional',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textPrimaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Menyesuaikan jam buka, laporan shift kasir, dan penutupan harian per cabang.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMutedDark,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: AppTheme.darkCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: AppTheme.darkCardBorder,
              width: AppTheme.hairline,
            ),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  currentTimezone == 'Asia/Jakarta'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentTimezone == 'Asia/Jakarta'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'WIB — Waktu Indonesia Barat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Asia/Jakarta (UTC+7: Jakarta, Jogja, Solo, Surabaya)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayTimezoneProvider.notifier).state =
                        'Asia/Jakarta',
              ),
              const Divider(
                height: 1,
                color: AppTheme.darkCardBorder,
                thickness: 1,
              ),
              ListTile(
                leading: Icon(
                  currentTimezone == 'Asia/Makassar'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentTimezone == 'Asia/Makassar'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'WITA — Waktu Indonesia Tengah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Asia/Makassar (UTC+8: Bali, Lombok, Makassar)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayTimezoneProvider.notifier).state =
                        'Asia/Makassar',
              ),
              const Divider(
                height: 1,
                color: AppTheme.darkCardBorder,
                thickness: 1,
              ),
              ListTile(
                leading: Icon(
                  currentTimezone == 'Asia/Jayapura'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentTimezone == 'Asia/Jayapura'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'WIT — Waktu Indonesia Timur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Asia/Jayapura (UTC+9: Maluku, Papua)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayTimezoneProvider.notifier).state =
                        'Asia/Jayapura',
              ),
              const Divider(
                height: 1,
                color: AppTheme.darkCardBorder,
                thickness: 1,
              ),
              ListTile(
                leading: Icon(
                  currentTimezone == 'Europe/London'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: currentTimezone == 'Europe/London'
                      ? AppTheme.jadeTosca
                      : AppTheme.textMutedDark,
                ),
                title: Text(
                  'BST/GMT — London United Kingdom',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Europe/London (UTC+1: Oxford St, London)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                onTap: () =>
                    ref.read(displayTimezoneProvider.notifier).state =
                        'Europe/London',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCardSurfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.jadeTosca.withAlpha(120),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: AppTheme.jadeTosca,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jam Operasional Saat Ini di Zona Terpilih:',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textMutedDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.jadeTosca,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
