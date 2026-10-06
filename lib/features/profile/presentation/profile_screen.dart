import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
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
