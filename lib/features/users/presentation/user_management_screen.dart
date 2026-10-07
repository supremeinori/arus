import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  final List<Map<String, dynamic>> _demoUsers = const [
    {
      'id': 'u-owner-001',
      'name': 'Rina Kartika',
      'email': 'owner@arus.demo',
      'role': 'Owner (Pemilik)',
      'outlet': 'Semua Cabang',
      'status': 'Aktif',
    },
    {
      'id': 'u-mgr-001',
      'name': 'Budi Santoso',
      'email': 'manager@arus.demo',
      'role': 'Manager (Kepala Cabang)',
      'outlet': 'Kopi Arus - Sudirman (HQ)',
      'status': 'Aktif',
    },
    {
      'id': 'u-staff-001',
      'name': 'Siti Rahma',
      'email': 'staff@arus.demo',
      'role': 'Staff (Kasir)',
      'outlet': 'Kopi Arus - Sudirman (HQ)',
      'status': 'Aktif',
    },
    {
      'id': 'u-staff-002',
      'name': 'Ahmad Fauzi',
      'email': 'fauzi@arus.demo',
      'role': 'Staff (Kasir)',
      'outlet': 'Kopi Arus - Senopati',
      'status': 'Aktif',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Manajemen Pengguna & Tim',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Daftar Anggota & Hak Akses Toko',
            style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ..._demoUsers.map((u) {
            final isOwner = u['role'].toString().contains('Owner');
            final isManager = u['role'].toString().contains('Manager');
            final badgeColor = isOwner
                ? const Color(0xFF1D4ED8)
                : isManager
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderOutline, width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      u['name'][0],
                      style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 16, color: badgeColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u['name'],
                          style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                        ),
                        Text(
                          u['email'],
                          style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                u['role'],
                                style: GoogleFonts.lexend(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${u['outlet']}',
                              style: GoogleFonts.lexend(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
