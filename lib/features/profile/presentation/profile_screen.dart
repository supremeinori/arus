import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/presentation/auth_provider.dart';
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
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Card
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderOutline, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                  ),
                  child: Center(
                    child: Text(
                      (user != null && user.name.isNotEmpty)
                          ? user.name[0].toUpperCase()
                          : 'U',
                      style: GoogleFonts.lexend(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Pengguna',
                        style: GoogleFonts.lexend(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentBlack,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: GoogleFonts.lexend(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBlueBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                        ),
                        child: Text(
                          user?.role.toDisplayString() ?? '',
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

          // Outlet Scopes List
          if (user != null && user.outlets.isNotEmpty) ...[
            Text(
              'Akses Outlet Cabang (${user.outlets.length}):',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
            ),
            const SizedBox(height: 8),
            ...user.outlets.map(
              (o) => Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: AppTheme.primaryBlue),
                  title: Text(o.name, style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                    '${o.timezone} • ${o.address ?? "-"}',
                    style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Text(
            'Administrasi & Aplikasi',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
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
                  leading: const Icon(Icons.people_outline_rounded, color: AppTheme.primaryBlue),
                  title: Text('Kelola Staf & Akun', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Atur hak akses kasir, manager, dan role pengguna', style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  onTap: () => context.push('/users'),
                ),
                const Divider(height: 1, indent: 56, color: AppTheme.borderOutline),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined, color: AppTheme.primaryBlue),
                  title: Text('Kirim Masukan & Feedback', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Saran pengembangan fitur dan laporan bug sistem', style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                  onTap: () => context.push('/feedback'),
                ),
                const Divider(height: 1, indent: 56, color: AppTheme.borderOutline),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue),
                  title: Text('Tentang ARUS Decision Hub', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: Text('Versi rilis v2.4.0, lisensi, & arsitektur sistem', style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
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
                    side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                  ),
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
                      child: Text('Batal', style: GoogleFonts.lexend(color: const Color(0xFF64748B))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dangerRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(color: AppTheme.borderOutline, width: 1),
                        ),
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
            },
            icon: const Icon(Icons.logout, color: AppTheme.dangerRed, size: 18),
            label: Text(
              'Keluar Akun',
              style: GoogleFonts.lexend(color: AppTheme.dangerRed, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.dangerRed, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
