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
            icon: const Icon(Icons.search_rounded, color: AppTheme.accentBlack),
            tooltip: 'Pencarian Global',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppTheme.dangerRed,
              label: Text('$unreadCount', style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 10)),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.accentBlack),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Fitur utama: POS (lebar penuh, gradien toska)
          _buildFeatureCard(
            context,
            icon: Icons.point_of_sale_rounded,
            title: 'Mesin Kasir (POS)',
            subtitle: 'Catat transaksi penjualan kasir, kelola keranjang & cetak struk',
            onTap: () => context.push('/pos'),
          ),

          _buildSectionTitle('Data & Stok'),
          _buildPairRow(
            _buildTile(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Katalog Produk',
              subtitle: 'Harga, HPP, tambah produk & kategori',
              badgeText: 'Katalog',
              onTap: () => context.push('/catalog'),
            ),
            _buildTile(
              context,
              icon: Icons.warehouse_outlined,
              title: 'Inventaris & Stok',
              subtitle: 'Sisa stok per outlet & peringatan menipis',
              badgeText: 'Stok',
              accent: true,
              onTap: () => context.push('/inventory'),
            ),
          ),

          _buildSectionTitle('Cabang & Laporan'),
          _buildPairRow(
            _buildTile(
              context,
              icon: Icons.store_mall_directory_outlined,
              title: 'Cabang & LBS',
              subtitle: 'Pemetaan cabang, outlet terdekat & jam buka',
              badgeText: 'Cabang',
              onTap: () => context.push('/outlets'),
            ),
            _buildTile(
              context,
              icon: Icons.assessment_outlined,
              title: 'Laporan & Audit',
              subtitle: 'Ringkasan berkala, verifikasi SHA-256',
              badgeText: 'Audit',
              onTap: () => context.push('/reports'),
            ),
          ),

          _buildSectionTitle('AI & Integritas'),
          _buildPairRow(
            _buildTile(
              context,
              icon: Icons.lightbulb_outline_rounded,
              title: 'Rekomendasi AI/DSS',
              subtitle: 'Rule Engine: stok habis & anomali',
              badgeText: 'Insight',
              accent: true,
              onTap: () => context.push('/insights'),
            ),
            _buildTile(
              context,
              icon: Icons.security_rounded,
              title: 'Ledger Integritas',
              subtitle: 'Audit trail rantai blok SHA-256',
              badgeText: 'Audit Chain',
              onTap: () => context.push('/integrity'),
            ),
          ),

          _buildSectionTitle('Lainnya'),
          _buildPillRow(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Notifikasi & Peringatan',
            subtitle: 'Stok menipis, evaluasi target & pesan sistem',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: 10),
          _buildPillRow(
            context,
            icon: Icons.currency_exchange_rounded,
            title: 'Pengaturan Kurs & Waktu',
            subtitle: 'IDR / USD / EUR & zona waktu cabang',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 10),
          _buildPairRow(
            _buildTile(
              context,
              icon: Icons.sports_esports_outlined,
              title: 'Simulasi Keputusan',
              subtitle: 'Mini game strategi operasional',
              badgeText: 'Simulasi',
              onTap: () => context.push('/game'),
            ),
            _buildTile(
              context,
              icon: Icons.sensors_rounded,
              title: 'Diagnostik Sensor',
              subtitle: 'Biometrik, akselerometer & giroskop',
              badgeText: 'Sensor',
              onTap: () => context.push('/sensors'),
            ),
          ),
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

  /// Dua kartu sejajar. Tinggi tiap kartu mengikuti isinya.
  Widget _buildPairRow(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  /// Kartu fitur utama, lebar penuh, gradien toska.
  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryToska, AppTheme.darkToska],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.lexend(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: AppTheme.darkToska, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu persegi panjang untuk grid 2 kolom.
  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    final bg = accent ? AppTheme.lightToskaBg : Colors.white;
    final border = accent ? AppTheme.primaryToska.withValues(alpha: 0.35) : AppTheme.borderOutline;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent ? AppTheme.primaryToska : AppTheme.lightToskaBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.25)),
                      ),
                      child: Icon(
                        icon,
                        color: accent ? Colors.white : AppTheme.primaryToska,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    _badge(badgeText),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.accentBlack, height: 1.25),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Baris kapsul lebar penuh.
  Widget _buildPillRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.borderOutline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.lightToskaBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.25)),
                  ),
                  child: Icon(icon, color: AppTheme.primaryToska, size: 22),
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
                      Text(
                        subtitle,
                        style: GoogleFonts.lexend(fontSize: 10.5, color: AppTheme.textMuted),
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

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.lightToskaBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: GoogleFonts.lexend(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppTheme.darkToska),
      ),
    );
  }
}
