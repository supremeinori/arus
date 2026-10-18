import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../outlets/data/outlets_repository.dart';
import '../../catalog/domain/product_model.dart';
import '../../outlets/domain/outlet_models.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  List<ProductModel> _matchingProducts = [];
  List<OutletModel> _matchingOutlets = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _matchingProducts = [];
        _matchingOutlets = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final catalogRepo = ref.read(catalogRepositoryProvider);
      final outletsRepo = ref.read(outletsRepositoryProvider);

      final prods = await catalogRepo.getProducts(q: q);
      final allOutlets = await outletsRepo.getOutlets();
      final filteredOutlets = allOutlets.where((o) =>
          o.name.toLowerCase().contains(q) || o.address.toLowerCase().contains(q)).toList();

      if (mounted) {
        setState(() {
          _matchingProducts = prods;
          _matchingOutlets = filteredOutlets;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Pencarian Global',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _searchController,
                    hintText: 'Cari menu, SKU, atau cabang toko...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: _performSearch,
                  ),
                ),
                if (_searchController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
                ],
              ],
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppTheme.jadeTosca)),
            )
          else
            Expanded(
              child: _searchController.text.trim().isEmpty
                  ? const EmptyStateView(
                      message: 'Ketik kata kunci untuk mencari seluruh menu dan cabang.',
                      icon: Icons.search_rounded,
                    )
                  : (_matchingProducts.isEmpty && _matchingOutlets.isEmpty)
                      ? const EmptyStateView(
                          message: 'Tidak ada hasil ditemukan.',
                          icon: Icons.search_off_rounded,
                        )
                      // Hasil kecil — render inline tanpa scroll bersarang ganda (aturan A4).
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (_matchingProducts.isNotEmpty) ...[
                              Text(
                                'Katalog Produk (${_matchingProducts.length})',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              ..._matchingProducts.map((p) => _ProductResultCard(product: p)),
                              const SizedBox(height: 14),
                            ],

                            if (_matchingOutlets.isNotEmpty) ...[
                              Text(
                                'Cabang Outlet (${_matchingOutlets.length})',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              ..._matchingOutlets.map((o) => _OutletResultCard(outlet: o)),
                            ],
                          ],
                        ),
            ),
        ],
      ),
    );
  }
}

/// Kartu hasil produk — widget class top-level (aturan E23).
class _ProductResultCard extends StatelessWidget {
  final ProductModel product;

  const _ProductResultCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: ListTile(
        leading: const Icon(Icons.coffee_rounded, color: AppTheme.jadeTosca),
        title: Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${p.sku} • ${p.categoryName ?? "Umum"}', style: GoogleFonts.inter(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: SizedBox(
          width: 100,
          child: Text(
            p.formattedPrice,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.jadeTosca),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
        onTap: () => context.push('/catalog/${p.id}'),
      ),
    );
  }
}

/// Kartu hasil outlet — widget class top-level (aturan E23).
class _OutletResultCard extends StatelessWidget {
  final OutletModel outlet;

  const _OutletResultCard({required this.outlet});

  @override
  Widget build(BuildContext context) {
    final o = outlet;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: ListTile(
        leading: const Icon(Icons.storefront_rounded, color: Color(0xFF16A34A)),
        title: Text(o.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(o.address, style: GoogleFonts.inter(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const SizedBox(
          width: 24,
          child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ),
        onTap: () => context.push('/outlets/${o.id}'),
      ),
    );
  }
}
