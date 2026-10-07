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
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: const Color(0xFFDC2626),
              label: Text('$unreadCount', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 10)),
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
          _buildOperationTile(
            context,
            icon: Icons.point_of_sale_rounded,
            title: 'Mesin Kasir (POS)',
            subtitle: 'Catat transaksi penjualan kasir, kelola keranjang & cetak struk',
            badgeText: 'Kasir',
            onTap: () => context.push('/pos'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'Katalog Produk & Kategori',
            subtitle: 'Lihat daftar harga, HPP, tambah produk baru & kategori',
            badgeText: 'Katalog',
            onTap: () => context.push('/catalog'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.warehouse_outlined,
            title: 'Inventaris & Stok Outlet',
            subtitle: 'Pantau sisa stok per cabang dan peringatan menipis',
            badgeText: 'Stok',
            onTap: () => context.push('/inventory'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.lightbulb_outline_rounded,
            title: 'Rekomendasi Keputusan (AI/DSS)',
            subtitle: 'Evaluasi Rule Engine untuk deteksi stok habis & anomali',
            badgeText: 'Insight',
            onTap: () => context.push('/insights'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.store_mall_directory_outlined,
            title: 'Manajemen Cabang & LBS',
            subtitle: 'Pemetaan cabang, pencarian outlet terdekat & jam operasional',
            badgeText: 'Cabang',
            onTap: () => context.push('/outlets'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.assessment_outlined,
            title: 'Laporan & Audit Snapshot',
            subtitle: 'Dokumen ringkasan berkala dengan verifikasi integritas SHA-256',
            badgeText: 'Audit',
            onTap: () => context.push('/reports'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi & Peringatan Sistem',
            subtitle: 'Peringatan stok menipis, evaluasi target & pesan sistem',
            badgeText: 'Peringatan',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.currency_exchange_rounded,
            title: 'Pengaturan Kurs & Waktu',
            subtitle: 'Preferensi multi-currency (IDR/USD/EUR) & zona waktu cabang',
            badgeText: 'Kurs',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 10),
          _buildOperationTile(
            context,
            icon: Icons.sensors_rounded,
            title: 'Diagnostik Sensor & Biometrik',
            subtitle: 'Simulasi biometrik, shake-to-refresh, akselerometer & giroskop',
            badgeText: 'Sensor',
            onTap: () => context.push('/sensors'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: onTap,
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
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted, height: 1.3),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
      ),
    );
  }
}
