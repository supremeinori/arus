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
            content: Text('Penyesuaian stok bahan baku berhasil disimpan.', style: GoogleFonts.inter()),
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
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 3),
          Text(
            '$_name • $_outletName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
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
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryDark),
                      ),
                    ),
                    Text(
                      '$_currentStock $_unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.jadeTosca),
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
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              const _FieldLabel('Tipe Perubahan'),
              const SizedBox(height: 6),
              _MovementTypeSelector(
                selected: _movementType,
                onChanged: (value) => setState(() => _movementType = value),
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
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
                    ),
                  ),
                  Text(
                    '$projectedQty $_unit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: projectedQty < 0 ? AppTheme.dangerRed : AppTheme.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const _FieldLabel('Catatan / Alasan'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Opsional, misal: Kiriman supplier PT Kopi Baru, opname mingguan',
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
          child: Text('Batal', style: GoogleFonts.inter(color: AppTheme.textMutedDark)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.jadeTosca,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Simpan', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Label kecil di atas kontrol dialog, memakai satu gaya agar seragam.
class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Satu pilihan tipe mutasi stok.
class _MovementOption {
  final String value;
  final String label;
  final String hint;
  final IconData icon;
  final Color tone;

  const _MovementOption({
    required this.value,
    required this.label,
    required this.hint,
    required this.icon,
    required this.tone,
  });
}

const List<_MovementOption> _movementOptions = [
  _MovementOption(
    value: 'restock',
    label: 'Masuk',
    hint: 'Restock / beli',
    icon: Icons.arrow_upward_rounded,
    tone: AppTheme.jadeTosca,
  ),
  _MovementOption(
    value: 'correction',
    label: 'Koreksi',
    hint: 'Opname +/-',
    icon: Icons.tune_rounded,
    tone: AppTheme.warningAmber,
  ),
  _MovementOption(
    value: 'waste',
    label: 'Keluar',
    hint: 'Basi / rusak',
    icon: Icons.arrow_downward_rounded,
    tone: AppTheme.dangerRed,
  ),
];

/// Tiga blok tipe mutasi yang bisa dibedakan sekali lihat, menggantikan dropdown abu.
class _MovementTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _MovementTypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in _movementOptions)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: option == _movementOptions.last ? 0 : 8),
              child: _MovementBlock(
                option: option,
                isSelected: option.value == selected,
                onTap: () => onChanged(option.value),
              ),
            ),
          ),
      ],
    );
  }
}

/// Blok pilihan tunggal tipe mutasi.
class _MovementBlock extends StatelessWidget {
  final _MovementOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _MovementBlock({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${option.label}, ${option.hint}',
      child: Material(
        color: isSelected ? option.tone.withAlpha(28) : AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? option.tone : AppTheme.darkCardBorder,
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(option.icon, size: 18, color: isSelected ? option.tone : AppTheme.textMutedDark),
                const SizedBox(height: 5),
                Text(
                  option.label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? option.tone : AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  option.hint,
                  style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
