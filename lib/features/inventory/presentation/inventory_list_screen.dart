import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('Inventaris & Stok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
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
            icon: const Icon(Icons.refresh_rounded),
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
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk atau SKU...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(inventoryFilterProvider.notifier).state =
                                  filterState.copyWith(searchQuery: '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (val) {
                    ref.read(inventoryFilterProvider.notifier).state =
                        filterState.copyWith(searchQuery: val.trim());
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Semua Stok'),
                      selected: !filterState.lowStockOnly,
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(inventoryFilterProvider.notifier).state =
                              filterState.copyWith(lowStockOnly: false);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                      label: const Text('Stok Menipis'),
                      selected: filterState.lowStockOnly,
                      selectedColor: Colors.amber.shade100,
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
          const Divider(height: 1),

          // List Items
          Expanded(
            child: inventoryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Gagal memuat inventaris: $err'),
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
                        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          filterState.lowStockOnly
                              ? 'Tidak ada produk dengan stok menipis.'
                              : 'Tidak ada data stok ditemukan.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
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

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLow ? Colors.amber.shade400 : Colors.grey.shade300,
          width: isLow ? 1.5 : 1.0,
        ),
      ),
      color: isLow ? Colors.amber.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${item.sku} • Outlet: ${item.outletName}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLow ? Colors.amber.shade700 : Colors.teal.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${item.quantity} ${item.unit}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                ),
                if (!isStaff && item.costIdr != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    'HPP: ${item.formattedCost}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Opname'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _openAdjustmentDialog(item),
                ),
              ],
            ),
            if (isLow) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Stok di bawah batas minimum (${item.reorderLevel} ${item.unit})',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
