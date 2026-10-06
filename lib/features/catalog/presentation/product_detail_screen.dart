import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import 'catalog_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role != UserRole.staff;
    final productState = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                context.push('/catalog/$productId/edit');
              },
            ),
        ],
      ),
      body: AsyncStateView(
        value: productState,
        onRetry: () => ref.refresh(productDetailProvider(productId)),
        dataBuilder: (prod) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Product Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prod.isActive ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: prod.isActive ? Colors.green.shade200 : Colors.red.shade200,
                              ),
                            ),
                            child: Text(
                              prod.isActive ? 'AKTIF' : 'NONAKTIF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: prod.isActive ? Colors.green.shade800 : Colors.red.shade800,
                              ),
                            ),
                          ),
                          Text(
                            prod.sku,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        prod.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (prod.categoryName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kategori: ${prod.categoryName}',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Harga Jual / ${prod.unit}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prod.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          if (canManage && prod.formattedCost != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'HPP (Modal)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  prod.formattedCost!,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Outlet Stock List
              const Text(
                'Ketersediaan Stok per Outlet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (prod.outletStock.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Belum ada data stok yang terhubung.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ...prod.outletStock.map(
                  (stock) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        Icons.storefront_rounded,
                        color: stock.quantity <= stock.reorderLevel
                            ? AppTheme.dangerRed
                            : AppTheme.primaryBlue,
                      ),
                      title: Text(stock.outletName),
                      subtitle: Text('Batas minimum restock: ${stock.reorderLevel} ${prod.unit}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stock.quantity <= stock.reorderLevel
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stock.quantity <= stock.reorderLevel
                                ? Colors.red.shade200
                                : Colors.green.shade200,
                          ),
                        ),
                        child: Text(
                          '${stock.quantity} ${prod.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: stock.quantity <= stock.reorderLevel
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
