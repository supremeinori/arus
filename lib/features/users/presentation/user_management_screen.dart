import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/user_management_models.dart';
import 'user_management_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openUserFormDialog([ManagedUser? userToEdit]) {
    final authUser = ref.read(authProvider).user;
    if (authUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _UserFormSheet(currentUser: authUser, userToEdit: userToEdit),
    );
  }

  void _confirmDeleteUser(ManagedUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.lightCardBorder, width: 1.0),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.dangerRed,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Akun?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun "${user.name}" (${user.roleDisplay}) dari cabang ${user.outletName}?\n\nTindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: AppTheme.textSecondaryLight,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.textMutedLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(userManagementProvider.notifier)
                    .deleteUser(user.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Akun ${user.name} berhasil dihapus.',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('Exception: ', ''),
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: AppTheme.dangerRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Hapus Akun',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final isOwner = authUser?.role == UserRole.owner;
    final isManager = authUser?.role == UserRole.manager;

    final usersAsync = ref.watch(userManagementProvider);
    final visibleUsers = ref.watch(visibleUsersProvider);
    final availableOutlets = ref.watch(availableOutletsProvider);

    final selectedRole = ref.watch(userRoleFilterProvider);
    final selectedOutlet = ref.watch(userOutletFilterProvider);

    // Identifikasi nama cabang jika Manager
    final managerOutletName = (authUser?.outlets.isNotEmpty == true)
        ? authUser!.outlets.first.name
        : 'Kopi Arus - Sudirman (HQ)';

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.lightCardSurface,
        foregroundColor: AppTheme.textPrimaryLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.lightCardBorder, width: 1.0),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              isOwner ? 'Manajemen Pengguna & Tim' : 'Kelola Kasir Cabang',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: AppTheme.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isOwner
                  ? 'Akses Penuh: Kelola Manager & Kasir seluruh cabang'
                  : 'Cabang: $managerOutletName',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                color: AppTheme.textMutedLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Segarkan Data',
            onPressed: () =>
                ref.read(userManagementProvider.notifier).loadUsers(),
          ),
        ],
      ),
      floatingActionButton: (isOwner || isManager)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.jadeTosca,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: Text(
                isOwner ? 'Tambah Akun' : 'Tambah Kasir',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              onPressed: () => _openUserFormDialog(),
            )
          : null,
      body: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.jadeTosca),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.dangerRed,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat data pengguna',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppTheme.textMutedLight,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.jadeTosca,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(userManagementProvider.notifier).loadUsers(),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (allUsers) {
          final totalManagers = allUsers
              .where((u) => u.role == UserRole.manager)
              .length;
          final totalStaff = allUsers
              .where((u) => u.role == UserRole.staff)
              .length;
          final managerStaffCount = visibleUsers.length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. Banner Khusus Role Manager
              if (isManager) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4), // Emerald-50
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBBF7D0),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF16A34A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Akses Terbatas Cabang Manager',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: const Color(0xFF14532D),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Anda dapat menambah, mengedit, dan menghapus kasir khusus untuk cabang $managerOutletName ($managerStaffCount kasir terdaftar).',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF166534),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 2. Summary Metric Chips untuk Owner
              if (isOwner) ...[
                Row(
                  children: [
                    _MetricChip(
                      icon: Icons.people_outline_rounded,
                      label: 'Total Pengguna',
                      count: allUsers.length.toString(),
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    _MetricChip(
                      icon: Icons.badge_outlined,
                      label: 'Manager',
                      count: totalManagers.toString(),
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    _MetricChip(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Kasir',
                      count: totalStaff.toString(),
                      color: AppTheme.jadeTosca,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // 3. Search Bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.lightCardBorder,
                    width: 1.0,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: isOwner
                        ? 'Cari nama, email, atau cabang...'
                        : 'Cari nama atau email kasir...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textMutedLight,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppTheme.textMutedLight,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(userSearchQueryProvider.notifier).state =
                                  '';
                              setState(() {});
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    ref.read(userSearchQueryProvider.notifier).state = val;
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 12),

              // 4. Role & Outlet Filters untuk Owner
              if (isOwner) ...[
                Row(
                  children: [
                    // Role Filter Chips
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChoiceChip(
                              label: 'Semua Role',
                              isSelected: selectedRole == 'all',
                              onSelected: () =>
                                  ref
                                          .read(userRoleFilterProvider.notifier)
                                          .state =
                                      'all',
                            ),
                            const SizedBox(width: 6),
                            _FilterChoiceChip(
                              label: 'Manager ($totalManagers)',
                              isSelected: selectedRole == 'manager',
                              onSelected: () =>
                                  ref
                                          .read(userRoleFilterProvider.notifier)
                                          .state =
                                      'manager',
                            ),
                            const SizedBox(width: 6),
                            _FilterChoiceChip(
                              label: 'Kasir ($totalStaff)',
                              isSelected: selectedRole == 'staff',
                              onSelected: () =>
                                  ref
                                          .read(userRoleFilterProvider.notifier)
                                          .state =
                                      'staff',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Outlet Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.lightCardBorder,
                            width: 1.0,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedOutlet,
                            isExpanded: true,
                            hint: Text(
                              'Semua Cabang',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppTheme.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: AppTheme.textMutedLight,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Semua Cabang',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...availableOutlets.map(
                                (o) => DropdownMenuItem<String?>(
                                  value: o.id,
                                  child: Text(
                                    o.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              ref
                                      .read(userOutletFilterProvider.notifier)
                                      .state =
                                  val;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // 5. Header Daftar Pengguna & Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOwner
                        ? 'Daftar Anggota & Staf (${visibleUsers.length})'
                        : 'Daftar Kasir Cabang (${visibleUsers.length})',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                  if (selectedRole != 'all' || selectedOutlet != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        ref.read(userRoleFilterProvider.notifier).state = 'all';
                        ref.read(userOutletFilterProvider.notifier).state =
                            null;
                      },
                      child: Text(
                        'Reset Filter',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.jadeTosca,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 6. User List / Empty State
              if (visibleUsers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.lightCardBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.person_search_rounded,
                        size: 48,
                        color: Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak Ada Pengguna',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isManager
                            ? 'Belum ada kasir terdaftar di cabang Anda. Tekan tombol "+ Tambah Kasir" untuk mendaftarkan kasir baru.'
                            : 'Tidak ada data pengguna yang cocok dengan kriteria pencarian atau filter yang dipilih.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: AppTheme.textMutedLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...visibleUsers.map((user) {
                  final canEdit =
                      isOwner || (isManager && user.role == UserRole.staff);
                  final canDelete =
                      (isOwner && user.id != authUser?.id) ||
                      (isManager && user.role == UserRole.staff);

                  return _UserCard(
                    user: user,
                    canEdit: canEdit,
                    canDelete: canDelete,
                    onEdit: () => _openUserFormDialog(user),
                    onDelete: () => _confirmDeleteUser(user),
                  );
                }),
              ],

              // Extra spacing for bottom bar
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

/// Widget Card Pengguna
class _UserCard extends StatelessWidget {
  final ManagedUser user;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lightCardBorder, width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Circle with Role Color
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: user.roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: user.roleColor.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: user.roleColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Aktif',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.phone != null && user.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.phone!,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.lightCardBorder),
          const SizedBox(height: 10),

          // Role & Outlet Tags + Action Buttons
          Row(
            children: [
              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: user.roleColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.roleDisplay,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: user.roleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),

              // Outlet Badge
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.store_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        user.outletName,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions (Edit & Delete)
              if (canEdit)
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppTheme.jadeTosca,
                  ),
                  tooltip: 'Edit Pengguna',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(6),
                  onPressed: onEdit,
                ),
              if (canDelete)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.dangerRed,
                  ),
                  tooltip: 'Hapus Pengguna',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(6),
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini summary metric chip
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.lightCardBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter Choice Chip
class _FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.jadeTosca : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.jadeTosca : AppTheme.lightCardBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet Form: Tambah / Edit Pengguna
class _UserFormSheet extends ConsumerStatefulWidget {
  final UserModel currentUser;
  final ManagedUser? userToEdit;

  const _UserFormSheet({required this.currentUser, this.userToEdit});

  @override
  ConsumerState<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  late UserRole _selectedRole;
  late String _selectedOutletId;
  late String _selectedOutletName;
  bool _isLoading = false;

  bool get isEditing => widget.userToEdit != null;
  bool get isOwner => widget.currentUser.role == UserRole.owner;
  bool get isManager => widget.currentUser.role == UserRole.manager;

  @override
  void initState() {
    super.initState();
    final edit = widget.userToEdit;

    _nameController = TextEditingController(text: edit?.name ?? '');
    _emailController = TextEditingController(text: edit?.email ?? '');
    _phoneController = TextEditingController(text: edit?.phone ?? '');
    _passwordController = TextEditingController();

    if (isEditing) {
      _selectedRole = edit!.role;
      _selectedOutletId = edit.outletId;
      _selectedOutletName = edit.outletName;
    } else {
      // Default jika buat baru
      if (isManager) {
        // Manager hanya bisa buat Kasir dan terkunci di outletnya
        _selectedRole = UserRole.staff;
        _selectedOutletId = widget.currentUser.outlets.isNotEmpty
            ? widget.currentUser.outlets.first.id
            : 'out-sudirman';
        _selectedOutletName = widget.currentUser.outlets.isNotEmpty
            ? widget.currentUser.outlets.first.name
            : 'Kopi Arus - Sudirman (HQ)';
      } else {
        // Owner default buat Manager
        _selectedRole = UserRole.manager;
        _selectedOutletId = 'out-sudirman';
        _selectedOutletName = 'Kopi Arus - Sudirman (HQ)';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        await ref
            .read(userManagementProvider.notifier)
            .updateUser(
              id: widget.userToEdit!.id,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              role: isOwner ? _selectedRole : UserRole.staff,
              outletId: isOwner ? _selectedOutletId : null,
              outletName: isOwner ? _selectedOutletName : null,
              phone: _phoneController.text.trim(),
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Data pengguna "${_nameController.text.trim()}" berhasil diperbarui.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await ref
            .read(userManagementProvider.notifier)
            .createUser(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              role: isOwner ? _selectedRole : UserRole.staff,
              outletId: _selectedOutletId,
              outletName: _selectedOutletName,
              phone: _phoneController.text.trim(),
              password: _passwordController.text.trim().isNotEmpty
                  ? _passwordController.text.trim()
                  : '12345678',
            );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pengguna baru "${_nameController.text.trim()}" berhasil ditambahkan.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: AppTheme.dangerRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableOutlets = ref.watch(availableOutletsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEditing
                          ? Icons.edit_note_rounded
                          : Icons.person_add_rounded,
                      color: AppTheme.jadeTosca,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Edit Data Pengguna'
                              : (isManager
                                    ? 'Tambah Kasir Baru'
                                    : 'Tambah Akun Baru'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                            color: AppTheme.textPrimaryLight,
                          ),
                        ),
                        Text(
                          isManager
                              ? 'Daftarkan kasir untuk cabang $_selectedOutletName'
                              : 'Tetapkan role (Manager/Kasir) dan penugasan cabang outlet',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: AppTheme.lightCardBorder),
              const SizedBox(height: 18),

              // 1. Role Selection (Hanya Owner yang bisa memilih role Manager vs Kasir)
              if (isOwner) ...[
                Text(
                  'Pilih Peran (Role):',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: AppTheme.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RoleSelectCard(
                        role: UserRole.manager,
                        title: 'Manager',
                        subtitle: 'Kepala Cabang',
                        isSelected: _selectedRole == UserRole.manager,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.manager),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RoleSelectCard(
                        role: UserRole.staff,
                        title: 'Kasir',
                        subtitle: 'Staf Operasional',
                        isSelected: _selectedRole == UserRole.staff,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.staff),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 2. Outlet Assignment
              Text(
                'Penugasan Cabang Toko (Outlet):',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              if (isManager) ...[
                // Locked for Manager
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF1F5F9,
                    ), // Slate-100 disabled background
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.lightCardBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedOutletName,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Cabang Anda',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Dropdown for Owner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.lightCardBorder,
                      width: 1.0,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          availableOutlets.any((o) => o.id == _selectedOutletId)
                          ? _selectedOutletId
                          : (availableOutlets.isNotEmpty
                                ? availableOutlets.first.id
                                : null),
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textMutedLight,
                      ),
                      items: availableOutlets
                          .map(
                            (o) => DropdownMenuItem<String>(
                              value: o.id,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.storefront_rounded,
                                    size: 16,
                                    color: AppTheme.jadeTosca,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      o.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          final selected = availableOutlets.firstWhere(
                            (o) => o.id == newId,
                          );
                          setState(() {
                            _selectedOutletId = selected.id;
                            _selectedOutletName = selected.name;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 3. Nama Lengkap
              Text(
                'Nama Lengkap:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: _inputDecoration(
                  hint: isManager ? 'Misal: Siti Rahma' : 'Misal: Budi Santoso',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'Nama minimal 3 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 4. Email (Untuk Login)
              Text(
                'Alamat Email (Username Login):',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: _inputDecoration(
                  hint: 'Misal: kasir@arus.demo',
                  icon: Icons.email_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 5. Password (Hanya wajib saat buat baru)
              Text(
                isEditing
                    ? 'Password Baru (Kosongkan jika tidak diganti):'
                    : 'Password Masuk:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: _inputDecoration(
                  hint: isEditing
                      ? 'Biarkan kosong untuk mempertahankan password lama'
                      : 'Minimal 6 karakter (Default: 12345678)',
                  icon: Icons.lock_outline_rounded,
                ),
                validator: (val) {
                  if (!isEditing && (val == null || val.trim().length < 6)) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 6. Nomor Handphone (Opsional)
              Text(
                'Nomor Telepon / WhatsApp (Opsional):',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: _inputDecoration(
                  hint: 'Misal: 081234567890',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 22),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.jadeTosca,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing
                              ? 'Perbarui Data Pengguna'
                              : 'Simpan & Daftarkan Pengguna',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 13,
        color: AppTheme.textMutedLight,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.textMutedLight),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppTheme.lightCardBorder,
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: AppTheme.lightCardBorder,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.jadeTosca, width: 1.5),
      ),
    );
  }
}

/// Selector card untuk memilih role di form modal
class _RoleSelectCard extends StatelessWidget {
  final UserRole role;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleSelectCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = role == UserRole.manager
        ? const Color(0xFFD97706) // Warm Amber
        : AppTheme.jadeTosca; // Jade Tosca

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.10)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.lightCardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              role == UserRole.manager
                  ? Icons.badge_outlined
                  : Icons.point_of_sale_rounded,
              color: isSelected ? activeColor : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? activeColor
                          : AppTheme.textPrimaryLight,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: activeColor, size: 16),
          ],
        ),
      ),
    );
  }
}
