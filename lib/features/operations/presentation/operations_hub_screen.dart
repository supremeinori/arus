import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../users/presentation/user_management_provider.dart';

class OperationsHubScreen extends ConsumerWidget {
  const OperationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isOwner = ref.watch(authProvider).user?.role == UserRole.owner;

    return Scaffold(
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
            icon: const Icon(Icons.search_rounded, color: AppTheme.textPrimaryLight),
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
                  fontSize: 11,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              child: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimaryLight),
            ),
            tooltip: 'Pusat Notifikasi',
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          // Kartu POS dihapus (revisi 22 Okt 2026): mesin kasir hanya untuk kasir
          // lewat tab "Kasir". Endpoint /pos tidak disentuh.
          // Cabang, Ledger, dan Pengaturan kini di Profil -> Manajemen & Integritas.
          // Keempat kartu memakai aksen yang sama (revisi 27 Okt 2026). Sebelumnya
          // hanya "Kelola Staf & Akun" yang menyala dengan tepi tosca dan cip ikon
          // tosca padat, sedangkan tiga lainnya bertepi abu dan bercip tosca pudar.
          // Kartu-kartu ini sederajat sebagai pintu masuk, jadi tidak ada yang
          // ditonjolkan. Perilaku onTap tiap kartu tidak berubah.
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              if (isOwner)
                _OperationTile(
                  title: 'Produk',
                  subtitle: 'Menu & harga',
                  icon: Icons.restaurant_menu_rounded,
                  onTap: () => context.push('/catalog'),
                ),
              _OperationTile(
                title: 'Inventaris',
                subtitle: 'Stok bahan',
                icon: Icons.inventory_2_outlined,
                onTap: () => context.push('/inventory'),
              ),
              _OperationTile(
                title: 'Kelola Staf & Akun',
                subtitle: isOwner ? 'Pilih cabang dahulu' : 'Kasir di cabang Anda',
                icon: Icons.groups_2_outlined,
                onTap: () => context.push('/users'),
              ),
              _OperationTile(
                title: 'Minigames',
                subtitle: 'Guess the Menu',
                icon: Icons.sports_esports_outlined,
                onTap: () => context.push('/game'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu fitur operasional di grid 2 kolom.
class _OperationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _OperationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.lightCardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.lightCardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.jadeTosca,
              width: 1.4,
            ),
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
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryLight,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedLight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Sisa tinggi diserap Spacer supaya kotak tidak pernah meluber.
              const Spacer(),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
