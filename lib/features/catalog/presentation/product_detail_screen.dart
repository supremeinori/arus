import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/product_model.dart';
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
          // A3: satu CustomScrollView dengan slivers untuk konten campuran
          // (kartu header + resep + daftar stok outlet), tanpa shrinkWrap.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ProductHeaderCard(prod: prod, canManage: canManage),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: _ProductRecipeCard(prod: prod),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Ketersediaan Stok per Outlet',
                    style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                  ),
                ),
              ),
              if (prod.outletStock.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      child: Text(
                        'Belum ada data stok yang terhubung.',
                        style: GoogleFonts.lexend(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OutletStockCard(
                          prod: prod,
                          stock: prod.outletStock[index],
                        ),
                      ),
                      childCount: prod.outletStock.length,
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

/// E23: kartu header produk sebagai widget class (bukan helper _build*).
class _ProductHeaderCard extends StatelessWidget {
  final ProductModel prod;
  final bool canManage;

  const _ProductHeaderCard({required this.prod, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
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
                  color: prod.isActive ? AppTheme.lightBlueBg : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: prod.isActive ? const Color(0xFFBFDBFE) : const Color(0xFFFCA5A5),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  prod.isActive ? 'AKTIF' : 'NONAKTIF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: prod.isActive ? AppTheme.primaryBlue : AppTheme.dangerRed,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prod.sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prod.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.accentBlack),
          ),
          if (prod.categoryName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kategori: ${prod.categoryName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.textMuted),
            ),
          ],
          const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harga Jual / ${prod.unit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prod.formattedPrice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage && prod.formattedCost != null)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'HPP (Modal)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prod.formattedCost!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentBlack,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// E23: kartu estimasi & resep sebagai widget class (bukan helper _build*).
class _ProductRecipeCard extends StatelessWidget {
  final ProductModel prod;

  const _ProductRecipeCard({required this.prod});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Estimasi Ketersediaan Menu',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: prod.estimatedPortions > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: prod.estimatedPortions > 0 ? const Color(0xFF93C5FD) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Text(
                  prod.estimatedPortions > 0
                      ? '${prod.estimatedPortions} Porsi'
                      : 'Habis (Bahan Kurang)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prod.estimatedPortions > 0 ? AppTheme.primaryBlue : AppTheme.dangerRed,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.borderOutline),
          Text(
            'Komposisi Resep (Bahan Baku per Porsi):',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const SizedBox(height: 8),
          if (prod.recipes.isEmpty)
            Text(
              'Belum ada komposisi resep yang dikonfigurasi.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...prod.recipes.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '• ${r.ingredientName ?? 'Bahan'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.accentBlack),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${r.amountNeeded} ${r.ingredientUnit ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// E23: kartu stok outlet sebagai widget class (bukan helper _build*).
class _OutletStockCard extends StatelessWidget {
  final ProductModel prod;
  final ProductOutletStock stock;

  const _OutletStockCard({required this.prod, required this.stock});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
      ),
      child: ListTile(
        leading: Icon(
          Icons.storefront_rounded,
          color: stock.quantity <= stock.reorderLevel
              ? AppTheme.dangerRed
              : AppTheme.primaryBlue,
        ),
        title: Text(
          stock.outletName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          'Batas minimum restock: ${stock.reorderLevel} ${prod.unit}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        // B9: trailing ListTile dibatasi lebarnya agar tidak unbounded width.
        trailing: SizedBox(
          width: 110,
          child: Container(
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
    );
  }
}
