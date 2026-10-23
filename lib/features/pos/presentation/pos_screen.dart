import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/sync/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../settings/presentation/currency_provider.dart';
import '../../sensors/presentation/sensor_provider.dart';
import 'pos_provider.dart';
import 'pos_cart_sheet.dart';
import 'pos_menu_thumbnail.dart';
import 'pos_catalog_provider.dart';
import 'pos_checkout_sheet.dart';
import '../data/pos_catalog_repository.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOfflineData();
    });
  }

  Future<void> _syncOfflineData() async {
    try {
      final syncService = ref.read(syncServiceProvider);
      final result = await syncService.syncPendingTransactions();
      if (mounted && result.totalPending > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Sinkronisasi selesai.'),
            backgroundColor: result.failedCount == 0
                ? const Color(0xFF059669)
                : const Color(0xFFD97706),
          ),
        );
        ref.invalidate(productListProvider);
      }
    } catch (_) {
      // Offline safe fallback
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PosCheckoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Shake-to-Refresh Listener
    ref.listen<DateTime?>(shakeEventProvider, (prev, next) {
      if (next != null) {
        ref.invalidate(productListProvider);
        ref.invalidate(categoriesProvider);
        _syncOfflineData();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Row(
              children: [
                const Icon(
                  Icons.vibration_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Guncangan terdeteksi! Memperbarui katalog POS...',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    final productsAsync = ref.watch(posCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(posCartProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCardSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimaryDark),
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.jadeTosca, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Kasir POS',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.receipt_long_outlined,
              color: AppTheme.jadeTosca,
            ),
            tooltip: 'Riwayat Transaksi Hari Ini',
            onPressed: () => context.push('/pos/history'),
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.jadeTosca),
            tooltip: 'Sinkronisasi Transaksi Offline',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final result = await ref
                    .read(syncServiceProvider)
                    .syncPendingTransactions();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.message ?? 'Sinkronisasi selesai.'),
                    backgroundColor: result.failedCount == 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                );
                ref.invalidate(productListProvider);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Sinkronisasi gagal: $e'),
                    backgroundColor: AppTheme.dangerRed,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: cartState.items.isEmpty
                  ? AppTheme.textMutedDark.withValues(alpha: 0.4)
                  : AppTheme.dangerRed,
            ),
            tooltip: 'Kosongkan Keranjang',
            onPressed: cartState.items.isEmpty
                ? null
                : () => ref.read(posCartProvider.notifier).clearCart(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTabletOrDesktop = constraints.maxWidth > 800;

          if (isTabletOrDesktop) {
            // ==========================================
            // SPLIT-SCREEN VIEW (Desktop / Tablet >= 800)
            // ==========================================
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sisi Kiri: Katalog Produk & Kategori
                Expanded(
                  flex: 65,
                  child: Column(
                    children: [
                      _buildSearchAndCategoryHeader(categoriesAsync),
                      Expanded(
                        child: _buildProductGrid(
                          productsAsync: productsAsync,
                          cartState: cartState,
                          crossAxisCount: constraints.maxWidth >= 1100 ? 4 : 3,
                          childAspectRatio: 0.74,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hairline Divider
                const VerticalDivider(width: 1, color: AppTheme.darkCardBorder),

                // Sisi Kanan: Panel Keranjang Permanen
                SizedBox(
                  width: 375,
                  child: _PosCartDesktopPanel(
                    cartState: cartState,
                    onCheckout: _showCheckoutSheet,
                  ),
                ),
              ],
            );
          }

          // ==========================================
          // SINGLE-COLUMN VIEW (Mobile < 800)
          // ==========================================
          return Column(
            children: [
              _buildSearchAndCategoryHeader(categoriesAsync),
              Expanded(
                child: _buildProductGrid(
                  productsAsync: productsAsync,
                  cartState: cartState,
                  crossAxisCount: constraints.maxWidth >= 600 ? 3 : 2,
                  childAspectRatio: constraints.maxWidth >= 600 ? 1.05 : 0.82,
                ),
              ),
              _buildMobileBottomCartBar(cartState),
            ],
          );
        },
      ),
    );
  }

  /// Search & Category Filter Header
  Widget _buildSearchAndCategoryHeader(AsyncValue<List<dynamic>> categoriesAsync) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimaryDark,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              hintText: 'Cari menu, kopi, atau SKU...',
              hintStyle: GoogleFonts.inter(
                color: AppTheme.textMutedDark,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppTheme.darkCardSurface,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.textMutedDark,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.jadeTosca,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Horizontal Category Pills
        categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (categories) {
            return SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: Text(
                      'Semua',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: _selectedCategoryId == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    selected: _selectedCategoryId == null,
                    selectedColor: AppTheme.jadeTosca,
                    backgroundColor: AppTheme.darkCardSurface,
                    side: BorderSide(
                      color: _selectedCategoryId == null
                          ? AppTheme.jadeTosca
                          : AppTheme.darkCardBorder,
                      width: 1.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    labelStyle: TextStyle(
                      color: _selectedCategoryId == null
                          ? Colors.white
                          : AppTheme.textMutedDark,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategoryId = null);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.jadeTosca,
                        backgroundColor: AppTheme.darkCardSurface,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.jadeTosca
                              : AppTheme.darkCardBorder,
                          width: 1.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textMutedDark,
                        ),
                        onSelected: (selected) {
                          setState(
                            () => _selectedCategoryId = selected
                                ? cat.id
                                : null,
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const Divider(height: 14, color: AppTheme.darkCardBorder),
      ],
    );
  }

  /// Product Catalog Grid
  Widget _buildProductGrid({
    required AsyncValue<List<PosCatalogItem>> productsAsync,
    required PosCartState cartState,
    required int crossAxisCount,
    required double childAspectRatio,
  }) {
    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.jadeTosca),
      ),
      error: (err, _) => Center(
        child: Text(
          'Gagal memuat produk: $err',
          style: GoogleFonts.inter(color: AppTheme.dangerRed),
        ),
      ),
      data: (catalogItems) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = catalogItems.where((c) {
          final p = c.product;
          final matchesCat =
              _selectedCategoryId == null ||
              p.categoryId == _selectedCategoryId;
          final matchesQuery =
              query.isEmpty ||
              p.name.toLowerCase().contains(query) ||
              p.sku.toLowerCase().contains(query);
          return matchesCat && matchesQuery;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 36,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    catalogItems.isEmpty
                        ? 'Katalog Masih Kosong'
                        : 'Tidak Ada Menu Sesuai',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    catalogItems.isEmpty
                        ? 'Tambahkan produk baru ke katalog untuk mulai transaksi kasir.'
                        : 'Coba ubah kata kunci atau pilih kategori lain.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/catalog/new'),
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      'Tambah Menu Baru',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.jadeTosca,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          // Napas vertikal tambahan supaya grid tidak menempel ke chip kategori.
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final catalogItem = filtered[index];
            final product = catalogItem.product;
            final maxPortions = catalogItem.maxPortions;
            final inCart = cartState.items.any(
              (i) => i.productId == product.id,
            );
            final isOutOfStock = !catalogItem.isAvailable;
            final cartItem = cartState.items.cast<dynamic>().firstWhere(
              (i) => i.productId == product.id,
              orElse: () => null,
            );
            final inCartQty = cartItem != null
                ? (cartItem.quantity as int)
                : 0;
            final remainingPortions = (maxPortions - inCartQty).clamp(
              0,
              maxPortions > 0 ? maxPortions : 0,
            );

            return _RedesignedProductCard(
              catalogItem: catalogItem,
              inCart: inCart,
              inCartQty: inCartQty,
              remainingPortions: remainingPortions,
              isOutOfStock: isOutOfStock,
              onTap: () {
                if (isOutOfStock) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Menu ${product.name} habis (bahan baku tidak cukup).',
                      ),
                      backgroundColor: AppTheme.dangerRed,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                final ok = ref
                    .read(posCartProvider.notifier)
                    .addProduct(product, maxPortions: maxPortions);
                if (!ok) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Maksimal estimasi porsi tercapai ($maxPortions porsi).',
                      ),
                      backgroundColor: const Color(0xFFD97706),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  /// Floating Bottom Cart Bar for Mobile
  Widget _buildMobileBottomCartBar(PosCartState cartState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cartState.items.isEmpty
                        ? 'Ketuk menu untuk menambah'
                        : '${cartState.totalItemsCount} Item Terpilih',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  MoneyText(
                    cartState.totalIdr,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cartState.items.isEmpty
                          ? AppTheme.textMutedDark
                          : AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: OutlinedButton.icon(
                onPressed: cartState.items.isEmpty
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const PosCartSheet(),
                        );
                      },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text(
                  'Keranjang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.jadeTosca,
                  side: BorderSide(
                    color: cartState.items.isEmpty
                        ? AppTheme.darkCardBorder
                        : AppTheme.jadeTosca,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: cartState.items.isEmpty
                  ? null
                  : _showCheckoutSheet,
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Checkout',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: cartState.items.isEmpty
                    ? AppTheme.darkCardSurfaceElevated
                    : AppTheme.jadeTosca,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Redesigned Product Card ala RestroBit / Foodigo
class _RedesignedProductCard extends StatelessWidget {
  final PosCatalogItem catalogItem;
  final bool inCart;
  final int inCartQty;
  final int remainingPortions;
  final bool isOutOfStock;
  final VoidCallback onTap;

  const _RedesignedProductCard({
    required this.catalogItem,
    required this.inCart,
    required this.inCartQty,
    required this.remainingPortions,
    required this.isOutOfStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = catalogItem.product;
    final maxPortions = catalogItem.maxPortions;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isOutOfStock
              ? const Color(0xFFFEF2F2)
              : (inCart
                  ? const Color(0xFFF0FDFA)
                  : AppTheme.darkCardSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOutOfStock
                ? const Color(0xFFFCA5A5)
                : (inCart
                    ? AppTheme.jadeTosca
                    : AppTheme.darkCardBorder),
            width: inCart ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Gambar Menu Dominan di Atas (tinggi proporsional 85dp)
            SizedBox(
              height: 85,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: PosMenuThumbnail(
                      imageUrl: product.imageUrl,
                      width: double.infinity,
                      height: 85,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    ),
                  ),
                  if (inCartQty > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppTheme.jadeTosca,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$inCartQty di Pesanan',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Konten Tengah: Nama, Kategori & Badge Estimasi Porsi
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isOutOfStock
                          ? const Color(0xFFB91C1C)
                          : AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.categoryName ?? 'Umum',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Signature Badge ARUS: Estimasi Porsi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'Habis (Bahan Kurang)'
                          : (inCartQty > 0
                              ? 'Sisa: $remainingPortions / $maxPortions porsi'
                              : 'Estimasi: $maxPortions Porsi'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isOutOfStock
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF0F766E),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Konten Bawah: Harga & Tombol + ADD
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: MoneyText(
                          product.priceIdr,
                          maxLines: 1,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            color: isOutOfStock
                                ? AppTheme.textMutedDark
                                : AppTheme.jadeTosca,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? AppTheme.darkCardSurfaceElevated
                              : AppTheme.jadeTosca,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOutOfStock
                                  ? Icons.block_rounded
                                  : Icons.add,
                              color: isOutOfStock
                                  ? AppTheme.textMutedDark
                                  : Colors.white,
                              size: 14,
                            ),
                            if (!isOutOfStock) ...[
                              const SizedBox(width: 3),
                              Text(
                                'ADD',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ],
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
    );
  }
}

/// Permanent Desktop/Tablet Right Cart Panel ala RestroBit
class _PosCartDesktopPanel extends ConsumerWidget {
  final PosCartState cartState;
  final VoidCallback onCheckout;

  const _PosCartDesktopPanel({
    required this.cartState,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(posCartProvider.notifier);

    return Container(
      color: AppTheme.darkCardSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Cart Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppTheme.jadeTosca, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Daftar Pesanan',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cartState.totalItemsCount} item',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkCardBorder),

          // Items List
          Expanded(
            child: cartState.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_shopping_cart_outlined,
                            size: 40,
                            color: AppTheme.textMutedDark.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keranjang masih kosong',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMutedDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Klik menu pada katalog untuk menambahkan ke pesanan.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: AppTheme.textMutedDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 12, color: AppTheme.darkCardBorder),
                    itemBuilder: (context, i) {
                      final item = cartState.items[i];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AppTheme.textPrimaryDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ref.money(item.unitPriceIdr),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textMutedDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                            color: AppTheme.textMutedDark,
                            onPressed: () => notifier.decrementProduct(item.productId),
                            tooltip: 'Kurangi',
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            '${item.quantity}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimaryDark,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 18, color: AppTheme.jadeTosca),
                            onPressed: () => notifier.addProductById(item.productId),
                            tooltip: 'Tambah',
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.dangerRed),
                            onPressed: () => notifier.removeProduct(item.productId),
                            tooltip: 'Hapus baris',
                            visualDensity: VisualDensity.compact,
                          ),
                          SizedBox(
                            width: 72,
                            child: Text(
                              ref.money(item.lineTotalIdr),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.textPrimaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Order Summary Breakdown Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              border: Border(
                top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMutedDark)),
                    MoneyText(
                      cartState.subtotalIdr,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ],
                ),
                if (cartState.discountIdr > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Diskon', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.dangerRed)),
                      Text(
                        '- ${ref.money(cartState.discountIdr)}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppTheme.darkCardBorder),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Bayar',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    MoneyText(
                      cartState.totalIdr,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.jadeTosca,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: cartState.items.isEmpty ? null : onCheckout,
                  icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.jadeTosca,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
