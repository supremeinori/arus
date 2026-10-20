import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final authState = ref.watch(authProvider);
    final isOwner = authState.user?.role == UserRole.owner;

    final scaffold = Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Pusat Operasi',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppTheme.textPrimaryLight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search_rounded,
              color: AppTheme.textPrimaryLight,
            ),
            tooltip: 'Pencarian Global',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppTheme.dangerRed,
              label: Text(
                '$unreadCount',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimaryLight,
              ),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Hero Card: Mesin Kasir
          _buildWideCard(
            title: 'Mesin Kasir',
            subtitle: 'Buka kasir aktif untuk input penjualan, scan barang & cetak struk',
            icon: Icons.point_of_sale_rounded,
            onTap: () => context.push('/pos'),
          ),
          const SizedBox(height: 12),

          // 2. Grid Fitur Operasional: Owner melihat 4 kartu (Produk, Inventaris, Staff, Cabang).
          // Manager hanya melihat fitur operasional non-owner (Inventaris, Staff) tanpa Produk & Cabang.
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              if (isOwner)
                _buildSquareCard(
                  title: 'Produk',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => context.push('/catalog'),
                ),
              _buildSquareCard(
                title: 'Inventaris',
                icon: Icons.warehouse_outlined,
                onTap: () => context.push('/inventory'),
              ),
              _buildSquareCard(
                title: 'Staff',
                icon: Icons.people_outline_rounded,
                onTap: () => context.push('/users'),
              ),
              if (isOwner)
                _buildSquareCard(
                  title: 'Cabang',
                  icon: Icons.storefront_outlined,
                  onTap: () => context.push('/outlets'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Wide Card: Ledger
          _buildWideCard(
            title: 'Ledger',
            subtitle: 'Integritas blockchain & audit transaksi tersegel SHA-256',
            icon: Icons.verified_user_outlined,
            onTap: () => context.push('/integrity'),
          ),
          const SizedBox(height: 20),

          // 4. Section: Entertain
          Text(
            'Entertain',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          _buildEntertainCard(
            onTap: () => context.push('/game'),
          ),
          const SizedBox(height: 80), // Padding bawah agar tidak tertutup FAB/Bottom Bar
        ],
      ),

      // Floating Component di kanan bawah
      floatingActionButton: Container(
        width: 56,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.textMutedLight,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );

    return scaffold;
  }

  // Helper: Wide Card (Mesin Kasir & Ledger)
  static Widget _buildWideCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.lightCardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.lightCardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightCardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimaryLight.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMutedLight,
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.lightToskaBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: AppTheme.jadeTosca),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Square Card Grid (Produk, Inventaris, Staff, Cabang)
  static Widget _buildSquareCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.lightCardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.lightCardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightCardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimaryLight.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.lightToskaBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 28, color: AppTheme.jadeTosca),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Entertain Large Card (Mini-Game)
  static Widget _buildEntertainCard({required VoidCallback onTap}) {
    return Material(
      color: AppTheme.lightCardSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppTheme.lightCardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightCardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: AppTheme.textPrimaryLight.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_esports_outlined,
                size: 64,
                color: AppTheme.jadeTosca,
              ),
              const SizedBox(height: 8),
              Text(
                'Mini-Game Menu',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tebak menu & edukasi resep',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textMutedLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
