import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
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
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Pencarian Global',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari menu, SKU, atau cabang toko...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: Colors.white,
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
              onChanged: _performSearch,
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
            )
          else
            Expanded(
              child: _searchController.text.trim().isEmpty
                  ? Center(
                      child: Text(
                        'Ketik kata kunci untuk mencari seluruh menu dan cabang.',
                        style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B)),
                      ),
                    )
                  : (_matchingProducts.isEmpty && _matchingOutlets.isEmpty)
                      ? Center(
                          child: Text(
                            'Tidak ada hasil ditemukan.',
                            style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (_matchingProducts.isNotEmpty) ...[
                              Text(
                                'Katalog Produk (${_matchingProducts.length})',
                                style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                              ),
                              const SizedBox(height: 8),
                              ..._matchingProducts.map((p) => Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.coffee_rounded, color: AppTheme.primaryBlue),
                                      title: Text(p.name, style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                      subtitle: Text('${p.sku} • ${p.categoryName ?? "Umum"}', style: GoogleFonts.lexend(fontSize: 12)),
                                      trailing: Text(p.formattedPrice, style: GoogleFonts.lexend(fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                                      onTap: () => context.push('/catalog/${p.id}'),
                                    ),
                                  )),
                              const SizedBox(height: 14),
                            ],

                            if (_matchingOutlets.isNotEmpty) ...[
                              Text(
                                'Cabang Outlet (${_matchingOutlets.length})',
                                style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentBlack),
                              ),
                              const SizedBox(height: 8),
                              ..._matchingOutlets.map((o) => Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.storefront_rounded, color: Color(0xFF16A34A)),
                                      title: Text(o.name, style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                      subtitle: Text(o.address, style: GoogleFonts.lexend(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                                      onTap: () => context.push('/outlets/${o.id}'),
                                    ),
                                  )),
                            ],
                          ],
                        ),
            ),
        ],
      ),
    );
  }
}
