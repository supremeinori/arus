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
import '../../../shared/widgets/app_widgets.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final canManage = user?.role != UserRole.staff;
    final productState = ref.watch(productDetailProvider(productId));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Detail Produk',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.textPrimaryDark),
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
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
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
                        color: AppTheme.darkCardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      child: Text(
                        'Belum ada data stok yang terhubung.',
                        style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 13),
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
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
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
                  color: prod.isActive ? const Color(0x1F00A896) : const Color(0x26EF4444),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: prod.isActive ? const Color(0x4000A896) : const Color(0x40EF4444),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  prod.isActive ? 'AKTIF' : 'NONAKTIF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: prod.isActive ? AppTheme.jadeTosca : const Color(0xFFEF4444),
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
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMutedDark,
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
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimaryDark),
          ),
          if (prod.categoryName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kategori: ${prod.categoryName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
            ),
          ],
          const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.0),
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
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                    ),
                    const SizedBox(height: 2),
                    MoneyText(
                      prod.priceIdr,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.jadeTosca,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage && prod.costIdr != null)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'HPP (Modal)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                      ),
                      const SizedBox(height: 2),
                      MoneyText(
                        prod.costIdr!,
                        maxLines: 1,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimaryDark,
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
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
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
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: prod.estimatedPortions > 0 ? const Color(0x1F00A896) : const Color(0x26EF4444),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: prod.estimatedPortions > 0 ? const Color(0x4000A896) : const Color(0x40EF4444),
                  ),
                ),
                child: Text(
                  prod.estimatedPortions > 0
                      ? '${prod.estimatedPortions} Porsi'
                      : 'Habis (Bahan Kurang)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prod.estimatedPortions > 0 ? AppTheme.jadeTosca : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.darkCardBorder),
          Text(
            'Komposisi Resep (Bahan Baku per Porsi):',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondaryDark),
          ),
          const SizedBox(height: 8),
          if (prod.recipes.isEmpty)
            Text(
              'Belum ada komposisi resep yang dikonfigurasi.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
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
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${r.amountNeeded} ${r.ingredientUnit ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.jadeTosca),
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
    final isLow = stock.quantity <= stock.reorderLevel;
    final statusColor = isLow ? const Color(0xFFEF4444) : AppTheme.jadeTosca;
    final statusBg = isLow ? const Color(0x26EF4444) : const Color(0x1F00A896);

    return Card(
      elevation: 0,
      color: AppTheme.darkCardSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: ListTile(
        leading: Icon(
          Icons.storefront_rounded,
          color: statusColor,
        ),
        title: Text(
          stock.outletName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark),
        ),
        subtitle: Text(
          'Batas minimum restock: ${stock.reorderLevel} ${prod.unit}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
        ),
        trailing: SizedBox(
          width: 110,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              '${stock.quantity} ${prod.unit}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: statusColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
