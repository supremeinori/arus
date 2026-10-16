import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
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
        title: Text('Hapus Bahan Baku?', style: GoogleFonts.lexend(fontWeight: FontWeight.w700)),
        content: Text(
          'Apakah Anda yakin ingin menghapus bahan baku “${item.name}” dari cabang ini? Riwayat mutasi dan resep yang bersinggungan akan terpengaruh.',
          style: GoogleFonts.lexend(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: GoogleFonts.lexend(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Hapus', style: GoogleFonts.lexend(color: Colors.white)),
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
            backgroundColor: AppTheme.accentBlack,
            content: Text('Bahan baku “${item.name}” telah dihapus.', style: GoogleFonts.lexend()),
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
            backgroundColor: AppTheme.accentBlack,
            content: Row(
              children: [
                const Icon(Icons.vibration_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Guncangan terdeteksi! Memperbarui data bahan baku...',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          isStaff ? 'Stok & Estimasi Porsi' : 'Bahan Baku & Inventaris',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (!isStaff)
            IconButton(
              icon: const Icon(Icons.history_rounded, color: AppTheme.accentBlack),
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
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
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
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text('Tambah Bahan', style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w600)),
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
              color: Colors.white,
              child: outletsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox(),
                data: (allOutlets) {
                  // Jika Manager, batasi pilihan hanya ke assigned outlets
                  final availableOutlets = isOwner
                      ? allOutlets
                      : (isManager && user != null
                          ? allOutlets.where((o) => user.outlets.any((uo) => uo.id == o.id)).toList()
                          : allOutlets);

                  if (availableOutlets.isEmpty) {
                    return Text('Tidak ada cabang yang ditugaskan.', style: GoogleFonts.lexend(fontSize: 13));
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
                      const Icon(Icons.storefront_rounded, size: 20, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        'Pilih Cabang:',
                        style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: currentOutletId,
                            items: availableOutlets.map((o) {
                              return DropdownMenuItem<String>(
                                value: o.id,
                                child: Text(
                                  o.name,
                                  style: GoogleFonts.lexend(fontSize: 13.5, fontWeight: FontWeight.w700),
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
            Expanded(child: _buildStaffPortionView())
          else ...[
            // Tampilan Owner & Manager: Manajemen Bahan Baku
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: GoogleFonts.lexend(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Cari bahan baku (kopi, susu, air)...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentBlack),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.accentBlack),
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
                        _buildFilterChip('Semua Bahan', 'all', filterState.status == 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Stok Aman', 'ok', filterState.status == 'ok'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Stok Menipis', 'low', filterState.status == 'low', Icons.warning_amber_rounded, AppTheme.dangerRed),
                        const SizedBox(width: 8),
                        _buildFilterChip('Stok Habis', 'out', filterState.status == 'out', Icons.cancel_outlined, const Color(0xFF991B1B)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 12),

            // List Bahan Baku
            Expanded(
              child: ingredientsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      Text('Gagal memuat bahan baku: $err', style: GoogleFonts.lexend()),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(ingredientsListProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
                data: (ingredients) {
                  if (ingredients.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.kitchen_outlined, size: 56, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 16),
                          Text(
                            filterState.status != 'all'
                                ? 'Tidak ada bahan baku dengan filter ini.'
                                : 'Belum ada bahan baku di cabang ini.',
                            style: GoogleFonts.lexend(fontSize: 14, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          if (selectedOutletId != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              label: Text('Tambah Bahan Baku', style: GoogleFonts.lexend(color: Colors.white)),
                              onPressed: () {
                                final outletName = outletsAsync.value?.firstWhere(
                                  (o) => o.id == selectedOutletId,
                                  orElse: () => outletsAsync.value!.first,
                                ).name ?? 'Cabang Terpilih';
                                _openAddIngredientDialog(selectedOutletId, outletName);
                              },
                            ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppTheme.primaryBlue,
                    onRefresh: () async => ref.invalidate(ingredientsListProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: ingredients.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = ingredients[index];
                        return _buildIngredientCard(item, selectedOutletId ?? '');
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

  Widget _buildFilterChip(String label, String value, bool isSelected, [IconData? icon, Color? color]) {
    return FilterChip(
      avatar: icon != null ? Icon(icon, size: 16, color: isSelected ? Colors.white : color) : null,
      label: Text(
        label,
        style: GoogleFonts.lexend(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: color ?? AppTheme.primaryBlue,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (color ?? AppTheme.accentBlack),
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(inventoryFilterProvider.notifier).state =
              ref.read(inventoryFilterProvider).copyWith(status: value);
        }
      },
    );
  }

  Widget _buildIngredientCard(IngredientModel item, String currentOutletId) {
    Color cardBorder = AppTheme.borderOutline;
    Color badgeBg = AppTheme.lightBlueBg;
    Color badgeColor = AppTheme.primaryBlue;
    String badgeText = item.formattedStock;

    if (item.isOutOfStock) {
      cardBorder = const Color(0xFFFCA5A5);
      badgeBg = const Color(0xFFFEE2E2);
      badgeColor = AppTheme.dangerRed;
    } else if (item.isLowStock) {
      cardBorder = const Color(0xFFFED7AA);
      badgeBg = const Color(0xFFFFEDD5);
      badgeColor = const Color(0xFFC2410C);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.2),
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
                  color: AppTheme.lightBlueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.egg_alt_outlined, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Modal: ${item.formattedCost} • Reorder: ${item.reorderLevel} ${item.unit}',
                      style: GoogleFonts.lexend(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.lexend(
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
              if (item.isOutOfStock)
                Text(
                  'Bahan Baku Habis!',
                  style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.dangerRed),
                )
              else if (item.isLowStock)
                Text(
                  'Stok Menipis (Batas: ${item.reorderLevel})',
                  style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFC2410C)),
                )
              else
                Text(
                  'Stok Aman',
                  style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF16A34A)),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                tooltip: 'Edit Bahan',
                onPressed: () => _openAddIngredientDialog(currentOutletId, item.outletName, item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.dangerRed),
                tooltip: 'Hapus Bahan',
                onPressed: () => _confirmDeleteIngredient(item),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                label: Text('Sesuaikan', style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  minimumSize: const Size(90, 34),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => _openAdjustmentDialog(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tampilan khusus Kasir: Hanya melihat daftar menu dan Estimasi Porsi (Read-Only)
  Widget _buildStaffPortionView() {
    final productsAsync = ref.watch(productListProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      error: (e, _) => Center(child: Text('Gagal memuat katalog: $e', style: GoogleFonts.lexend())),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Text('Tidak ada menu terdaftar.', style: GoogleFonts.lexend()),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isZero ? const Color(0xFFFCA5A5) : AppTheme.borderOutline,
                ),
              ),
              child: Row(
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
                              color: AppTheme.lightBlueBg,
                              child: const Icon(Icons.coffee_rounded, color: AppTheme.primaryBlue),
                            ),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: AppTheme.lightBlueBg,
                            child: const Icon(Icons.coffee_rounded, color: AppTheme.primaryBlue),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${p.formattedPrice} • SKU: ${p.sku}',
                          style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isZero ? const Color(0xFFFEE2E2) : AppTheme.lightBlueBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isZero ? const Color(0xFFFCA5A5) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isZero ? 'Habis' : '${p.estimatedPortions} Porsi',
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isZero ? AppTheme.dangerRed : AppTheme.primaryBlue,
                          ),
                        ),
                        Text(
                          isZero ? 'Bahan Kurang' : 'Estimasi',
                          style: GoogleFonts.lexend(
                            fontSize: 10,
                            color: isZero ? AppTheme.dangerRed : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
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
