import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pos_repository.dart';
import 'pos_provider.dart';
import 'pos_receipt_dialog.dart';

class PosCheckoutSheet extends ConsumerStatefulWidget {
  const PosCheckoutSheet({super.key});

  @override
  ConsumerState<PosCheckoutSheet> createState() => _PosCheckoutSheetState();
}

class _PosCheckoutSheetState extends ConsumerState<PosCheckoutSheet> {
  final _paidController = TextEditingController();
  final _discountController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _paidController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _setExactCash(int total) {
    _paidController.text = total.toString();
    setState(() {});
  }

  void _setPresetCash(int amount) {
    _paidController.text = amount.toString();
    setState(() {});
  }

  Future<void> _processCheckout() async {
    final cartState = ref.read(posCartProvider);
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (cartState.items.isEmpty) return;

    final outletId = user?.outlets.isNotEmpty == true ? user!.outlets.first.id : '';
    if (outletId.isEmpty) {
      setState(() => _errorMessage = 'Outlet aktif tidak ditemukan untuk kasir.');
      return;
    }

    final total = cartState.totalIdr;
    final isCash = cartState.paymentMethod == 'cash';
    final paidAmount = isCash ? (int.tryParse(_paidController.text.trim()) ?? 0) : total;

    if (isCash && paidAmount < total) {
      setState(() => _errorMessage = 'Uang pembayaran kurang dari total tagihan.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(posRepositoryProvider);
      // Generate client request id UUID secara random untuk idempotency
      final clientRequestId = 'req-${DateTime.now().millisecondsSinceEpoch}-${user?.id.substring(0, 5)}';

      final transaction = await repo.createTransaction(
        clientRequestId: clientRequestId,
        outletId: outletId,
        paymentMethod: cartState.paymentMethod,
        paidIdr: paidAmount,
        discountIdr: cartState.discountIdr,
        items: cartState.items,
      );

      // Reset Keranjang
      ref.read(posCartProvider.notifier).clearCart();

      if (mounted) {
        Navigator.of(context).pop(); // Tutup bottom sheet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PosReceiptDialog(transaction: transaction),
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
    final cartState = ref.watch(posCartProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final subtotal = cartState.subtotalIdr;
    final total = cartState.totalIdr;
    final isCash = cartState.paymentMethod == 'cash';
    final currentPaid = int.tryParse(_paidController.text) ?? 0;
    final change = isCash ? (currentPaid - total).clamp(0, double.infinity).toInt() : 0;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Pembayaran & Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),

            // Summary Subtotal & Diskon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal (${cartState.totalItemsCount} item)'),
                Text(currencyFormatter.format(subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),

            // Diskon Field
            Row(
              children: [
                const Text('Diskon:'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Rp 0',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final disc = int.tryParse(val) ?? 0;
                      ref.read(posCartProvider.notifier).setDiscount(disc);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Total Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  currencyFormatter.format(total),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal),
                ),
              ],
            ),
            const Divider(height: 24),

            // Pilihan Metode Pembayaran
            const Text('Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMethodChoice('cash', 'Tunai / Cash', Icons.payments_outlined, cartState.paymentMethod),
                const SizedBox(width: 8),
                _buildMethodChoice('qris_simulated', 'QRIS', Icons.qr_code_2_rounded, cartState.paymentMethod),
                const SizedBox(width: 8),
                _buildMethodChoice('card_simulated', 'Kartu EDC', Icons.credit_card_rounded, cartState.paymentMethod),
              ],
            ),
            const SizedBox(height: 16),

            // Jika Tunai: Input Uang & Preset Cepat
            if (isCash) ...[
              TextField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Uang Diterima',
                  hintText: 'Masukkan nominal',
                  border: const OutlineInputBorder(),
                  prefixText: 'Rp ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Uang Pas',
                    onPressed: () => _setExactCash(total),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),

              // Preset uang pas, 50k, 100k
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Uang Pas'),
                    onPressed: () => _setExactCash(total),
                  ),
                  if (total <= 50000)
                    ActionChip(
                      label: const Text('Rp 50.000'),
                      onPressed: () => _setPresetCash(50000),
                    ),
                  if (total <= 100000)
                    ActionChip(
                      label: const Text('Rp 100.000'),
                      onPressed: () => _setPresetCash(100000),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    currencyFormatter.format(change),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: currentPaid >= total ? Colors.green.shade700 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Konfirmasi & Bayar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChoice(String method, String label, IconData icon, String current) {
    final isSelected = current == method;
    return Expanded(
      child: InkWell(
        onTap: () {
          ref.read(posCartProvider.notifier).setPaymentMethod(method);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.teal.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.teal : Colors.grey.shade300, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.teal : Colors.grey.shade700),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.teal : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
