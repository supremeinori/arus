import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/catalog_repository.dart';
import 'catalog_provider.dart';

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

  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isFetchingInitial = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _loadProductData();
    }
  }

  Future<void> _loadProductData() async {
    setState(() => _isFetchingInitial = true);
    try {
      final repo = ref.read(catalogRepositoryProvider);
      final product = await repo.getProductById(widget.productId!);
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
    } catch (e) {
      _errorMessage = 'Gagal memuat data produk: $e';
    } finally {
      if (mounted) setState(() => _isFetchingInitial = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _imageUrlController.dispose();
    super.dispose();
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

      if (widget.productId == null) {
        await repo.createProduct(
          name: _nameController.text.trim(),
          sku: _skuController.text.trim(),
          unit: _unitController.text.trim(),
          priceIdr: price,
          costIdr: cost,
          categoryId: _selectedCategoryId,
          imageUrl: imageUrl,
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
        );
      }

      ref.invalidate(productListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentBlack,
            content: Text(
              widget.productId == null
                  ? 'Produk baru berhasil ditambahkan ke database!'
                  : 'Produk berhasil diperbarui di database!',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AppException', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Tambah Produk Baru' : 'Edit Produk',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: _isFetchingInitial
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        labelText: 'Nama Produk *',
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
                          val == null || val.trim().isEmpty ? 'Nama produk wajib diisi' : null,
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
                              labelText: 'Satuan *',
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
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kategori Dropdown
                    categoriesState.when(
                      data: (categories) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: 'Kategori Produk',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                            ),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name, style: GoogleFonts.lexend(fontSize: 14)),
                            );
                          }).toList(),
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

                    // Baris Harga Jual & HPP
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
                              labelText: 'HPP / Modal (Rp)',
                              hintText: '9000',
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
                              widget.productId == null ? 'Simpan Produk Baru' : 'Simpan Perubahan',
                              style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
