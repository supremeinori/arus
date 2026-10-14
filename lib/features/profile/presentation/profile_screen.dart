import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Profil & Akun',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildUserCard(user),

          // Keamanan & sesi biometrik
          _buildSectionTitle('Keamanan & Preferensi Sesi'),
          _buildBiometricTile(ref, user),

          // Cakupan outlet
          if (user != null && user.outlets.isNotEmpty) ...[
            _buildSectionTitle('Akses Outlet Cabang (${user.outlets.length})'),
            ...user.outlets.map(
              (o) => _buildOutletTile(
                name: o.name,
                detail: '${o.timezone} • ${o.address ?? "-"}',
              ),
            ),
          ],

          // Menu administrasi
          _buildSectionTitle('Administrasi & Aplikasi'),
          _buildMenuItem(
            icon: Icons.people_outline_rounded,
            title: 'Kelola Staf & Akun',
            subtitle: 'Atur hak akses kasir, manager, dan role pengguna',
            onTap: () => context.push('/users'),
          ),
          const SizedBox(height: 10),
          _buildMenuItem(
            icon: Icons.rate_review_outlined,
            title: 'Saran & Kesan Kuliah PAM',
            subtitle: 'Kesan dan saran mata kuliah Pemrograman Aplikasi Mobile (Phase 1)',
            onTap: () => context.push('/feedback'),
          ),
          const SizedBox(height: 10),
          _buildMenuItem(
            icon: Icons.info_outline_rounded,
            title: 'Tentang ARUS Decision Hub',
            subtitle: 'Versi rilis v2.4.0, lisensi, & arsitektur sistem',
            onTap: () => context.push('/about'),
          ),

          const SizedBox(height: 24),
          _buildLogoutButton(context, ref),
        ],
      ),
    );
  }

  // ---------- Komponen ----------

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.lexend(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Avatar: foto dari server jika ada, selain itu huruf awal nama.
  Widget _buildAvatar(UserModel? user) {
    final avatarUrl = user?.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    final initial = (user != null && user.name.isNotEmpty) ? user.name[0].toUpperCase() : 'U';

    Widget letter() => Center(
          child: Text(
            initial,
            style: GoogleFonts.lexend(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        );

    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: hasPhoto
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => letter(),
            )
          : letter(),
    );
  }

  /// Kartu profil dengan gradien toska.
  Widget _buildUserCard(UserModel? user) {
    final role = user?.role.toDisplayString() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryToska, AppTheme.darkToska],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkToska.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatar(user),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Pengguna',
                  style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.lexend(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9)),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Toggle login sidik jari. Tetap memanggil toggleBiometric dari provider.
  Widget _buildBiometricTile(WidgetRef ref, UserModel? user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryToska,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 22),
        ),
        title: Text(
          'Login Sidik Jari (Biometrik)',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accentBlack),
        ),
        subtitle: Text(
          'Buka kunci sesi otomatis dengan sensor biometrik HP',
          style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3),
        ),
        activeThumbColor: AppTheme.primaryToska,
        value: user?.settings.biometricEnabled ?? false,
        onChanged: (val) => ref.read(authProvider.notifier).toggleBiometric(val),
      ),
    );
  }

  Widget _buildOutletTile({required String name, required String detail}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.lightToskaBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.storefront_outlined, color: AppTheme.primaryToska, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
                ),
                Text(
                  detail,
                  style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol menu berbentuk kartu dengan ikon kotak toska.
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderOutline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryToska,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accentBlack),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.5), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _confirmLogout(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: AppTheme.dangerRed, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Keluar Akun',
                  style: GoogleFonts.lexend(color: AppTheme.dangerRed, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar dari Akun?',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari sesi saat ini?',
          style: GoogleFonts.lexend(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.lexend(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: Text('Keluar', style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
