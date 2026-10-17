import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Profil & Akun',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Card with Avatar (Photo / Letter)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
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
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlueBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          user?.role.toDisplayString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
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

          // Keamanan & Sesi Biometrik
          Text(
            'Keamanan & Preferensi Sesi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Login Sidik Jari (Biometrik)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Buka kunci sesi otomatis dengan sensor biometrik HP',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  activeThumbColor: AppTheme.primaryBlue,
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
                  color: AppTheme.borderOutline,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.vibration_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Sensitivitas Guncangan (Shake)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Atur ambang batas getaran refresh (${currentThreshold.toStringAsFixed(1)} m/s²)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
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
                          color: AppTheme.lightBlueBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
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
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  onTap: () => ShakeSettingsSheet.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Outlet Scopes List
          if (user != null && user.outlets.isNotEmpty) ...[
            Text(
              'Akses Outlet Cabang (${user.outlets.length}):',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lexend(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppTheme.accentBlack,
              ),
            ),
            const SizedBox(height: 8),
            // List outlet kecil milik user: dirender langsung via ...map di
            // body ListView (aturan A4) — bukan ListView bersarang.
            ...user.outlets.map(
              (o) => Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.borderOutline,
                    width: 1.0,
                  ),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.storefront_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${o.timezone} • ${o.address ?? "-"}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            'Administrasi & Aplikasi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppTheme.accentBlack,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.people_outline_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Kelola Staf & Akun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Atur hak akses kasir, manager, dan role pengguna',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.lexend(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMuted,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () => context.push('/users'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.borderOutline,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.rate_review_outlined,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Saran & Kesan Kuliah PAM',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Kesan dan saran mata kuliah Pemrograman Aplikasi Mobile (Phase 1)',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.lexend(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMuted,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () => context.push('/feedback'),
                ),
                const Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.borderOutline,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    'Tentang ARUS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  // subtitle: Text(
                  //   'Versi rilis v2.4.0, lisensi, & arsitektur sistem',
                  //   maxLines: 2,
                  //   overflow: TextOverflow.ellipsis,
                  //   style: GoogleFonts.lexend(
                  //     fontSize: 11.5,
                  //     color: AppTheme.textMuted,
                  //   ),
                  // ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(
                      color: AppTheme.borderOutline,
                      width: 1.5,
                    ),
                  ),
                  title: const Text(
                    'Keluar dari Akun?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      'Apakah Anda yakin ingin keluar dari sesi saat ini?',
                      style: GoogleFonts.lexend(fontSize: 13.5),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.lexend(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(
                            color: AppTheme.borderOutline,
                            width: 1,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).logout();
                      },
                      child: Text(
                        'Keluar',
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout, color: AppTheme.dangerRed, size: 18),
            label: Text(
              'Keluar Akun',
              style: GoogleFonts.lexend(
                color: AppTheme.dangerRed,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.dangerRed, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
      ),
      child: Center(
        child: Text(
          initial,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
    );
  }
}
