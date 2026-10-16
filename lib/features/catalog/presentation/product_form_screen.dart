import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../data/catalog_repository.dart';
import '../domain/product_model.dart';
import 'catalog_provider.dart';

class _RecipeRow {
  String? ingredientId;
  final TextEditingController amountController;

  _RecipeRow({this.ingredientId, int? amount})
      : amountController = TextEditingController(text: amount != null && amount > 0 ? amount.toString() : '');

  void dispose() {
    amountController.dispose();
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId; // Null = create, non-null = edit

  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _unitController = TextEditingController(text: 'cup');
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final List<_RecipeRow> _recipeRows = [];
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isInit = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _imageUrlController.dispose();
    for (final r in _recipeRows) {
      r.dispose();
    }
    super.dispose();
  }

  void _populateExisting(ProductModel product) {
    if (_isInit) return;
    _isInit = true;

    _nameController.text = product.name;
    _skuController.text = product.sku;
    _unitController.text = product.unit;
    _priceController.text = product.priceIdr.toString();
    if (product.costIdr != null) {
      _costController.text = product.costIdr.toString();
    }
    if (product.imageUrl != null) {
      _imageUrlController.text = product.imageUrl!;
    }
    _selectedCategoryId = product.categoryId;

    for (final r in _recipeRows) {
      r.dispose();
    }
    _recipeRows.clear();
    if (product.recipes.isNotEmpty) {
      for (final r in product.recipes) {
        _recipeRows.add(_RecipeRow(
          ingredientId: r.ingredientId,
          amount: r.amountNeeded,
        ));
      }
    }
  }

  void _addRecipeRow() {
    setState(() {
      _recipeRows.add(_RecipeRow());
    });
  }

  void _removeRecipeRow(int index) {
    setState(() {
      if (index >= 0 && index < _recipeRows.length) {
        final removed = _recipeRows.removeAt(index);
        removed.dispose();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(catalogRepositoryProvider);
      final price = int.parse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final cost = _costController.text.isNotEmpty
          ? int.parse(_costController.text.replaceAll(RegExp(r'[^0-9]'), ''))
          : null;
      final imageUrl = _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim();

      final List<Map<String, dynamic>> recipesPayload = [];
      for (final r in _recipeRows) {
        if (r.ingredientId != null && r.ingredientId!.isNotEmpty) {
          final amt = int.tryParse(r.amountController.text.trim()) ?? 0;
          if (amt > 0) {
            recipesPayload.add({
              'ingredient_id': r.ingredientId!,
              'amount_needed': amt,
            });
          }
        }
      }

      if (widget.productId == null) {
        await repo.createProduct(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          unit: _unitController.text.trim(),
          priceIdr: price,
          costIdr: cost,
          categoryId: _selectedCategoryId,
          imageUrl: imageUrl,
          recipes: recipesPayload,
        );
      } else {
        await repo.updateProduct(
          widget.productId!,
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          unit: _unitController.text.trim(),
          priceIdr: price,
          costIdr: cost,
          categoryId: _selectedCategoryId,
          imageUrl: imageUrl,
          recipes: recipesPayload,
        );
        ref.invalidate(productDetailProvider(widget.productId!));
      }

      ref.invalidate(productListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentBlack,
            content: Text(
              widget.productId == null
                  ? 'Produk & resep berhasil disimpan!'
                  : 'Produk & resep berhasil diperbarui!',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AppException', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;

    if (isEditing) {
      final productAsync = ref.watch(productDetailProvider(widget.productId!));
      return productAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppTheme.backgroundWhite,
          appBar: AppBar(
            title: Text(
              'Edit Menu / Produk',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Scaffold(
          backgroundColor: AppTheme.backgroundWhite,
          appBar: AppBar(
            title: Text(
              'Edit Menu / Produk',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat produk: $err',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(fontSize: 14, color: AppTheme.accentBlack),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(productDetailProvider(widget.productId!)),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (product) {
          _populateExisting(product);
          return _buildFormScaffold(context);
        },
      );
    }

    return _buildFormScaffold(context);
  }

  Widget _buildFormScaffold(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);
    final ingredientsState = ref.watch(ingredientsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Tambah Menu / Produk' : 'Edit Menu / Produk',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.lexend(color: const Color(0xFFDC2626), fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Nama Produk
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.lexend(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nama Menu / Produk *',
                hintText: 'Contoh: Es Kopi Susu Aren',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'Nama menu wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Baris SKU & Satuan
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _skuController,
                    style: GoogleFonts.lexend(fontSize: 14),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'SKU *',
                      hintText: 'KOP-03',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'SKU wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _unitController,
                    style: GoogleFonts.lexend(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'cup',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kategori Dropdown
            categoriesState.when(
              data: (categories) {
                final uniqueCategories = <String, String>{};
                for (final c in categories) {
                  if (c.id.isNotEmpty) {
                    uniqueCategories[c.id] = c.name;
                  }
                }

                final isValidCat = _selectedCategoryId != null &&
                    uniqueCategories.containsKey(_selectedCategoryId);
                final selectedVal = isValidCat ? _selectedCategoryId : null;

                return DropdownButtonFormField<String?>(
                  initialValue: selectedVal,
                  decoration: InputDecoration(
                    labelText: 'Kategori Produk',
                    hintText: 'Pilih Kategori Produk',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tanpa Kategori', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    ...uniqueCategories.entries.map((entry) {
                      return DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value, style: GoogleFonts.lexend(fontSize: 14)),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryId = val;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // URL Foto / Gambar Produk
            TextFormField(
              controller: _imageUrlController,
              style: GoogleFonts.lexend(fontSize: 14),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'URL Gambar Menu (Unsplash / Web)',
                hintText: 'https://images.unsplash.com/...',
                prefixIcon: const Icon(Icons.image_outlined, color: AppTheme.primaryBlue, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Baris Harga Jual & HPP Estimasi
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.lexend(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Harga Jual (Rp) *',
                      hintText: '22000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Harga jual wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.lexend(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'HPP Manual (Opsional)',
                      hintText: 'Otomatis dari resep',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================
            // SEKSI KOMPOSISI RESEP (PRODUCT RECIPES)
            // ==========================================
            Container(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Komposisi Resep Menu',
                            style: GoogleFonts.lexend(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentBlack,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Takaran bahan baku per 1 porsi pesanan',
                            style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _addRecipeRow,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Bahan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.lightBlueBg,
                          foregroundColor: AppTheme.primaryBlue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppTheme.primaryBlue, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.borderOutline),

                  if (_recipeRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Belum ada takaran resep. Klik "+ Bahan" untuk menambahkan bahan baku.',
                          style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ingredientsState.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Gagal memuat bahan: $e', style: GoogleFonts.lexend(fontSize: 12)),
                      data: (availableIngredients) {
                        final uniqueMap = <String, IngredientModel>{};
                        for (final ing in availableIngredients) {
                          if (ing.id.isNotEmpty) {
                            uniqueMap[ing.id] = ing;
                          }
                        }
                        final ingredientsList = uniqueMap.values.toList();

                        return Column(
                          children: [
                            for (int idx = 0; idx < _recipeRows.length; idx++) ...[
                              Builder(
                                builder: (context) {
                                  final row = _recipeRows[idx];
                                  final selectedIngredient = ingredientsList
                                      .cast<IngredientModel?>()
                                      .firstWhere((i) => i?.id == row.ingredientId, orElse: () => null);

                                  final isKnown = row.ingredientId != null &&
                                      ingredientsList.any((i) => i.id == row.ingredientId);
                                  final effectiveVal = isKnown ? row.ingredientId : null;

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.borderOutline),
                                    ),
                                    child: Row(
                                      children: [
                                        // Dropdown Bahan Baku
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String?>(
                                            isExpanded: true,
                                            initialValue: effectiveVal,
                                            decoration: InputDecoration(
                                              labelText: 'Pilih Bahan Baku',
                                              hintText: 'Pilih Bahan',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            items: [
                                              const DropdownMenuItem<String?>(
                                                value: null,
                                                child: Text('-- Pilih Bahan --', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                              ),
                                              ...ingredientsList.map((ing) {
                                                return DropdownMenuItem<String?>(
                                                  value: ing.id,
                                                  child: Text(
                                                    '${ing.name} (${ing.unit})',
                                                    style: GoogleFonts.lexend(fontSize: 12.5),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }),
                                            ],
                                            onChanged: (val) {
                                              setState(() {
                                                row.ingredientId = val;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Takaran
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: row.amountController,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            style: GoogleFonts.lexend(fontSize: 12.5),
                                            decoration: InputDecoration(
                                              labelText: 'Takaran',
                                              hintText: '18',
                                              suffixText: selectedIngredient?.unit ?? '',
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),

                                        // Tombol Hapus Baris
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 20),
                                          onPressed: () => _removeRecipeRow(idx),
                                          tooltip: 'Hapus bahan ini',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (idx < _recipeRows.length - 1) const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.productId == null ? 'Simpan Menu Baru' : 'Simpan Perubahan Menu',
                      style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
