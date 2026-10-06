import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/inventory_models.dart';
import 'inventory_provider.dart';
import 'stock_adjustment_dialog.dart';
import 'stock_movement_screen.dart';

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

  void _openAdjustmentDialog(InventoryStockItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StockAdjustmentDialog(stockItem: item),
    );
    if (result == true) {
      ref.invalidate(inventoryListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isStaff = authState.user?.role == UserRole.staff;
    final filterState = ref.watch(inventoryFilterProvider);
    final inventoryAsync = ref.watch(inventoryListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Inventaris & Stok',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.accentBlack),
            tooltip: 'Riwayat Mutasi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockMovementScreen(outletId: filterState.outletId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlack),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(inventoryListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar & Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.lexend(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk atau SKU...',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                  onSubmitted: (val) {
                    ref.read(inventoryFilterProvider.notifier).state =
                        filterState.copyWith(searchQuery: val.trim());
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      label: Text(
                        'Semua Stok',
                        style: GoogleFonts.lexend(
                          fontSize: 12.5,
                          fontWeight: !filterState.lowStockOnly ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: !filterState.lowStockOnly,
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: TextStyle(
                        color: !filterState.lowStockOnly ? Colors.white : AppTheme.accentBlack,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(inventoryFilterProvider.notifier).state =
                              filterState.copyWith(lowStockOnly: false);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: filterState.lowStockOnly ? Colors.white : AppTheme.accentBlack,
                      ),
                      label: Text(
                        'Stok Menipis',
                        style: GoogleFonts.lexend(
                          fontSize: 12.5,
                          fontWeight: filterState.lowStockOnly ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: filterState.lowStockOnly,
                      selectedColor: AppTheme.accentBlack,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      labelStyle: TextStyle(
                        color: filterState.lowStockOnly ? Colors.white : AppTheme.accentBlack,
                      ),
                      onSelected: (selected) {
                        ref.read(inventoryFilterProvider.notifier).state =
                            filterState.copyWith(lowStockOnly: selected);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 12),

          // List Items
          Expanded(
            child: inventoryAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                    const SizedBox(height: 12),
                    Text('Gagal memuat inventaris: $err', style: GoogleFonts.lexend()),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(inventoryListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (stocks) {
                if (stocks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        Text(
                          filterState.lowStockOnly
                              ? 'Tidak ada produk dengan stok menipis.'
                              : 'Tidak ada data stok ditemukan.',
                          style: GoogleFonts.lexend(fontSize: 14, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primaryBlue,
                  onRefresh: () async => ref.invalidate(inventoryListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: stocks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = stocks[index];
                      return _buildStockCard(item, isStaff);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(InventoryStockItem item, bool isStaff) {
    final isLow = item.isLowStock;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLow ? const Color(0xFFDC2626) : AppTheme.borderOutline,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.accentBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${item.sku} • Outlet: ${item.outletName}',
                      style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLow ? const Color(0xFFDC2626) : AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderOutline, width: 1),
                ),
                child: Text(
                  '${item.quantity} ${item.unit}',
                  style: GoogleFonts.lexend(
                    color: Colors.white,
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
              Text(
                item.formattedPrice,
                style: GoogleFonts.lexend(fontWeight: FontWeight.w700, color: AppTheme.primaryBlue, fontSize: 13.5),
              ),
              if (!isStaff && item.costIdr != null) ...[
                const SizedBox(width: 12),
                Text(
                  'HPP: ${item.formattedCost}',
                  style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: Text('Opname', style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 34),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => _openAdjustmentDialog(item),
              ),
            ],
          ),
          if (isLow) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFDC2626), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 5),
                  Text(
                    'Stok di bawah batas minimum (${item.reorderLevel} ${item.unit})',
                    style: GoogleFonts.lexend(
                      fontSize: 11,
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
