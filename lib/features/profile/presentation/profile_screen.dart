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
import '../../shell/presentation/main_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const _menuDivider = Divider(
    height: 1,
    indent: 56,
    color: AppTheme.darkCardBorder,
  );

  String _getThresholdLabel(double threshold) {
    if (threshold <= 4.5) return 'Ringan';
    if (threshold <= 7.5) return 'Sedang';
    if (threshold <= 11.0) return 'Kuat';
    return 'Sangat Kuat';
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
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
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textMutedDark,
            ),
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
                ref.read(shellTabIndexProvider.notifier).state = 0;
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
          return ShadTheme(data: AppTheme.shadcnThemeLight, child: dialog);
        }
        return dialog;
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentThreshold = ref.watch(shakeThresholdProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Profil',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Header Pengguna & Avatar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _UserAvatar(user: user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Pengguna',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      if (user?.email != null && user!.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        user?.role.toDisplayString() ?? 'Pengguna',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.jadeTosca,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Kartu Keamanan & Preferensi Sesi
          _SectionCard(
            children: [
              _ProfileMenuTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Pengaturan Kurs & Waktu',
                onTap: () => context.push('/settings'),
              ),
              _menuDivider,
              _ProfileMenuTile(
                icon: Icons.sensors_rounded,
                title: 'Diagnostik Sensor & Biometrik',
                onTap: () => context.push('/sensors'),
              ),
              _menuDivider,
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
                activeThumbColor: AppTheme.jadeTosca,
                value: user?.settings.biometricEnabled ?? false,
                onChanged: (val) async {
                  if (val) {
                    final confirmed = await ref
                        .read(biometricServiceProvider)
                        .authenticate(
                          localizedReason:
                              'Konfirmasi sidik jari atau wajah untuk mengaktifkan biometrik',
                        );
                    if (confirmed) {
                      ref.read(authProvider.notifier).toggleBiometric(true);
                    }
                  } else {
                    ref.read(authProvider.notifier).toggleBiometric(false);
                  }
                },
              ),
              _menuDivider,
              _ProfileMenuTile(
                icon: Icons.vibration_rounded,
                title: 'Sensitivitas Guncangan (Shake)',
                onTap: () => ShakeSettingsSheet.show(context),
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
                        _getThresholdLabel(currentThreshold),
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
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Kartu Administrasi & Aplikasi
          _SectionCard(
            children: [
              _ProfileMenuTile(
                icon: Icons.people_outline_rounded,
                title: 'Kelola Staf & Akun',
                onTap: () => context.push('/users'),
              ),
              _menuDivider,
              _ProfileMenuTile(
                icon: Icons.rate_review_outlined,
                title: 'Saran & Kesan Kuliah PAM',
                onTap: () => context.push('/feedback'),
              ),
              _menuDivider,
              _ProfileMenuTile(
                icon: Icons.info_outline_rounded,
                title: 'Tentang ARUS',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Tombol Logout
          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              onPressed: () => _showLogoutDialog(context, ref),
              leading: const Icon(
                Icons.logout,
                color: AppTheme.dangerRed,
                size: 18,
              ),
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
      return ShadTheme(data: AppTheme.shadcnThemeLight, child: scaffold);
    }
    return scaffold;
  }
}

/// Kartu kontainer bergaya section profil (aturan E23).
class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.darkCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(children: children),
    );
  }
}

/// Baris tile menu navigasi profil terpadu untuk mencegah pengulangan boilerplate.
class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.jadeTosca),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppTheme.textMutedDark,
          ),
      onTap: onTap,
    );
  }
}

/// Avatar profil foto dengan fallback ke inisial huruf.
class _UserAvatar extends StatelessWidget {
  final UserModel? user;

  const _UserAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: 64,
          height: 64,
          child: Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _LetterAvatar(user: user),
          ),
        ),
      );
    }
    return _LetterAvatar(user: user);
  }
}

/// Avatar inisial huruf depan nama user (aturan E23).
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Center(
        child: Text(
          initial,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.jadeTosca,
          ),
        ),
      ),
    );
  }
}
