import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/presentation/notifications_provider.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Pusat Operasi',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.accentBlack),
            tooltip: 'Pencarian Global',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: const Color(0xFFDC2626),
              label: Text('$unreadCount', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.accentBlack),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _OperationTile(
            icon: Icons.point_of_sale_rounded,
            title: 'Mesin Kasir (POS)',
            subtitle: 'Catat transaksi penjualan kasir, kelola keranjang & cetak struk',
            badgeText: 'Kasir',
            route: '/pos',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.inventory_2_outlined,
            title: 'Katalog Produk & Kategori',
            subtitle: 'Lihat daftar harga, HPP, tambah produk baru & kategori',
            badgeText: 'Katalog',
            route: '/catalog',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.warehouse_outlined,
            title: 'Inventaris & Stok Outlet',
            subtitle: 'Pantau sisa stok per cabang dan peringatan menipis',
            badgeText: 'Stok',
            route: '/inventory',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Rekomendasi Keputusan (AI/DSS)',
            subtitle: 'Evaluasi Rule Engine untuk deteksi stok habis & anomali',
            badgeText: 'Insight',
            route: '/insights',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.store_mall_directory_outlined,
            title: 'Manajemen Cabang & LBS',
            subtitle: 'Pemetaan cabang, pencarian outlet terdekat & jam operasional',
            badgeText: 'Cabang',
            route: '/outlets',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.assessment_outlined,
            title: 'Laporan & Audit Snapshot',
            subtitle: 'Dokumen ringkasan berkala dengan verifikasi integritas SHA-256',
            badgeText: 'Audit',
            route: '/reports',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi & Peringatan Sistem',
            subtitle: 'Peringatan stok menipis, evaluasi target & pesan sistem',
            badgeText: 'Peringatan',
            route: '/notifications',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.currency_exchange_rounded,
            title: 'Pengaturan Kurs & Waktu',
            subtitle: 'Preferensi multi-currency (IDR/USD/EUR) & zona waktu cabang',
            badgeText: 'Kurs',
            route: '/settings',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.security_rounded,
            title: 'Ledger Integritas & Verifikasi',
            subtitle: 'Audit trail rantai blok SHA-256 untuk mendeteksi manipulasi data',
            badgeText: 'Audit Chain',
            route: '/integrity',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.sports_esports_rounded,
            title: 'Mini-Game: Guess the Menu',
            subtitle: 'Uji ketangkasan menghafal foto menu, nama produk, & harga jual POS',
            badgeText: 'Game',
            route: '/game',
          ),
          const SizedBox(height: 10),
          const _OperationTile(
            icon: Icons.sensors_rounded,
            title: 'Diagnostik Sensor & Biometrik',
            subtitle: 'Simulasi biometrik, shake-to-refresh, akselerometer & giroskop',
            badgeText: 'Sensor',
            route: '/sensors',
          ),
        ],
      ),
    );
  }

}

/// Tile operasi — widget class top-level const (aturan E23).
class _OperationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final String route;

  const _OperationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => context.push(route),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.accentBlack,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.lightBlueBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.lexend(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted, height: 1.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: const SizedBox(width: 20, child: Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14)),
      ),
    );
  }
}
