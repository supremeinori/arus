import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Detail Produk',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.accentBlack),
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
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderOutline, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: prod.isActive ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: prod.isActive ? AppTheme.primaryBlue : AppTheme.dangerRed,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            prod.isActive ? 'AKTIF' : 'NONAKTIF',
                            style: GoogleFonts.lexend(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: prod.isActive ? AppTheme.primaryBlue : AppTheme.dangerRed,
                            ),
                          ),
                        ),
                        Text(
                          prod.sku,
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      prod.name,
                      style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentBlack),
                    ),
                    if (prod.categoryName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Kategori: ${prod.categoryName}',
                        style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    ],
                    const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Harga Jual / ${prod.unit}',
                              style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prod.formattedPrice,
                              style: GoogleFonts.lexend(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                                style: GoogleFonts.lexend(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                prod.formattedCost!,
                                style: GoogleFonts.lexend(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentBlack,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Outlet Stock List
              Text(
                'Ketersediaan Stok per Outlet',
                style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
              ),
              const SizedBox(height: 10),
              if (prod.outletStock.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderOutline, width: 1.5),
                  ),
                  child: Text(
                    'Belum ada data stok yang terhubung.',
                    style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 13),
                  ),
                )
              else
                ...prod.outletStock.map(
                  (stock) => Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.storefront_rounded,
                        color: stock.quantity <= stock.reorderLevel
                            ? AppTheme.dangerRed
                            : AppTheme.primaryBlue,
                      ),
                      title: Text(stock.outletName, style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        'Batas minimum restock: ${stock.reorderLevel} ${prod.unit}',
                        style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: stock.quantity <= stock.reorderLevel
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: stock.quantity <= stock.reorderLevel
                                ? AppTheme.dangerRed
                                : AppTheme.primaryBlue,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${stock.quantity} ${prod.unit}',
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: stock.quantity <= stock.reorderLevel
                                ? AppTheme.dangerRed
                                : AppTheme.primaryBlue,
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
