import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/settings_tile.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../sensors/presentation/shake_settings_sheet.dart';
import '../../shell/presentation/main_shell.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
    // Revisi 23 Okt 2026: "Cabang & Outlet" hanya untuk owner. Manajer tetap
    // memegang "Integritas Data". Sebabnya Rute /outlets sudah dibatasi owner
    // di app_router.dart, jadi tile itu sebelumnya jalan buntu bagi manajer.
    final showManagement =
        user?.role == UserRole.owner || user?.role == UserRole.manager;
    final isOwner = user?.role == UserRole.owner;

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profil',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isOwner
                  ? 'Kelola akun, cabang, dan integritas data'
                  : 'Kelola akun dan integritas data',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // 1. Kartu identitas akun
          _ProfileHeaderCard(user: user),
          const SizedBox(height: 18),

          if (showManagement) ...[
            SettingsSectionLabel(
              isOwner ? 'Manajemen & Integritas' : 'Integritas Data',
            ),
            const SizedBox(height: 8),
            SettingsSectionCard(
              children: [
                // Sementara #outlets ditahan untuk owner lewat app_router.dart,
                // jadi kartunya disembunyikan untuk manajer.
                if (isOwner) ...[
                  SettingsNavTile(
                    icon: Icons.storefront_rounded,
                    title: 'Cabang & Outlet',
                    onTap: () => context.push('/outlets'),
                  ),
                  const SettingsTileDivider(),
                ],
                SettingsNavTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Integritas Data (Ledger LBS)',
                  onTap: () => context.push('/integrity'),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          const SettingsSectionLabel('Preferensi'),
          const SizedBox(height: 8),
          SettingsSectionCard(
            children: [
              const SettingsTileDivider(),
              SettingsNavTile(
                icon: Icons.settings_outlined,
                title: 'Pengaturan',
                onTap: () => context.push('/settings'),
              ),
              const SettingsTileDivider(),
              SettingsNavTile(
                icon: Icons.sensors_rounded,
                title: 'Diagnostik Sensor & Biometrik',
                onTap: () => context.push('/sensors'),
              ),
              const SettingsTileDivider(),
              SettingsNavTile(
                icon: Icons.vibration_rounded,
                title: 'Sensitivitas Guncangan (Shake)',
                onTap: () => ShakeSettingsSheet.show(context),
                trailing: SettingsValueChip(
                  label: _getThresholdLabel(currentThreshold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const SettingsSectionLabel('Bantuan & Info'),
          const SizedBox(height: 8),
          // Revisi 22 Okt 2026: "Kelola Staf & Akun" dipindahkan ke Pusat Operasi,
          // jadi di Profil tidak ada lagi pintu ganda ke halaman yang sama.
          SettingsSectionCard(
            children: [
              SettingsNavTile(
                icon: Icons.rate_review_outlined,
                title: 'Saran & Kesan Kuliah PAM',
                onTap: () => context.push('/feedback'),
              ),
              const SettingsTileDivider(),
              SettingsNavTile(
                icon: Icons.info_outline_rounded,
                title: 'Tentang ARUS',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Zona keluar akun
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showLogoutDialog(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dangerRed.withAlpha(70),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.logout_rounded,
                    size: 20,
                    color: AppTheme.dangerRed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Keluar Akun',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.dangerRed,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Akhiri sesi di perangkat ini',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: AppTheme.textMutedDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
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

/// Kartu identitas akun: avatar, nama, email, dan peran.
class _ProfileHeaderCard extends StatelessWidget {
  final UserModel? user;

  const _ProfileHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final email = user?.email;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(
        children: [
          _UserAvatar(user: user),
          const SizedBox(height: 12),
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
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: AppTheme.textMutedDark,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.jadeTosca.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.jadeTosca.withAlpha(70),
                width: 1.0,
              ),
            ),
            child: Text(
              user?.role.toDisplayString() ?? 'Pengguna',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.jadeTosca,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
          width: 72,
          height: 72,
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
      width: 72,
      height: 72,
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
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.jadeTosca,
          ),
        ),
      ),
    );
  }
}
