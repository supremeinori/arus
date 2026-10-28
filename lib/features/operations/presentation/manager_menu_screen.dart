import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../../pos/data/pos_catalog_repository.dart';
import '../../pos/presentation/pos_catalog_provider.dart';
import '../../pos/presentation/pos_menu_thumbnail.dart';

/// Layar Menu & Estimasi Profit untuk Akun Manager (Read-Only).
///
/// Menggunakan data dan rumus kalkulasi yang sama persis dengan Kasir POS:
///   - Sumber data: [posCatalogProvider] (endpoint `/api/pos/catalog`).
///   - Estimasi porsi dihitung secara dinamis dari resep bahan baku & stok cabang.
///   - Estimasi profit dihitung dari harga jual dikurangi HPP (unit cost) nyata.
///   - Pengelolaan (tambah/edit/hapus) dinonaktifkan sesuai RBAC (hak Owner).
class ManagerMenuScreen extends ConsumerStatefulWidget {
  const ManagerMenuScreen({super.key});

  @override
  ConsumerState<ManagerMenuScreen> createState() => _ManagerMenuScreenState();
}

class _ManagerMenuScreenState extends ConsumerState<ManagerMenuScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final outletName = user?.outlets.isNotEmpty == true
        ? user!.outlets.first.name
        : 'Cabang Anda';

    final productsAsync = ref.watch(posCatalogProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.jadeTosca,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Menu & Estimasi Profit',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$outletName • Mode Tinjauan (Read-Only)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMutedDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.jadeTosca),
            tooltip: 'Perbarui Menu',
            onPressed: () {
              ref.invalidate(posCatalogProvider);
              ref.invalidate(categoriesProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memperbarui data menu & estimasi profit...'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 900
              ? 4
              : (constraints.maxWidth >= 600 ? 3 : 2);
          final childAspectRatio = constraints.maxWidth >= 600 ? 0.95 : 0.73;

          return Column(
            children: [
              // Search & Categories Header
              _buildSearchAndCategoryHeader(categoriesAsync),

              // KPI Profit Summary Card
              productsAsync.maybeWhen(
                data: (items) => _buildProfitSummaryBanner(items),
                orElse: () => const SizedBox.shrink(),
              ),

              // Product Grid (Identik dengan UI Kasir)
              Expanded(
                child: _buildProductGrid(
                  productsAsync: productsAsync,
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Banner ringkasan estimasi profit outlet
  Widget _buildProfitSummaryBanner(List<PosCatalogItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    int totalAvailablePortions = 0;
    int totalEstimatedProfitPotential = 0;
    int totalAvailableMenuCount = 0;
    double sumMarginPct = 0;
    int itemsWithCostCount = 0;

    for (final item in items) {
      if (item.isAvailable && item.maxPortions > 0) {
        totalAvailablePortions += item.maxPortions;
        totalAvailableMenuCount++;
      }
      final cost = item.product.costIdr ?? 0;
      final price = item.product.priceIdr;
      final profit = price - cost;
      if (item.product.costIdr != null && price > 0) {
        itemsWithCostCount++;
        sumMarginPct += (profit / price) * 100;
        if (item.maxPortions > 0) {
          totalEstimatedProfitPotential += profit * item.maxPortions;
        }
      }
    }

    final avgMargin = itemsWithCostCount > 0
        ? (sumMarginPct / itemsWithCostCount).round()
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric(
            label: 'Menu Tersedia',
            value: '$totalAvailableMenuCount/${items.length}',
            subtext: '$totalAvailablePortions porsi',
            color: AppTheme.jadeTosca,
          ),
          Container(height: 30, width: 1, color: AppTheme.darkCardBorder),
          _buildSummaryMetric(
            label: 'Rata-rata Margin',
            value: '$avgMargin%',
            subtext: 'Laba kotor',
            color: const Color(0xFF10B981),
          ),
          Container(height: 30, width: 1, color: AppTheme.darkCardBorder),
          _buildSummaryMetric(
            label: 'Potensi Profit',
            value: MoneyFormatter.format(
              totalEstimatedProfitPotential,
              currency: 'IDR',
            ),
            subtext: 'Dari stok porsi',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMutedDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          subtext,
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: AppTheme.textMutedDark,
          ),
        ),
      ],
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
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textMutedDark, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
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
              height: 38,
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
    required int crossAxisCount,
    required double childAspectRatio,
  }) {
    return productsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.jadeTosca),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 40),
              const SizedBox(height: 10),
              Text(
                'Gagal memuat produk: $err',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.dangerRed),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(posCatalogProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jadeTosca,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
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
                        ? 'Belum ada produk aktif yang terdaftar di cabang ini.'
                        : 'Coba ubah kata kunci atau pilih kategori lain.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final catalogItem = filtered[index];
            return _ManagerProductCard(
              catalogItem: catalogItem,
              onTap: () => _showProductDetailSheet(context, catalogItem),
            );
          },
        );
      },
    );
  }

  /// Detail Modal Bottom Sheet untuk Manager
  void _showProductDetailSheet(BuildContext context, PosCatalogItem item) {
    final product = item.product;
    final cost = product.costIdr;
    final profit = cost != null ? (product.priceIdr - cost) : null;
    final marginPct = (cost != null && product.priceIdr > 0)
        ? ((profit! / product.priceIdr) * 100).round()
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.darkCardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: AppTheme.darkCardBorder, width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Gambar & Judul
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: PosMenuThumbnail(
                      imageUrl: product.imageUrl,
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppTheme.textPrimaryDark,
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
                                color: AppTheme.darkCardSurfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.sku,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMutedDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${product.categoryName ?? "Umum"}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppTheme.textMutedDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.darkCardBorder),
              const SizedBox(height: 12),

              // Detail Keuangan & Estimasi Profit
              Text(
                'Analisis Harga & Estimasi Profit',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMutedDark,
                ),
              ),
              const SizedBox(height: 10),

              _buildDetailRow(
                label: 'Harga Jual Konsumen',
                value: MoneyFormatter.format(product.priceIdr, currency: 'IDR'),
                valueColor: AppTheme.jadeTosca,
                isBold: true,
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                label: 'HPP / Modal Resep',
                value: cost != null
                    ? MoneyFormatter.format(cost, currency: 'IDR')
                    : 'Tidak tersedia',
                valueColor: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                label: 'Estimasi Profit per Porsi',
                value: profit != null
                    ? '${MoneyFormatter.format(profit, currency: "IDR")} ($marginPct%)'
                    : '-',
                valueColor: const Color(0xFF10B981),
                isBold: true,
              ),
              const SizedBox(height: 8),

              _buildDetailRow(
                label: 'Ketersediaan Porsi',
                value: item.isAvailable
                    ? '${item.maxPortions} Porsi'
                    : 'Habis (Bahan Kurang)',
                valueColor: item.isAvailable
                    ? const Color(0xFF0F766E)
                    : AppTheme.dangerRed,
              ),
              const SizedBox(height: 8),

              if (profit != null && item.maxPortions > 0) ...[
                _buildDetailRow(
                  label: 'Total Potensi Profit Stok',
                  value: MoneyFormatter.format(
                    profit * item.maxPortions,
                    currency: 'IDR',
                  ),
                  valueColor: const Color(0xFF10B981),
                  isBold: true,
                ),
                const SizedBox(height: 12),
              ],

              const Divider(color: AppTheme.darkCardBorder),
              const SizedBox(height: 10),

              // Catatan RBAC
              Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.textMutedDark,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Manager: Tinjauan menu & profit bersifat read-only. Pengelolaan menu (tambah/edit/hapus) merupakan hak Owner.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textMutedDark,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            color: AppTheme.textPrimaryDark.withValues(alpha: 0.8),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Kartu Produk Khusus Manajer (Read-Only)
///
/// Memiliki gaya visual identik dengan kartu kasir POS (`_RedesignedProductCard`),
/// dilengkapi badge Estimasi Porsi dan badge Estimasi Profit.
class _ManagerProductCard extends StatelessWidget {
  final PosCatalogItem catalogItem;
  final VoidCallback onTap;

  const _ManagerProductCard({
    required this.catalogItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = catalogItem.product;
    final maxPortions = catalogItem.maxPortions;
    final isOutOfStock = !catalogItem.isAvailable;

    // Kalkulasi Profit Nyata
    final cost = product.costIdr;
    final profit = cost != null ? (product.priceIdr - cost) : null;
    final marginPct = (cost != null && product.priceIdr > 0)
        ? ((profit! / product.priceIdr) * 100).round()
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isOutOfStock
              ? const Color(0xFFFEF2F2)
              : AppTheme.darkCardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOutOfStock
                ? const Color(0xFFFCA5A5)
                : AppTheme.darkCardBorder,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Gambar Menu Dominan di Atas (tinggi proporsional 85dp)
            SizedBox(
              height: 85,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: PosMenuThumbnail(
                  imageUrl: product.imageUrl,
                  width: double.infinity,
                  height: 85,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                ),
              ),
            ),

            // 2. Konten Tengah: Nama, Kategori, Badge Porsi & Profit
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
                          : 'Estimasi: $maxPortions Porsi',
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

                  // Badge Estimasi Profit
                  if (profit != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x1F10B981),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0x4010B981),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.trending_up_rounded,
                            size: 11,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'Profit: ${MoneyFormatter.format(profit, currency: "IDR")} ($marginPct%)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // 3. Konten Bawah: Harga Jual & Badge Detail (Read-Only)
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCardSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.darkCardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.visibility_outlined,
                              color: AppTheme.textMutedDark,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Info',
                              style: GoogleFonts.inter(
                                color: AppTheme.textMutedDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
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
