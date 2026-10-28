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
                  fontSize: 10,
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
                  subtitle: 'Kelola menu & harga',
                  icon: Icons.restaurant_menu_rounded,
                  onTap: () => context.push('/catalog'),
                )
              else
                _OperationTile(
                  title: 'Menu',
                  subtitle: 'Daftar menu & estimasi profit',
                  icon: Icons.restaurant_menu_rounded,
                  highlighted: true,
                  onTap: () => context.push('/operations/menu'),
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
                highlighted: true,
                onTap: () => _openAccountManager(context, ref),
              ),
              _OperationTile(
                title: 'Riwayat Transaksi',
                subtitle: 'Daftar struk & detail penjualan',
                icon: Icons.receipt_long_outlined,
                onTap: () => context.push('/pos/history?scope=dashboard'),
              ),
              _OperationTile(
                title: 'Hiburan',
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

/// Sentinel untuk pilihan "Semua Cabang" yang id-nya null.
const String _allBranches = '__all_branches__';

/// Langkah pemilihan cabang sebelum masuk Manajemen Pengguna.
///
/// Owner memilih cabang (atau semua cabang); manager cabangnya terkunci.
/// Pemilihan hanya menulis ke [userOutletFilterProvider] milik halaman akun,
/// jadi tidak ada rute baru maupun perubahan aturan data.
Future<void> _openAccountManager(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authProvider).user;
  final isOwner = user?.role == UserRole.owner;

  final items = <_BranchOption>[
    if (isOwner)
      const _BranchOption(
        id: _allBranches,
        name: 'Semua Cabang',
        subtitle: 'Akun dari seluruh cabang',
        icon: Icons.apps_rounded,
      ),
    if (isOwner)
      ...ref.read(availableOutletsProvider).map(
        (outlet) => _BranchOption(
          id: outlet.id,
          name: outlet.name,
          subtitle: outlet.address,
          icon: Icons.storefront_rounded,
        ),
      ),
    if (!isOwner)
      if (user != null)
        ...user.outlets.map(
          (outlet) => _BranchOption(
            id: outlet.id,
            name: outlet.name,
            subtitle: outlet.address,
            icon: Icons.storefront_rounded,
            locked: true,
          ),
        ),
  ];

  if (items.isEmpty) {
    await context.push('/users');
    return;
  }

  final selectedId = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _BranchPickerSheet(
      items: items,
      isOwner: isOwner,
      selectedId: isOwner ? ref.read(userOutletFilterProvider) : null,
    ),
  );

  if (selectedId == null) return;

  if (isOwner) {
    ref.read(userOutletFilterProvider.notifier).state =
        selectedId == _allBranches ? null : selectedId;
  }

  if (context.mounted) await context.push('/users');
}

/// Satu pilihan cabang di sheet pemilih.
class _BranchOption {
  final String id;
  final String name;
  final String? subtitle;
  final IconData icon;
  final bool locked;

  const _BranchOption({
    required this.id,
    required this.name,
    this.subtitle,
    this.icon = Icons.storefront_rounded,
    this.locked = false,
  });
}

/// Sheet "Pilih Cabang" sebelum membuka manajemen pengguna.
class _BranchPickerSheet extends StatelessWidget {
  final List<_BranchOption> items;
  final bool isOwner;
  final String? selectedId;

  const _BranchPickerSheet({
    required this.items,
    required this.isOwner,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Pilih Cabang',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              isOwner
                  ? 'Daftar akun yang tampil mengikuti cabang yang dipilih.'
                  : 'Akun yang bisa Anda kelola terbatas pada cabang tugas.',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final option = items[i];
                  return _BranchOptionTile(
                    option: option,
                    isSelected: option.id == selectedId,
                    onTap: () => Navigator.of(context).pop(option.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris pilihan cabang dengan penanda terpilih / terkunci.
class _BranchOptionTile extends StatelessWidget {
  final _BranchOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _BranchOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppTheme.jadeTosca.withAlpha(24) : AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 20,
                  color: isSelected ? AppTheme.jadeTosca : AppTheme.textMutedDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.name,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (option.subtitle != null && option.subtitle!.isNotEmpty)
                        Text(
                          option.subtitle!,
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (option.locked)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 13, color: AppTheme.textMutedDark),
                      const SizedBox(width: 4),
                      Text(
                        'Terkunci',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMutedDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                else
                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMutedDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu fitur operasional di grid 2 kolom.
class _OperationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _OperationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
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
              color: highlighted ? AppTheme.jadeTosca : AppTheme.lightCardBorder,
              width: highlighted ? 1.4 : 1.0,
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
                    color: highlighted ? AppTheme.jadeTosca : AppTheme.lightToskaBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: highlighted ? Colors.white : AppTheme.jadeTosca,
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
