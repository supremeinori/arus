import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../inventory/domain/inventory_models.dart';
import '../../inventory/presentation/inventory_provider.dart';
import '../data/catalog_repository.dart';
import '../domain/product_model.dart';
import '../../../core/utils/money_formatter.dart';
import 'catalog_provider.dart';
import 'widgets/product_image_url_field.dart';

class _RecipeRow {
  String? ingredientId;
  // Nama & satuan bahan ikut disimpan dari resep yang dimuat. Dipakai untuk
  // menampilkan bahan yang tidak ada di daftar inventory (mis. terfilter).
  String? ingredientName;
  String? ingredientUnit;
  final TextEditingController amountController;

  _RecipeRow({
    this.ingredientId,
    this.ingredientName,
    this.ingredientUnit,
    int? amount,
  }) : amountController = TextEditingController(text: amount != null && amount > 0 ? amount.toString() : '');

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
          ingredientName: r.ingredientName,
          ingredientUnit: r.ingredientUnit,
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
          // Hanya kosongkan kalau memang form ini yang mengosongkan field
          // tersebut (kategori/foto dihapus user), bukan karena form tidak
          // punya field-nya sama sekali.
          clearCategory: _selectedCategoryId == null,
          clearImage: imageUrl == null,
        );
        ref.invalidate(productDetailProvider(widget.productId!));
      }

      ref.invalidate(productListProvider);

      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.textPrimaryDark,
            content: Text(
              widget.productId == null
                  ? 'Produk & resep berhasil disimpan!'
                  : 'Produk & resep berhasil diperbarui!',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
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
      // E24: loading/error/data lewat satu AsyncStateView dalam satu Scaffold
      // (satu AppBar saja, anti judul ganda). Mode data memakai Scaffold-less
      // body agar tidak ada Scaffold bertumpuk.
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          title: Text(
            'Edit Menu / Produk',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ),
        body: AsyncStateView(
          value: productAsync,
          onRetry: () => ref.refresh(productDetailProvider(widget.productId!)),
          dataBuilder: (product) {
            _populateExisting(product);
            return _ProductFormBody(
              formKey: _formKey,
              nameController: _nameController,
              skuController: _skuController,
              unitController: _unitController,
              priceController: _priceController,
              costController: _costController,
              imageUrlController: _imageUrlController,
              recipeRows: _recipeRows,
              selectedCategoryId: _selectedCategoryId,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              isEditing: true,
              showScaffold: false,
              onCategoryChanged: (val) => setState(() => _selectedCategoryId = val),
              onAddRecipeRow: _addRecipeRow,
              onRemoveRecipeRow: _removeRecipeRow,
              onSubmit: _submit,
            );
          },
        ),
      );
    }

    return _ProductFormBody(
      formKey: _formKey,
      nameController: _nameController,
      skuController: _skuController,
      unitController: _unitController,
      priceController: _priceController,
      costController: _costController,
      imageUrlController: _imageUrlController,
      recipeRows: _recipeRows,
      selectedCategoryId: _selectedCategoryId,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isEditing: false,
      onCategoryChanged: (val) => setState(() => _selectedCategoryId = val),
      onAddRecipeRow: _addRecipeRow,
      onRemoveRecipeRow: _removeRecipeRow,
      onSubmit: _submit,
    );
  }
}

/// E23: badan form sebagai widget class (bukan helper _build* yang panjang).
/// Berbentuk StatefulWidget agar perubahan baris resep lokal bisa rebuild
/// lewat setState sendiri; state induk tetap pemilik controller & data.
class _ProductFormBody extends ConsumerStatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController skuController;
  final TextEditingController unitController;
  final TextEditingController priceController;
  final TextEditingController costController;
  final TextEditingController imageUrlController;
  final List<_RecipeRow> recipeRows;
  final String? selectedCategoryId;
  final bool isLoading;
  final String? errorMessage;
  final bool isEditing;
  final bool showScaffold;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onAddRecipeRow;
  final void Function(int index) onRemoveRecipeRow;
  final VoidCallback onSubmit;

  const _ProductFormBody({
    required this.formKey,
    required this.nameController,
    required this.skuController,
    required this.unitController,
    required this.priceController,
    required this.costController,
    required this.imageUrlController,
    required this.recipeRows,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.errorMessage,
    required this.isEditing,
    this.showScaffold = true,
    required this.onCategoryChanged,
    required this.onAddRecipeRow,
    required this.onRemoveRecipeRow,
    required this.onSubmit,
  });

  @override
  ConsumerState<_ProductFormBody> createState() => _ProductFormBodyState();
}

class _ProductFormBodyState extends ConsumerState<_ProductFormBody> {
  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: widget.formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.errorMessage != null) ...[
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
                        widget.errorMessage!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Nama Produk
            TextFormField(
              controller: widget.nameController,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nama Menu / Produk *',
                hintText: 'Contoh: Es Kopi Susu Aren',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                    controller: widget.skuController,
                    style: GoogleFonts.inter(fontSize: 14),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'SKU *',
                      hintText: 'KOP-03',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                    controller: widget.unitController,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Satuan',
                      hintText: 'cup',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kategori Dropdown
            // E24: loading/error tampil ringkas, data lewat satu builder.
            AsyncStateView(
              value: ref.watch(categoriesProvider),
              dataBuilder: (categories) {
                final uniqueCategories = <String, String>{};
                for (final c in categories) {
                  if (c.id.isNotEmpty) {
                    uniqueCategories[c.id] = c.name;
                  }
                }

                final isValidCat = widget.selectedCategoryId != null &&
                    uniqueCategories.containsKey(widget.selectedCategoryId);
                final selectedVal = isValidCat ? widget.selectedCategoryId : null;

                return DropdownButtonFormField<String?>(
                  initialValue: selectedVal,
                  decoration: InputDecoration(
                    labelText: 'Kategori Produk',
                    hintText: 'Pilih Kategori Produk',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tanpa Kategori', style: TextStyle(color: AppTheme.textMutedDark)),
                    ),
                    ...uniqueCategories.entries.map((entry) {
                      return DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      );
                    }),
                  ],
                  onChanged: widget.onCategoryChanged,
                );
              },
            ),
            const SizedBox(height: 16),

            // URL Foto / Gambar Produk (opsional) + preview langsung.
            ProductImageUrlField(
              controller: widget.imageUrlController,
            ),
            const SizedBox(height: 16),

            // Baris Harga Jual & HPP Estimasi
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: widget.priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText:
                          'Harga Jual (${MoneyFormatter.symbolOf(MoneyFormatter.defaultCurrency).trim()}) *',
                      hintText: '22000',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Harga jual wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: widget.costController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'HPP Manual (Opsional)',
                      hintText: 'Otomatis dari resep',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Komposisi Resep Menu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Takaran bahan baku per 1 porsi pesanan',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: widget.onAddRecipeRow,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Bahan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkCardSurfaceElevated,
                          foregroundColor: AppTheme.jadeTosca,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppTheme.jadeTosca, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.darkCardBorder),

                  if (widget.recipeRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Belum ada takaran resep. Klik "+ Bahan" untuk menambahkan bahan baku.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    // E24: loading/error/data bahan lewat satu AsyncStateView.
                    AsyncStateView(
                      value: ref.watch(ingredientsListProvider),
                      dataBuilder: (availableIngredients) {
                        final uniqueMap = <String, IngredientModel>{};
                        for (final ing in availableIngredients) {
                          if (ing.id.isNotEmpty) {
                            uniqueMap[ing.id] = ing;
                          }
                        }
                        final ingredientsList = uniqueMap.values.toList();

                        // Opsi dropdown digabung dengan bahan yang sudah dipakai
                        // produk. Bahan tersimpan bisa tidak muncul di daftar
                        // inventory (filter outlet/status/pencarian), sehingga
                        // resep akan tampil kosong padahal data tersimpan.
                        final optionLabels = <String, String>{};
                        final optionUnits = <String, String>{};
                        for (final ing in ingredientsList) {
                          optionLabels[ing.id] = '${ing.name} (${ing.unit})';
                          optionUnits[ing.id] = ing.unit;
                        }
                        for (final r in widget.recipeRows) {
                          final id = r.ingredientId;
                          if (id == null || id.isEmpty || optionLabels.containsKey(id)) continue;
                          optionLabels[id] =
                              '${r.ingredientName ?? 'Bahan tidak tersedia'} (${r.ingredientUnit ?? ''})';
                          optionUnits[id] = r.ingredientUnit ?? '';
                        }

                        return Column(
                          children: [
                            for (int idx = 0; idx < widget.recipeRows.length; idx++) ...[
                              Builder(
                                builder: (context) {
                                  final row = widget.recipeRows[idx];
                                  final selectedIngredient = ingredientsList
                                      .cast<IngredientModel?>()
                                      .firstWhere((i) => i?.id == row.ingredientId, orElse: () => null);

                                  final isKnown = row.ingredientId != null &&
                                      optionLabels.containsKey(row.ingredientId);
                                  final effectiveVal = isKnown ? row.ingredientId : null;
                                  final selectedUnit = selectedIngredient?.unit ??
                                      (row.ingredientId != null ? optionUnits[row.ingredientId] : null) ??
                                      '';

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.darkCardSurfaceElevated,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.darkCardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        // Dropdown Bahan Baku
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<String?>(
                                            isExpanded: true,
                                            dropdownColor: AppTheme.darkCardSurface,
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
                                                child: Text('-- Pilih Bahan --', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                              ),
                                              ...optionLabels.entries.map((entry) {
                                                return DropdownMenuItem<String?>(
                                                  value: entry.key,
                                                  child: Text(
                                                    entry.value,
                                                    style: GoogleFonts.inter(fontSize: 12.5),
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
                                            style: GoogleFonts.inter(fontSize: 12.5),
                                            decoration: InputDecoration(
                                              labelText: 'Takaran',
                                              hintText: '18',
                                              suffixText: selectedUnit,
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
                                          onPressed: () {
                                            widget.onRemoveRecipeRow(idx);
                                            setState(() {});
                                          },
                                          tooltip: 'Hapus bahan ini',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (idx < widget.recipeRows.length - 1) const SizedBox(height: 10),
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
              onPressed: widget.isLoading ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.jadeTosca,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.isEditing ? 'Simpan Perubahan Menu' : 'Simpan Menu Baru',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ],
        ),
    );

    if (!widget.showScaffold) return form;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Menu / Produk' : 'Tambah Menu / Produk',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: form,
    );
  }
}
