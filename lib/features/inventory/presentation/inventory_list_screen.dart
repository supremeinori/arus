import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../outlets/presentation/outlets_provider.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';
import 'inventory_provider.dart';
import 'stock_adjustment_dialog.dart';
import 'add_ingredient_dialog.dart';
import 'stock_movement_screen.dart';
import '../../sensors/presentation/sensor_provider.dart';
import '../../settings/presentation/currency_provider.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAdjustmentDialog(IngredientModel item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StockAdjustmentDialog(ingredient: item),
    );
    if (result == true) {
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(inventoryListProvider);
    }
  }

  void _openAddIngredientDialog(String outletId, String outletName, [IngredientModel? existing]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AddIngredientDialog(
        outletId: outletId,
        outletName: outletName,
        existingIngredient: existing,
      ),
    );
    if (result == true) {
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(inventoryListProvider);
    }
  }

  void _confirmDeleteIngredient(IngredientModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Bahan Baku?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        // C15: konten dialog dibatasi + scroll agar tidak overflow.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apakah Anda yakin ingin menghapus bahan baku “${item.name}” dari cabang ini? Riwayat mutasi dan resep yang bersinggungan akan terpengaruh.',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.deleteIngredient(item.id);
      ref.invalidate(ingredientsListProvider);
      ref.invalidate(inventoryListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Text('Bahan baku “${item.name}” telah dihapus.', style: GoogleFonts.inter()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(ingredientsListProvider);
        ref.invalidate(inventoryListProvider);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Row(
              children: [
                const Icon(Icons.vibration_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Guncangan terdeteksi! Memperbarui data bahan baku...',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isStaff = user?.role == UserRole.staff;
    final isOwner = user?.role == UserRole.owner;
    final isManager = user?.role == UserRole.manager;

    final filterState = ref.watch(inventoryFilterProvider);
    final selectedOutletId = ref.watch(selectedOutletFilterProvider);
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final outletsAsync = ref.watch(outletsListProvider);

    // Untuk Manager: Cabang selalu terkunci pada cabang yang di-assign oleh Owner (tidak bisa memilih cabang lain)
    final assignedOutlet = isManager && user != null && user.outlets.isNotEmpty
        ? user.outlets.first
        : null;
    final effectiveOutletId = isManager
        ? assignedOutlet?.id
        : selectedOutletId;

    if (isManager && assignedOutlet != null && selectedOutletId != assignedOutlet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedOutletFilterProvider.notifier).state = assignedOutlet.id;
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isStaff ? 'Stok & Estimasi Porsi' : 'Bahan Baku & Inventaris',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!isStaff && effectiveOutletId != null)
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppTheme.textPrimaryDark),
              tooltip: 'Riwayat Mutasi',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockMovementScreen(outletId: effectiveOutletId),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Segarkan',
            onPressed: () {
              ref.invalidate(ingredientsListProvider);
              ref.invalidate(inventoryListProvider);
              ref.invalidate(productListProvider);
            },
          ),
        ],
      ),
      floatingActionButton: (!isStaff && effectiveOutletId != null)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.jadeTosca,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Tambah Bahan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () {
                final outletName = isManager
                    ? (assignedOutlet?.name ?? 'Cabang Penugasan')
                    : (outletsAsync.value?.firstWhere(
                        (o) => o.id == effectiveOutletId,
                        orElse: () => outletsAsync.value!.first,
                      ).name ?? 'Cabang Terpilih');
                _openAddIngredientDialog(effectiveOutletId, outletName);
              },
            )
          : null,
      body: Column(
        children: [
          // 1. Outlet Selector Bar khusus Owner: Bisa memilih antar cabang
          if (isOwner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppTheme.darkCardSurface,
                border: Border(
                  bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                ),
              ),
              child: AsyncStateView(
                value: outletsAsync,
                dataBuilder: (allOutlets) {
                  if (allOutlets.isEmpty) {
                    return Text(
                      'Tidak ada cabang.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
                    );
                  }

                  final currentOutletId = selectedOutletId != null && allOutlets.any((o) => o.id == selectedOutletId)
                      ? selectedOutletId
                      : allOutlets.first.id;

                  // Pastikan state selected terisi
                  if (selectedOutletId != currentOutletId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(selectedOutletFilterProvider.notifier).state = currentOutletId;
                    });
                  }

                  return Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.jadeTosca),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Cabang:',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppTheme.darkCardSurface,
                            isExpanded: true,
                            value: currentOutletId,
                            items: allOutlets.map((o) {
                              return DropdownMenuItem<String>(
                                value: o.id,
                                child: Text(
                                  o.name,
                                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(selectedOutletFilterProvider.notifier).state = val;
                                ref.invalidate(ingredientsListProvider);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            )
          // 2. Bar Cabang Khusus Manager: Terkunci pada 1 cabang penugasan oleh Owner (TIDAK BISA MEMILIH CABANG)
          else if (isManager)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.darkCardSurface,
                border: Border(
                  bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                ),
              ),
              child: assignedOutlet != null
                  ? Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.jadeTosca),
                        const SizedBox(width: 8),
                        Text(
                          'Cabang Ditugaskan:',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            assignedOutlet.name,
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.jadeTosca.withValues(alpha: 0.3), width: 1.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lock_outline_rounded, size: 12, color: AppTheme.jadeTosca),
                              const SizedBox(width: 4),
                              Text(
                                'Terkunci',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.jadeTosca),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Belum ada cabang yang ditugaskan oleh Owner.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          const Divider(height: 1),

          // Tampilan Staff (Kasir): Melihat Estimasi Porsi Menu (Read-Only)
          if (isStaff)
            const Expanded(child: _StaffPortionView())
          else ...[
            // Tampilan Owner & Manager: Manajemen Bahan Baku
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.textPrimaryDark),
                    decoration: InputDecoration(
                      hintText: 'Cari bahan baku (kopi, susu, air)...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMutedDark),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.textMutedDark),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(inventoryFilterProvider.notifier).state =
                                    filterState.copyWith(searchQuery: '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (val) {
                      ref.read(inventoryFilterProvider.notifier).state =
                          filterState.copyWith(searchQuery: val.trim());
                    },
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _InventoryFilterChip(label: 'Semua Bahan', value: 'all', isSelected: filterState.status == 'all'),
                        const SizedBox(width: 8),
                        _InventoryFilterChip(label: 'Stok Aman', value: 'ok', isSelected: filterState.status == 'ok'),
                        const SizedBox(width: 8),
                        _InventoryFilterChip(label: 'Stok Menipis', value: 'low', isSelected: filterState.status == 'low', icon: Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _InventoryFilterChip(label: 'Stok Habis', value: 'out', isSelected: filterState.status == 'out', icon: Icons.cancel_outlined, color: AppTheme.dangerRed),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),

            // List Bahan Baku
            // E24: loading/error/data lewat satu AsyncStateView.
            Expanded(
              child: AsyncStateView(
                value: ingredientsAsync,
                onRetry: () => ref.invalidate(ingredientsListProvider),
                dataBuilder: (ingredients) {
                  if (ingredients.isEmpty) {
                    return EmptyStateView(
                      message: filterState.status != 'all'
                          ? 'Tidak ada bahan baku dengan filter ini.'
                          : 'Belum ada bahan baku di cabang ini.',
                      icon: Icons.kitchen_outlined,
                      ctaText: effectiveOutletId != null ? 'Tambah Bahan Baku' : null,
                      onCtaPressed: effectiveOutletId != null
                          ? () {
                              final outletName = isManager
                                  ? (assignedOutlet?.name ?? 'Cabang Penugasan')
                                  : (outletsAsync.value?.firstWhere(
                                      (o) => o.id == effectiveOutletId,
                                      orElse: () => outletsAsync.value!.first,
                                    ).name ?? 'Cabang Terpilih');
                              _openAddIngredientDialog(effectiveOutletId, outletName);
                            }
                          : null,
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.jadeTosca,
                    onRefresh: () async => ref.invalidate(ingredientsListProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: ingredients.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        // Stat ringkas di atas daftar (lihat mockup frame Inventaris).
                        if (index == 0) {
                          return _InventoryStatStrip(ingredients: ingredients);
                        }
                        final item = ingredients[index - 1];
                        return _IngredientCard(
                          item: item,
                          onEdit: () => _openAddIngredientDialog(effectiveOutletId ?? item.outletId, item.outletName, item),
                          onDelete: () => _confirmDeleteIngredient(item),
                          onAdjust: () => _openAdjustmentDialog(item),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stat ringkas di atas daftar bahan baku: total, menipis, habis.
class _InventoryStatStrip extends StatelessWidget {
  final List<IngredientModel> ingredients;

  const _InventoryStatStrip({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final low = ingredients.where((e) => e.isLowStock).length;
    final out = ingredients.where((e) => e.isOutOfStock).length;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Total Bahan',
            value: '${ingredients.length}',
            color: AppTheme.textPrimaryDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Menipis',
            value: '$low',
            color: AppTheme.warningAmber,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: 'Habis',
            value: '$out',
            color: AppTheme.dangerRed,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// E23: chip filter sebagai widget class const (bukan helper _build*).
class _InventoryFilterChip extends ConsumerWidget {
  final String label;
  final String value;
  final bool isSelected;
  final IconData? icon;
  final Color? color;

  const _InventoryFilterChip({
    required this.label,
    required this.value,
    required this.isSelected,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilterChip(
      avatar: icon != null ? Icon(icon, size: 16, color: isSelected ? Colors.white : color) : null,
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? AppTheme.jadeTosca,
      backgroundColor: AppTheme.darkCardSurface,
      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (color ?? AppTheme.textSecondaryDark),
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(inventoryFilterProvider.notifier).state =
              ref.read(inventoryFilterProvider).copyWith(status: value);
        }
      },
    );
  }
}

/// E23: kartu bahan baku sebagai widget class (bukan helper _build* panjang).
class _IngredientCard extends ConsumerWidget {
  final IngredientModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjust;

  const _IngredientCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color cardBorder = AppTheme.darkCardBorder;
    Color badgeBg = AppTheme.darkCardSurfaceElevated;
    Color badgeColor = AppTheme.jadeTosca;
    String badgeText = item.formattedStock;

    if (item.isOutOfStock) {
      cardBorder = const Color(0x33EF4444);
      badgeBg = const Color(0x22EF4444);
      badgeColor = const Color(0xFFF87171);
    } else if (item.isLowStock) {
      cardBorder = const Color(0x33F59E0B);
      badgeBg = const Color(0x22F59E0B);
      badgeColor = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.egg_alt_outlined, color: AppTheme.jadeTosca, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Modal: ${ref.money(item.costPerUnit)} / ${item.unit} • Reorder: ${item.reorderLevel} ${item.unit}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: item.isOutOfStock
                    ? Text(
                        'Bahan Baku Habis!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dangerRed),
                      )
                    : item.isLowStock
                        ? Text(
                            'Stok Menipis (Batas: ${item.reorderLevel})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFBBF24)),
                          )
                        : Text(
                            'Stok Aman',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF10B981)),
                          ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMutedDark),
                tooltip: 'Edit Bahan',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                tooltip: 'Hapus Bahan',
                onPressed: onDelete,
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                label: Text('Sesuaikan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jadeTosca,
                  minimumSize: const Size(90, 34),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: onAdjust,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tampilan khusus Kasir: Hanya melihat daftar menu dan Estimasi Porsi (Read-Only)
  // E23: sebagai widget class (bukan helper _build*).
}

final _staffInventoryTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class _StaffPortionView extends ConsumerWidget {
  const _StaffPortionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(_staffInventoryTabProvider);
    final user = ref.watch(authProvider).user;
    final branchName = user?.outlets.isNotEmpty == true ? user!.outlets.first.name : 'Cabang Penugasan';
    final productsAsync = ref.watch(productListProvider);
    final ingredientsAsync = ref.watch(ingredientsListProvider);

    return Column(
      children: [
        // Header Info Cabang Kasir
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.darkCardSurface,
            border: Border(bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: AppTheme.jadeTosca),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stok Cabang: $branchName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.jadeTosca.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Kasir Realtime',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.jadeTosca),
                ),
              ),
            ],
          ),
        ),

        // Tab Selector Kasir: Estimasi Porsi Menu vs Stok Bahan Baku Cabang
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Estimasi Porsi Menu', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  selected: currentTab == 0,
                  onSelected: (selected) {
                    if (selected) ref.read(_staffInventoryTabProvider.notifier).state = 0;
                  },
                  backgroundColor: AppTheme.darkCardSurface,
                  selectedColor: AppTheme.jadeTosca,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: currentTab == 0 ? Colors.white : AppTheme.textSecondaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('Stok Bahan Baku', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  selected: currentTab == 1,
                  onSelected: (selected) {
                    if (selected) ref.read(_staffInventoryTabProvider.notifier).state = 1;
                  },
                  backgroundColor: AppTheme.darkCardSurface,
                  selectedColor: AppTheme.jadeTosca,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: currentTab == 1 ? Colors.white : AppTheme.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Konten Tab
        Expanded(
          child: currentTab == 0
              ? AsyncStateView(
                  value: productsAsync,
                  onRetry: () => ref.invalidate(productListProvider),
                  dataBuilder: (products) {
                    if (products.isEmpty) {
                      return const EmptyStateView(
                        message: 'Belum ada menu yang terdaftar.',
                        icon: Icons.coffee_outlined,
                      );
                    }

                    return RefreshIndicator(
                      color: AppTheme.jadeTosca,
                      onRefresh: () async {
                        ref.invalidate(productListProvider);
                        ref.invalidate(ingredientsListProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final p = products[idx];
                          final isZero = p.estimatedPortions <= 0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isZero ? const Color(0x33EF4444) : AppTheme.darkCardBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                          ? Image.network(
                                              p.imageUrl!,
                                              width: 52,
                                              height: 52,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                width: 52,
                                                height: 52,
                                                color: AppTheme.darkCardSurfaceElevated,
                                                child: const Icon(Icons.coffee_rounded, color: AppTheme.jadeTosca),
                                              ),
                                            )
                                          : Container(
                                              width: 52,
                                              height: 52,
                                              color: AppTheme.darkCardSurfaceElevated,
                                              child: const Icon(Icons.coffee_rounded, color: AppTheme.jadeTosca),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppTheme.textPrimaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${ref.money(p.priceIdr)} • SKU: ${p.sku}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isZero ? const Color(0x22EF4444) : AppTheme.darkCardSurfaceElevated,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isZero ? const Color(0x33EF4444) : AppTheme.darkCardBorder,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            isZero ? '0 Porsi' : '${p.estimatedPortions} Porsi',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isZero ? AppTheme.dangerRed : AppTheme.jadeTosca,
                                            ),
                                          ),
                                          Text(
                                            isZero ? 'Habis' : 'Estimasi',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isZero ? AppTheme.dangerRed : AppTheme.textMutedDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (isZero) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0x15EF4444),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 14, color: AppTheme.dangerRed),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            p.recipes.isEmpty
                                                ? 'Belum ada resep bahan baku yang dihubungkan ke produk ini.'
                                                : 'Bahan baku cabang belum lengkap/habis untuk membuat menu ini.',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.dangerRed),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                )
              : AsyncStateView(
                  value: ingredientsAsync,
                  onRetry: () => ref.invalidate(ingredientsListProvider),
                  dataBuilder: (ingredients) {
                    if (ingredients.isEmpty) {
                      return EmptyStateView(
                        message: 'Belum ada bahan baku fisik yang terdaftar di $branchName.',
                        icon: Icons.kitchen_outlined,
                      );
                    }

                    return RefreshIndicator(
                      color: AppTheme.jadeTosca,
                      onRefresh: () async {
                        ref.invalidate(ingredientsListProvider);
                        ref.invalidate(productListProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: ingredients.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final item = ingredients[idx];
                          final isOut = item.isOutOfStock;
                          final isLow = item.isLowStock;

                          Color badgeColor = const Color(0xFF10B981);
                          String badgeText = 'Stok Aman';
                          if (isOut) {
                            badgeColor = AppTheme.dangerRed;
                            badgeText = 'Habis';
                          } else if (isLow) {
                            badgeColor = const Color(0xFFFBBF24);
                            badgeText = 'Menipis';
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.darkCardSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isOut ? const Color(0x33EF4444) : AppTheme.darkCardBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkCardSurfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.egg_alt_outlined,
                                    color: isOut ? AppTheme.dangerRed : AppTheme.jadeTosca,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppTheme.textPrimaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Sisa: ${item.formattedStock} • Min: ${item.reorderLevel} ${item.unit}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: GoogleFonts.inter(
                                      color: badgeColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
