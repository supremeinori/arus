import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';
import '../../../core/utils/money_formatter.dart';

class AddIngredientDialog extends ConsumerStatefulWidget {
  final String outletId;
  final String outletName;
  final IngredientModel? existingIngredient;

  const AddIngredientDialog({
    super.key,
    required this.outletId,
    required this.outletName,
    this.existingIngredient,
  });

  @override
  ConsumerState<AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends ConsumerState<AddIngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _stockController;
  late final TextEditingController _reorderController;
  late final TextEditingController _costController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final ing = widget.existingIngredient;
    _nameController = TextEditingController(text: ing?.name ?? '');
    _unitController = TextEditingController(text: ing?.unit ?? 'gram');
    _stockController = TextEditingController(text: ing != null ? '${ing.stockQty}' : '1000');
    _reorderController = TextEditingController(text: ing != null ? '${ing.reorderLevel}' : '200');
    _costController = TextEditingController(text: ing != null ? '${ing.costPerUnit}' : '100');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final isEditing = widget.existingIngredient != null;

      if (isEditing) {
        await repo.updateIngredient(
          widget.existingIngredient!.id,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          reorderLevel: int.tryParse(_reorderController.text.trim()) ?? 100,
          costPerUnit: int.tryParse(_costController.text.trim()) ?? 0,
        );
      } else {
        await repo.createIngredient(
          outletId: widget.outletId,
          name: _nameController.text.trim(),
          unit: _unitController.text.trim(),
          stockQty: int.tryParse(_stockController.text.trim()) ?? 0,
          reorderLevel: int.tryParse(_reorderController.text.trim()) ?? 100,
          costPerUnit: int.tryParse(_costController.text.trim()) ?? 0,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.jadeTosca,
            content: Text(
              isEditing ? 'Bahan baku berhasil diperbarui.' : 'Bahan baku baru berhasil ditambahkan.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingIngredient != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Edit Bahan Baku' : 'Tambah Bahan Baku Baru',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            'Cabang: ${widget.outletName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
          ),
        ],
      ),
      // C15: konten dialog dibatasi lebarnya agar tidak overflow di layar sempit.
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerTint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.dangerTintStrong),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.dangerRedStrong),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Bahan Baku *',
                  hintText: 'Misal: Biji Kopi Espresso, Susu UHT, Air Mineral',
                  isDense: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Satuan (Unit) *',
                        hintText: 'gram, ml, pcs',
                        isDense: true,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (!isEditing)
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok Awal',
                          hintText: '0',
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas Minimum (Reorder)',
                        hintText: '100',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Modal/Unit (${MoneyFormatter.symbolOf(MoneyFormatter.defaultCurrency).trim()})',
                        hintText: '150',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          // Gaya teks diserahkan ke tema. Sebelumnya di sini dipaksa abu-abu dan
          // bobot regular, jadi tampil berbeda dari tombol Batal lain.
          child: const Text('Batal'),
        ),
        ElevatedButton(
          // Sudut 8 di sini berbeda dari 12 milik tema, jadi tombol ini satu-satunya
          // yang bermata lebih tumpul di dialog. Gaya diserahkan ke tema.
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEditing ? 'Simpan Perubahan' : 'Tambah Bahan'),
        ),
      ],
    );
  }
}
