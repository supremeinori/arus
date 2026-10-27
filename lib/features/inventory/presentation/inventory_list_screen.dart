import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
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
        title: Text('Hapus Bahan Baku?', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            // Gaya teks diserahkan ke tema supaya seragam dengan tombol Batal lain.
            child: const Text('Batal'),
          ),
          ElevatedButton(
            // Tombol hapus tetap merah, tetapi sudut dan gaya teks diserahkan ke tema.
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
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
            content: Text('Bahan baku “${item.name}” telah dihapus.'),
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
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
    final selectedOutletId = ref.watch(selectedInventoryOutletProvider);
    final ingredientsAsync = ref.watch(ingredientsListProvider);
    final outletsAsync = ref.watch(outletsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isStaff ? 'Stok & Estimasi Porsi' : 'Bahan Baku & Inventaris',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!isStaff)
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppTheme.textPrimaryDark),
              tooltip: 'Riwayat Mutasi',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockMovementScreen(outletId: selectedOutletId),
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
      floatingActionButton: (!isStaff && selectedOutletId != null)
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.jadeTosca,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Tambah Bahan', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () {
                final outletName = outletsAsync.value?.firstWhere(
                  (o) => o.id == selectedOutletId,
                  orElse: () => outletsAsync.value!.first,
                ).name ?? 'Cabang Terpilih';
                _openAddIngredientDialog(selectedOutletId, outletName);
              },
            )
          : null,
      body: Column(
        children: [
          // Outlet Selector Bar untuk Owner & Manager
          if (!isStaff)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: AppTheme.darkCardSurface,
                border: Border(
                  bottom: BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
                ),
              ),
              child: AsyncStateView(
                value: outletsAsync,
                dataBuilder: (allOutlets) {
                  // Jika Manager, batasi pilihan hanya ke assigned outlets
                  final availableOutlets = isOwner
                      ? allOutlets
                      : (isManager && user != null
                          ? allOutlets.where((o) => user.outlets.any((uo) => uo.id == o.id)).toList()
                          : allOutlets);

                  if (availableOutlets.isEmpty) {
                    return Text(
                      'Tidak ada cabang yang ditugaskan.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMutedDark),
                    );
                  }

                  final currentOutletId = selectedOutletId != null && availableOutlets.any((o) => o.id == selectedOutletId)
                      ? selectedOutletId
                      : availableOutlets.first.id;

                  // Pastikan state selected terisi
                  if (selectedOutletId != currentOutletId) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(selectedInventoryOutletProvider.notifier).state = currentOutletId;
                    });
                  }

                  return Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.jadeTosca),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Cabang:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppTheme.darkCardSurface,
                            isExpanded: true,
                            value: currentOutletId,
                            items: availableOutlets.map((o) {
                              return DropdownMenuItem<String>(
                                value: o.id,
                                child: Text(
                                  o.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(selectedInventoryOutletProvider.notifier).state = val;
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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimaryDark),
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
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InventoryFilterChip(
                          label: 'Semua Bahan',
                          value: 'all',
                          isSelected: filterState.status == 'all',
                        ),
                        const SizedBox(width: 8),

                        _InventoryFilterChip(
                          label: 'Stok Aman',
                          value: 'ok',
                          isSelected: filterState.status == 'ok',
                        ),
                        const SizedBox(width: 8),

                        _InventoryFilterChip(
                          label: 'Stok Menipis',
                          value: 'low',
                          isSelected: filterState.status == 'low',
                          icon: Icons.warning_amber_rounded,
                          color: AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 8),

                        _InventoryFilterChip(
                          label: 'Stok Habis',
                          value: 'out',
                          isSelected: filterState.status == 'out',
                          icon: Icons.cancel_outlined,
                          color: AppTheme.dangerRed,
                        ),
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
                // Kerangka kartu saat memuat, supaya tidak ada lompatan bentuk
                // dari spinner ke daftar penuh.
                skeleton: const SkeletonList(),
                dataBuilder: (ingredients) {
                  if (ingredients.isEmpty) {
                    return EmptyStateView(
                      message: filterState.status != 'all'
                          ? 'Tidak ada bahan baku dengan filter ini.'
                          : 'Belum ada bahan baku di cabang ini.',
                      icon: Icons.kitchen_outlined,
                      ctaText: selectedOutletId != null ? 'Tambah Bahan Baku' : null,
                      onCtaPressed: selectedOutletId != null
                          ? () {
                              final outletName = outletsAsync.value?.firstWhere(
                                (o) => o.id == selectedOutletId,
                                orElse: () => outletsAsync.value!.first,
                              ).name ?? 'Cabang Terpilih';
                              _openAddIngredientDialog(selectedOutletId, outletName);
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
                          onEdit: () => _openAddIngredientDialog(selectedOutletId ?? '', item.outletName, item),
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textMutedDark),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color, letterSpacing: -0.3),
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : (color ?? AppTheme.textSecondaryDark),
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? AppTheme.jadeTosca,
      backgroundColor: AppTheme.darkCardSurface,
      side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    StatusKind stockKind;
    String stockLabel = item.formattedStock;
    String statusLabel;
    StatusKind statusKind;

    if (item.isOutOfStock) {
      stockKind = StatusKind.danger;
      statusLabel = 'Habis';
      statusKind = StatusKind.danger;
    } else if (item.isLowStock) {
      stockKind = StatusKind.warning;
      statusLabel = 'Menipis (Batas: ${item.reorderLevel})';
      statusKind = StatusKind.warning;
    } else {
      stockKind = StatusKind.success;
      statusLabel = 'Aman';
      statusKind = StatusKind.success;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightCardBorder, width: AppTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === AREA ATAS (fixed height 96px) ===
          SizedBox(
            height: 96,
            child: Row(
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryDark,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Modal: ${ref.money(item.costPerUnit)} / ${item.unit} • Reorder: ${item.reorderLevel} ${item.unit}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMutedDark,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Spacing antar area atas & baris aksi
          const SizedBox(height: 10),

          // === BARIS AKSI (Row FIXED — tidak Wrap) ===
          // Setiap kolom punya lebar EKSPLISIT → posisi X & Y SELALU SAMA di semua kartu.
          // Gap antar kolom: 12px (lebih longgar dari 8px sebelumnya).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge stok: mengikuti isi dengan batas maksimum
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 60,
                    maxWidth: 100,
                  ),
                  child: StatusBadge(
                    label: stockLabel,
                    kind: stockKind,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Badge status: mengambil ruang yang tersedia
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 150,
                    ),
                    child: StatusBadge(
                      label: statusLabel,
                      kind: statusKind,
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Tombol edit
              SizedBox(
                width: 32,
                height: 36,
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppTheme.textMutedDark,
                  ),
                  tooltip: 'Edit Bahan',
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),

              const SizedBox(width: 4),

              // Tombol hapus
              SizedBox(
                width: 32,
                height: 36,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.dangerRed,
                  ),
                  tooltip: 'Hapus Bahan',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),

              const SizedBox(width: 6),

              // Tombol sesuaikan
              SizedBox(
                width: 96,
                height: 34,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Sesuaikan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.jadeTosca,
                    minimumSize: const Size(96, 34),
                    maximumSize: const Size(96, 34),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onAdjust,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Tampilan khusus Kasir: Hanya melihat daftar menu dan Estimasi Porsi (Read-Only)
  // E23: sebagai widget class (bukan helper _build*).
}

class _StaffPortionView extends ConsumerWidget {
  const _StaffPortionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);

    // E24: loading/error/data lewat satu AsyncStateView.
    return AsyncStateView(
      value: productsAsync,
      onRetry: () => ref.invalidate(productListProvider),
      dataBuilder: (products) {
        if (products.isEmpty) {
          return const EmptyStateView(
            message: 'Tidak ada menu terdaftar.',
            icon: Icons.coffee_outlined,
          );
        }

        return ListView.separated(
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
                  color: isZero ? AppTheme.dangerTintStrong : AppTheme.darkCardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === AREA ATAS (fixed height 82px) ===
                  SizedBox(
                    height: 82,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ref.money(p.priceIdr)} • SKU: ${p.sku}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMutedDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacing antar area atas & badge estimasi
                  const SizedBox(height: 10),

                  // === BADGE ESTIMASI (Row FIXED — posisi kanan tetap) ===
                  // Posisi Y-nya FIXED: 92px dari atas kartu (82 + 10).
                  // Badge diletakkan di kolom kanan dengan lebar tetap 120px,
                  // di dalam Row yang memenuhi lebar kartu → selalu kanan, tidak bergerak.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isZero ? AppTheme.dangerTint : AppTheme.darkCardSurfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isZero ? AppTheme.dangerTintStrong : AppTheme.darkCardBorder,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isZero ? 'Habis' : '${p.estimatedPortions} Porsi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isZero ? AppTheme.dangerRed : AppTheme.jadeTosca,
                                    ),
                              ),
                              Text(
                                isZero ? 'Bahan Kurang' : 'Estimasi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isZero ? AppTheme.dangerRed : AppTheme.textMutedDark,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
