import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/timezone_converter.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/presentation/auth_provider.dart';
import 'currency_provider.dart';

/// Hub pengaturan aplikasi: kurs, zona waktu, dan keamanan biometrik.
///
/// Layar ini hanya memuat pintu masuk ketiga domain tersebut. Rinciannya ada di
/// layar masing-masing (`/settings/currency` dan `/settings/time`) supaya daftar
/// pengaturan tetap pendek, sementara nilai aktif tiap domain langsung terbaca
/// dari chip di sisi kanan baris.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(displayCurrencyProvider);
    final timezone = ref.watch(displayTimezoneProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Pengaturan',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SettingsSectionLabel('Tampilan & Waktu'),
            const SizedBox(height: 8),
            SettingsSectionCard(
              children: [
                SettingsNavTile(
                  icon: Icons.payments_outlined,
                  title: 'Pengaturan Kurs',
                  subtitle: 'Mata uang tampilan, kalkulator, & pratinjau omzet',
                  onTap: () => context.push('/settings/currency'),
                  trailing: SettingsValueChip(
                    label: currency,
                    icon: Icons.attach_money_rounded,
                  ),
                ),
                const SettingsTileDivider(),
                SettingsNavTile(
                  icon: Icons.schedule_outlined,
                  title: 'Pengaturan Waktu',
                  subtitle: 'Zona waktu operasional & jam toko',
                  onTap: () => context.push('/settings/time'),
                  trailing: SettingsValueChip(
                    label: TimezoneConverter.getSuffix(timezone),
                    icon: Icons.public_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionLabel('Keamanan & Akses Cepat'),
            const SizedBox(height: 4),
            Text(
              'Kelola autentikasi sidik jari/wajah dan kunci layar otomatis setelah 5 menit di background.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMutedDark),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              children: [
                SwitchListTile(
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
                    'Login Sidik Jari (Biometrik)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryDark,
                        ),
                  ),
                  subtitle: Text(
                    'Buka kunci dengan sidik jari/wajah & kunci otomatis 5 menit.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMutedDark),
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
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final confirmed = await bioService.authenticate(
                        localizedReason:
                            'Konfirmasi sidik jari atau wajah untuk mengaktifkan login biometrik',
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
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
