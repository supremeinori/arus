import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';
import '../domain/inventory_models.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final InventoryStockItem stockItem;

  const StockAdjustmentDialog({
    super.key,
    required this.stockItem,
  });

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deltaController = TextEditingController();
  final _noteController = TextEditingController();

  String _movementType = 'correction'; // 'correction' | 'waste' | 'restock'
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _deltaController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final delta = int.tryParse(_deltaController.text.trim()) ?? 0;
    if (delta == 0) {
      setState(() => _errorMessage = 'Perubahan stok tidak boleh 0.');
      return;
    }

    final newStock = widget.stockItem.quantity + delta;
    if (newStock < 0) {
      setState(() => _errorMessage = 'Stok akhir tidak boleh negatif ($newStock).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.createAdjustment(
        outletId: widget.stockItem.outletId,
        productId: widget.stockItem.productId,
        movementType: _movementType,
        quantityDelta: delta,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penyesuaian stok berhasil disimpan.'),
            backgroundColor: Colors.teal,
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
    final item = widget.stockItem;
    final currentDelta = int.tryParse(_deltaController.text) ?? 0;
    final projectedQty = item.quantity + currentDelta;

    return AlertDialog(
      title: Text('Penyesuaian Stok: ${item.productName}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outlet: ${item.outletName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Stok saat ini: ${item.quantity} ${item.unit}'),
              const Divider(height: 24),

              DropdownButtonFormField<String>(
                initialValue: _movementType,
                decoration: const InputDecoration(
                  labelText: 'Alasan Penyesuaian',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'correction', child: Text('Koreksi Opname Fisik')),
                  DropdownMenuItem(value: 'waste', child: Text('Barang Rusak / Kadaluarsa')),
                  DropdownMenuItem(value: 'restock', child: Text('Restock Masuk Manual')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _movementType = val);
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _deltaController,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: 'Jumlah Perubahan (+ / -)',
                  hintText: 'Misal: 5 atau -2',
                  helperText: 'Stok baru menjadi: $projectedQty ${item.unit}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                  final num = int.tryParse(val.trim());
                  if (num == null) return 'Masukkan angka bulat';
                  if (num == 0) return 'Perubahan tidak boleh 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan Penyesuaian (Opsional)',
                  hintText: 'Contoh: Kemasan pecah saat bongkar muat',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
