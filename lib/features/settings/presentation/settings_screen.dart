import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/auth/biometric_service.dart';
import '../../auth/presentation/auth_provider.dart';
import 'widgets/currency_settings_section.dart';
import 'widgets/time_settings_section.dart';

/// Layar gabungan pengaturan (kurs + waktu + keamanan).
///
/// Isi tiap domain dipecah ke widget terpisah supaya bisa dipakai ulang oleh
/// layar tunggal masing-masing: [CurrencySettingsSection] dan
/// [TimeSettingsSection].
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Pengaturan Kurs & Waktu',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CurrencySettingsSection(),
            const SizedBox(height: 24),
            const TimeSettingsSection(),
            const SizedBox(height: 24),
            // Section 4: Keamanan & Autentikasi Biometrik
            Text(
              'Keamanan & Akses Cepat',
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
              'Kelola autentikasi sidik jari/wajah dan kunci layar otomatis setelah 5 menit di background.',
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
                  width: 1.0,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppTheme.jadeTosca,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Login Biometrik',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                subtitle: Text(
                  'Buka kunci dengan sidik jari/wajah & kunci otomatis 5 menit.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                activeThumbColor: AppTheme.jadeTosca,
                value:
                    ref.watch(authProvider).user?.settings.biometricEnabled ??
                    false,
                onChanged: (enabled) async {
                  if (enabled) {
                    final bioService = ref.read(biometricServiceProvider);
                    final available = await bioService.isBiometricAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppTheme.dangerRed,
                            content: Text(
                              'Sensor biometrik tidak tersedia atau belum didaftarkan di perangkat ini.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final confirmed = await bioService.authenticate(
                      localizedReason: 'Konfirmasi sidik jari atau wajah untuk mengaktifkan login biometrik',
                    );
                    if (confirmed && context.mounted) {
                      await ref
                          .read(authProvider.notifier)
                          .toggleBiometric(true);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.jadeTosca,
                          content: Text(
                            'Login biometrik berhasil diaktifkan.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                      );
                    }
                  } else {
                    await ref
                        .read(authProvider.notifier)
                        .toggleBiometric(false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.darkCardSurfaceElevated,
                          content: Text(
                            'Login biometrik dinonaktifkan.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
