import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import 'catalog_provider.dart';

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
    final productsState = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
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
              onChanged: (val) {
                ref.read(searchQueryProvider.notifier).state = val;
              },
            ),
          ),

          // Horizontal Category Filter Chips
          categoriesState.when(
            data: (categories) => SizedBox(
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
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: TextStyle(
                        color: selectedCategory == null ? Colors.white : AppTheme.accentBlack,
                        fontWeight: selectedCategory == null ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (_) {
                        ref.read(selectedCategoryProvider.notifier).state = null;
                      },
                    ),
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat.name),
                        selected: selectedCategory == cat.id,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        labelStyle: TextStyle(
                          color: selectedCategory == cat.id ? Colors.white : AppTheme.accentBlack,
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
            loading: () => const SizedBox(height: 48),
            error: (_, _) => const SizedBox(height: 48),
          ),
          const Divider(height: 1),

          // Product List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(productListProvider);
                ref.invalidate(categoriesProvider);
              },
              child: AsyncStateView(
                value: productsState,
                onRetry: () => ref.refresh(productListProvider),
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

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderOutline, width: 1.0),
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
                                // Icon Box
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderOutline, width: 1.0),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.coffee_rounded,
                                      color: AppTheme.primaryBlue,
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
                                      Text(
                                        prod.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              prod.sku,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          if (prod.categoryName != null) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '• ${prod.categoryName}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
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
                                          Text(
                                            prod.formattedPrice,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                          if (canManage && prod.formattedCost != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: Colors.amber.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                'HPP: ${prod.formattedCost}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.amber.shade900,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
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
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            )
          : null,
    );
  }
}
