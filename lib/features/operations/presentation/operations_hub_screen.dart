import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/presentation/notifications_provider.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Operasi'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
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
            icon: Icons.inventory_2_outlined,
            title: 'Katalog Produk & Kategori',
            subtitle: 'Lihat daftar harga, HPP, tambah produk baru & kategori',
            badgeText: 'Katalog',
            badgeColor: AppTheme.primaryBlue,
            onTap: () => context.push('/catalog'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.warehouse_outlined,
            title: 'Inventaris & Stok Outlet',
            subtitle: 'Pantau sisa stok per cabang dan peringatan menipis',
            badgeText: 'Stok',
            badgeColor: Colors.teal,
            onTap: () => context.push('/inventory'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.lightbulb_outline_rounded,
            title: 'Rekomendasi Keputusan (AI/DSS)',
            subtitle: 'Evaluasi Rule Engine untuk deteksi stok habis & slow moving',
            badgeText: 'Insight',
            badgeColor: Colors.purple,
            onTap: () => context.push('/insights'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.store_mall_directory_outlined,
            title: 'Manajemen Cabang & LBS',
            subtitle: 'Pemetaan cabang, pencarian outlet terdekat & jam operasional lokal',
            badgeText: 'Cabang',
            badgeColor: Colors.indigo,
            onTap: () => context.push('/outlets'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.assessment_outlined,
            title: 'Laporan & Audit Snapshot',
            subtitle: 'Dokumen ringkasan berkala dengan verifikasi integritas SHA-256',
            badgeText: 'Audit',
            badgeColor: Colors.teal,
            onTap: () => context.push('/reports'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi & Peringatan Sistem',
            subtitle: 'Peringatan stok menipis, evaluasi pencapaian target & pesan sistem',
            badgeText: 'Peringatan',
            badgeColor: Colors.deepOrange,
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.currency_exchange_rounded,
            title: 'Pengaturan Kurs & Waktu',
            subtitle: 'Preferensi multi-currency (IDR/USD/EUR) & zona waktu lokal cabang',
            badgeText: 'Kurs',
            badgeColor: Colors.deepPurple,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.sensors_rounded,
            title: 'Diagnostik Sensor & Biometrik',
            subtitle: 'Simulasi biometrik, shake-to-refresh, gauge akselerometer & giroskop',
            badgeText: 'Sensor',
            badgeColor: Colors.blueGrey,
            onTap: () => context.push('/sensors'),
          ),
          const SizedBox(height: 12),
          _buildOperationTile(
            context,
            icon: Icons.receipt_long_outlined,
            title: 'Riwayat Transaksi',
            subtitle: 'Daftar struk transaksi dan pembatalan (Void)',
            badgeText: 'Transaksi',
            badgeColor: Colors.orange,
            onTap: () {},
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
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: badgeColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: badgeColor, size: 26),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
