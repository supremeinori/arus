import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final IngredientModel? ingredient;
  final InventoryStockItem? stockItem;

  const StockAdjustmentDialog({
    super.key,
    this.ingredient,
    this.stockItem,
  }) : assert(ingredient != null || stockItem != null);

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deltaController = TextEditingController();
  final _noteController = TextEditingController();

  String _movementType = 'restock'; // 'restock' | 'correction' | 'waste'
  bool _isLoading = false;
  String? _errorMessage;

  String get _id => widget.ingredient?.id ?? widget.stockItem!.productId;
  String get _name => widget.ingredient?.name ?? widget.stockItem!.productName;
  String get _unit => widget.ingredient?.unit ?? widget.stockItem!.unit;
  String get _outletId => widget.ingredient?.outletId ?? widget.stockItem!.outletId;
  String get _outletName => widget.ingredient?.outletName ?? widget.stockItem!.outletName;
  int get _currentStock => widget.ingredient?.stockQty ?? widget.stockItem!.quantity;

  @override
  void dispose() {
    _deltaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final rawDelta = int.tryParse(_deltaController.text.trim()) ?? 0;
    if (rawDelta == 0) {
      setState(() => _errorMessage = 'Perubahan stok tidak boleh 0.');
      return;
    }

    // Koreksi atau waste jika diketik positif tapi tipe waste, jadikan minus
    int delta = rawDelta;
    if (_movementType == 'waste' && delta > 0) {
      delta = -delta;
    }

    final newStock = _currentStock + delta;
    if (newStock < 0) {
      setState(() => _errorMessage = 'Stok akhir tidak boleh negatif ($newStock $_unit).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.createAdjustment(
        outletId: _outletId,
        ingredientId: _id,
        movementType: _movementType,
        quantityDelta: delta,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Penyesuaian stok bahan baku berhasil disimpan.', style: GoogleFonts.lexend()),
            backgroundColor: AppTheme.jadeTosca,
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
    final currentDelta = int.tryParse(_deltaController.text) ?? 0;
    final effDelta = (_movementType == 'waste' && currentDelta > 0) ? -currentDelta : currentDelta;
    final projectedQty = _currentStock + effDelta;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Penyesuaian Stok Bahan Baku',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 3),
          Text(
            '$_name • $_outletName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Stok Saat Ini:',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.textPrimaryDark),
                      ),
                    ),
                    Text(
                      '$_currentStock $_unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.jadeTosca),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x22EF4444),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x33EF4444)),
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
                          style: GoogleFonts.lexend(fontSize: 12, color: const Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Text('Jenis Mutasi:', style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _movementType,
                dropdownColor: AppTheme.darkCardSurface,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'restock', child: Text('Restock Masuk (+)', style: GoogleFonts.lexend(fontSize: 13))),
                  DropdownMenuItem(value: 'correction', child: Text('Koreksi Opname (+/-)', style: GoogleFonts.lexend(fontSize: 13))),
                  DropdownMenuItem(value: 'waste', child: Text('Bahan Basi / Rusak (-)', style: GoogleFonts.lexend(fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _movementType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _deltaController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: _movementType == 'restock'
                      ? 'Jumlah Tambah ($_unit) *'
                      : (_movementType == 'waste' ? 'Jumlah Rusak ($_unit) *' : 'Selisih (+/- $_unit) *'),
                  hintText: 'Misal: 500',
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                  if (int.tryParse(val.trim()) == null) return 'Harus angka bulat';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Estimasi stok akhir:',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMutedDark),
                    ),
                  ),
                  Text(
                    '$projectedQty $_unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: projectedQty < 0 ? AppTheme.dangerRed : AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Alasan (Opsional)',
                  hintText: 'Misal: Kiriman supplier PT Kopi Baru, opname mingguan',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Batal', style: GoogleFonts.lexend(color: AppTheme.textMutedDark)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.jadeTosca,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Simpan', style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
