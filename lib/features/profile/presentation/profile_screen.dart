import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/biometric_service.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../sensors/presentation/shake_settings_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentThreshold = ref.watch(shakeThresholdProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Profil & Akun',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Card with Avatar (Photo / Letter)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: Row(
              children: [
                if (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      user.avatarUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _LetterAvatar(user: user),
                    ),
                  )
                else
                  _LetterAvatar(user: user),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Pengguna',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textMutedDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.darkCardBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          user?.role.toDisplayString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.jadeTosca,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Keamanan & Preferensi Sesi
          Text(
            'Pengaturan Sistem & Preferensi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: AppTheme.darkCardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: Column(
              children: [
                // 1. Pengaturan Kurs & Waktu
                ListTile(
                  leading: const Icon(
                    Icons.currency_exchange_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Pengaturan Kurs & Waktu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Multi-currency (IDR, USD, EUR) & zona waktu toko',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMutedDark,
                  ),
                  onTap: () => context.push('/settings'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkCardBorder,
                ),

                // 2. Diagnostik Sensor Hardware
                ListTile(
                  leading: const Icon(
                    Icons.sensors_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Diagnostik Sensor & Biometrik',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Pengujian akselerometer, giroskop & sensor sidik jari',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMutedDark,
                  ),
                  onTap: () => context.push('/sensors'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkCardBorder,
                ),

                // 3. Login Sidik Jari (Biometrik)
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Login Sidik Jari (Biometrik)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Buka kunci sesi otomatis dengan sensor biometrik HP',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  activeThumbColor: AppTheme.jadeTosca,
                  value: user?.settings.biometricEnabled ?? false,
                  onChanged: (val) async {
                    if (val) {
                      final confirmed = await ref
                          .read(biometricServiceProvider)
                          .authenticate(
                            localizedReason: 'Konfirmasi sidik jari atau wajah untuk mengaktifkan biometrik',
                          );
                      if (confirmed) {
                        ref.read(authProvider.notifier).toggleBiometric(true);
                      }
                    } else {
                      ref.read(authProvider.notifier).toggleBiometric(false);
                    }
                  },
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkCardBorder,
                ),

                // 4. Sensitivitas Guncangan (Shake)
                ListTile(
                  leading: const Icon(
                    Icons.vibration_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Sensitivitas Guncangan (Shake)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Atur ambang batas getaran refresh (${currentThreshold.toStringAsFixed(1)} m/s²)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.darkCardBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          currentThreshold <= 4.5
                              ? 'Ringan'
                              : currentThreshold <= 7.5
                              ? 'Sedang'
                              : currentThreshold <= 11.0
                              ? 'Kuat'
                              : 'Sangat Kuat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.jadeTosca,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppTheme.textMutedDark,
                      ),
                    ],
                  ),
                  onTap: () => ShakeSettingsSheet.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Administrasi & Aplikasi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppTheme.textPrimaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: AppTheme.darkCardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.people_outline_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Kelola Staf & Akun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Atur hak akses kasir, manager, dan role pengguna',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.inter(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMutedDark,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMutedDark,
                  ),
                  onTap: () => context.push('/users'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkCardBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.rate_review_outlined,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Saran & Kesan Kuliah PAM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Kesan dan saran mata kuliah Pemrograman Aplikasi Mobile (Phase 1)',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.inter(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMutedDark,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMutedDark,
                  ),
                  onTap: () => context.push('/feedback'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.darkCardBorder,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.jadeTosca,
                  ),
                  title: Text(
                    'Tentang ARUS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Versi rilis v2.4.0, lisensi, & arsitektur sistem',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.inter(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMutedDark,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMutedDark,
                  ),
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final dialog = ShadDialog(
                      title: const Text(
                        'Keluar dari Akun?',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      description: Text(
                        'Apakah Anda yakin ingin keluar dari sesi saat ini?',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
                      ),
                      actions: [
                        ShadButton.ghost(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.inter(color: AppTheme.textMutedDark),
                          ),
                        ),
                        ShadButton.destructive(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(authProvider.notifier).logout();
                          },
                          child: Text(
                            'Keluar',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    );
                    if (ShadTheme.maybeOf(ctx) == null) {
                      return ShadTheme(
                        data: AppTheme.shadcnThemeDark,
                        child: dialog,
                      );
                    }
                    return dialog;
                  },
                );
              },
              leading: const Icon(Icons.logout, color: AppTheme.dangerRed, size: 18),
              child: Text(
                'Keluar Akun',
                style: GoogleFonts.inter(
                  color: AppTheme.dangerRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeDark,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// Avatar huruf depan nama user (aturan E23: widget class const, bukan helper).
class _LetterAvatar extends StatelessWidget {
  final UserModel? user;

  const _LetterAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final u = user;
    final initial = (u != null && u.name.isNotEmpty)
        ? u.name[0].toUpperCase()
        : 'U';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Center(
        child: Text(
          initial,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.jadeTosca,
          ),
        ),
      ),
    );
  }
}
