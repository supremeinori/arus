import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_list.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import 'catalog_provider.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../settings/presentation/currency_provider.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role != UserRole.staff;

    final categoriesState = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final showInactive = ref.watch(showInactiveProvider);
    final productsState = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Katalog Produk'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama atau SKU produk...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.jadeTosca, width: 2),
                ),
              ),
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // Horizontal Category Filter Chips
          AsyncStateView(
            value: categoriesState,
            dataBuilder: (categories) => SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: const Text('Semua'),
                      selected: selectedCategory == null,
                      selectedColor: AppTheme.jadeTosca,
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: TextStyle(
                        color: selectedCategory == null ? Colors.white : AppTheme.textPrimaryDark,
                        fontWeight: selectedCategory == null ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        ref.read(selectedCategoryProvider.notifier).state = null;
                      },
                    ),
                  ),
                  if (canManage)
                    Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: const Text('Tampilkan nonaktif'),
                      selected: showInactive,
                      selectedColor: AppTheme.dangerTintStrong,
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: TextStyle(
                        color: showInactive
                            ? AppTheme.dangerRedStrong
                            : AppTheme.textPrimaryDark,
                        fontWeight: showInactive ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (v) {
                        ref.read(showInactiveProvider.notifier).state = v;
                      },
                    ),
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(
                          cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: selectedCategory == cat.id,
                        selectedColor: AppTheme.jadeTosca,
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        labelStyle: TextStyle(
                          color: selectedCategory == cat.id ? Colors.white : AppTheme.textPrimaryDark,
                          fontWeight: selectedCategory == cat.id ? FontWeight.w700 : FontWeight.w500,
                        ),
                        onSelected: (_) {
                          ref.read(selectedCategoryProvider.notifier).state =
                              selectedCategory == cat.id ? null : cat.id;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkCardBorder),

          // Product List
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.jadeTosca,
              onRefresh: () async {
                ref.invalidate(productListProvider);
                ref.invalidate(categoriesProvider);
              },
              child: AsyncStateView(
                value: productsState,
                onRetry: () => ref.refresh(productListProvider),
                // Kerangka kartu saat memuat, supaya tidak ada lompatan bentuk
                // dari spinner ke daftar penuh.
                skeleton: const SkeletonList(),
                dataBuilder: (products) {
                  if (products.isEmpty) {
                    return const EmptyStateView(
                      message: 'Belum ada produk yang cocok dengan pencarian.',
                      icon: Icons.inventory_2_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final prod = products[index];

                      // Tepi kartu produk dibuat lebih tegas supaya batas tiap
                      // produk terbaca. Elemen di dalam kartu (kotak gambar, chip
                      // SKU) tetap hairline Slate-200: batas luar harus lebih
                      // kuat dari garis di dalamnya (revisi 27 Okt 2026).
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.lightCardBorderStrong,
                            width: AppTheme.hairline,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            context.push('/catalog/${prod.id}');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon / Image Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.darkCardSurfaceElevated,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: (prod.imageUrl != null && prod.imageUrl!.isNotEmpty)
                                      ? Image.network(
                                          prod.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Center(
                                            child: Icon(
                                              Icons.coffee_rounded,
                                              color: AppTheme.jadeTosca,
                                              size: 24,
                                            ),
                                          ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.coffee_rounded,
                                            color: AppTheme.jadeTosca,
                                            size: 24,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),

                                // Product Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prod.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.textPrimaryDark,
                                                  ),
                                            ),
                                          ),
                                          if (!prod.isActive) ...[
                                            const SizedBox(width: 6),
                                            StatusBadge.danger(
                                              label: 'NONAKTIF',
                                              fontSize: 11,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          StatusBadge.neutral(
                                            label: prod.sku,
                                            fontSize: 11,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          ),
                                          if (prod.categoryName != null) ...[
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '• ${prod.categoryName}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: AppTheme.textMutedDark,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Pricing
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: MoneyText(
                                              prod.priceIdr,
                                              maxLines: 1,
                                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.jadeTosca,
                                                  ),
                                            ),
                                          ),
                                          if (canManage && prod.costIdr != null)
                                            StatusBadge.warning(
                                              label: 'HPP: ${ref.money(prod.costIdr!)}',
                                              fontSize: 11,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Estimasi Porsi Badge
                                      StatusBadge(
                                        label: prod.estimatedPortions > 0
                                            ? 'Estimasi: ${prod.estimatedPortions} Porsi'
                                            : 'Habis (Bahan Baku Kurang)',
                                        kind: prod.estimatedPortions > 0
                                            ? StatusKind.primary
                                            : StatusKind.danger,
                                        fontSize: 11,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () {
                context.push('/catalog/new');
              },
              backgroundColor: AppTheme.jadeTosca,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            )
          : null,
    );
  }
}
