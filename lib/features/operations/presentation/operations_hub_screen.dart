import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../notifications/presentation/notifications_provider.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: AppTheme.darkCardBorder,
          ),
        ),
        title: Text(
          'Pusat Operasi',
          style: GoogleFonts.lexend(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppTheme.textPrimaryDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Pencarian Global',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: const Color(0xFFEF4444),
              label: Text(
                '$unreadCount',
                style: GoogleFonts.lexend(
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              child: const Icon(
                Icons.notifications_outlined,
                color: AppTheme.textPrimaryDark,
              ),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
          // Hitung aspect ratio dinamis agar tinggi kartu selalu cukup (~146dp) dan bebas RenderFlex overflow
          final itemWidth = (width - 32 - ((crossAxisCount - 1) * 12)) / crossAxisCount;
          final childAspectRatio = (itemWidth / 146).clamp(0.95, 1.45);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Hero Card: Mesin Kasir (POS)
              const _PosHeroCard(),
              const SizedBox(height: 24),

              // 2. Kategori: Manajemen
              const _SectionHeader(
                icon: Icons.business_center_outlined,
                title: 'Manajemen',
                countBadge: '4 Modul',
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: const [
                  _OperationGridCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Katalog & Kategori',
                    subtitle: 'Daftar harga jual, HPP, & tambah produk',
                    badgeText: 'Katalog',
                    route: '/catalog',
                  ),
                  _OperationGridCard(
                    icon: Icons.warehouse_outlined,
                    title: 'Inventaris & Stok',
                    subtitle: 'Pantau sisa stok outlet & peringatan tipis',
                    badgeText: 'Stok',
                    route: '/inventory',
                  ),
                  _OperationGridCard(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Cabang & LBS',
                    subtitle: 'Pemetaan cabang, LBS & jam operasional',
                    badgeText: 'Cabang',
                    route: '/outlets',
                  ),
                  _OperationGridCard(
                    icon: Icons.security_rounded,
                    title: 'Integritas Ledger',
                    subtitle: 'Audit trail rantai blok SHA-256 anti-tamper',
                    badgeText: 'Audit Chain',
                    route: '/integrity',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Kategori: Fitur Tambahan
              const _SectionHeader(
                icon: Icons.sports_esports_rounded,
                title: 'Fitur Tambahan',
                countBadge: '1 Modul',
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
                children: const [
                  _OperationGridCard(
                    icon: Icons.sports_esports_rounded,
                    title: 'Mini-Game Menu',
                    subtitle: 'Uji ketangkasan hafalan menu & harga POS',
                    badgeText: 'Game',
                    route: '/game',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeDark,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// Header Kategori Operasi
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String countBadge;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.countBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.jadeTosca),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.lexend(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryDark,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.darkCardSurfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
          ),
          child: Text(
            countBadge,
            style: GoogleFonts.lexend(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hero Action Card untuk Mesin Kasir (POS)
class _PosHeroCard extends StatelessWidget {
  const _PosHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        gradient: LinearGradient(
          colors: [
            AppTheme.jadeTosca.withValues(alpha: 0.14),
            AppTheme.darkCardSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.jadeTosca.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/pos'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Mesin Kasir (POS)',
                              style: GoogleFonts.lexend(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ShadBadge.secondary(
                            backgroundColor: AppTheme.jadeTosca.withValues(alpha: 0.15),
                            foregroundColor: AppTheme.jadeTosca,
                            child: Text(
                              'Kasir Utama',
                              style: GoogleFonts.lexend(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buka kasir aktif untuk input penjualan, scan barang & cetak struk',
                        style: GoogleFonts.lexend(
                          fontSize: 11.5,
                          color: AppTheme.textMutedDark,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.darkCardBorder),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.jadeTosca,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Item Grid Kartu Operasi dalam Kategori
class _OperationGridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badgeText;
  final String route;

  const _OperationGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(route),
      child: ShadCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.jadeTosca.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, color: AppTheme.jadeTosca, size: 20),
                ),
                Flexible(
                  child: ShadBadge.outline(
                    child: Text(
                      badgeText,
                      style: GoogleFonts.lexend(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.jadeTosca,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textPrimaryDark,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.lexend(
                      fontSize: 10.5,
                      color: AppTheme.textMutedDark,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
