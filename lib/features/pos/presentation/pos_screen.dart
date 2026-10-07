import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../catalog/presentation/catalog_provider.dart';
import 'pos_provider.dart';
import 'pos_checkout_sheet.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;

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
    final productsAsync = ref.watch(productListProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final cartState = ref.watch(posCartProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.accentBlack),
                tooltip: 'Kembali',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'Kasir POS',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_outlined, color: AppTheme.primaryBlue),
            tooltip: 'Tambah Produk Baru',
            onPressed: () => context.push('/catalog/new'),
          ),
          if (cartState.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppTheme.accentBlack),
              tooltip: 'Kosongkan Keranjang',
              onPressed: () => ref.read(posCartProvider.notifier).clearCart(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Category Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk atau SKU...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Categories Filter Horisontal
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (categories) {
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: Text(
                        'Semua',
                        style: GoogleFonts.lexend(
                          fontSize: 12.5,
                          fontWeight: _selectedCategoryId == null ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      selected: _selectedCategoryId == null,
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null ? Colors.white : AppTheme.accentBlack,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategoryId = null);
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
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.accentBlack,
                          ),
                          onSelected: (selected) {
                            setState(() => _selectedCategoryId = selected ? cat.id : null);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 16),

          // Product Grid
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
              ),
              error: (err, _) => Center(
                child: Text('Gagal memuat produk: $err', style: GoogleFonts.lexend()),
              ),
              data: (products) {
                // Filter lokal berdasarkan pencarian & kategori
                final query = _searchController.text.trim().toLowerCase();
                final filtered = products.where((p) {
                  final matchesCat = _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
                  final matchesQuery = query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.sku.toLowerCase().contains(query);
                  return matchesCat && matchesQuery && p.isActive;
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            products.isEmpty ? 'Katalog Masih Kosong' : 'Tidak Ada Produk Sesuai',
                            style: GoogleFonts.lexend(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            products.isEmpty
                                ? 'Tambahkan produk baru ke katalog untuk mulai transaksi.'
                                : 'Coba ubah kata kunci atau pilih kategori lain.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexend(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/catalog/new'),
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            label: Text(
                              'Tambah Produk Baru',
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final screenWidth = MediaQuery.sizeOf(context).width;
                final crossAxisCount = screenWidth >= 900 ? 4 : (screenWidth >= 600 ? 3 : 2);

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: screenWidth >= 600 ? 1.2 : 1.05,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final inCart = cartState.items.any((i) => i.productId == product.id);

                    return InkWell(
                      onTap: () => ref.read(posCartProvider.notifier).addProduct(product),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: inCart ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: inCart ? AppTheme.primaryBlue : AppTheme.borderOutline,
                            width: inCart ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.lexend(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: AppTheme.accentBlack,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              product.categoryName ?? 'Umum',
                              style: GoogleFonts.lexend(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  product.formattedPrice,
                                  style: GoogleFonts.lexend(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: inCart ? AppTheme.primaryBlue : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: inCart ? Colors.white : AppTheme.primaryBlue,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Bottom Bar Keranjang Belanja
          if (cartState.items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cartState.totalItemsCount} Item Terpilih',
                          style: GoogleFonts.lexend(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currencyFormatter.format(cartState.totalIdr),
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentBlack,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _showCheckoutSheet,
                      icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      label: Text(
                        'Checkout',
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        elevation: 0,
                        minimumSize: const Size(130, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
