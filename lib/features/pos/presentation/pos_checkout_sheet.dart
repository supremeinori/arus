import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
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

    final outletId = user?.outlets.isNotEmpty == true ? user!.outlets.first.id : 'out-001';

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
      final userSuffix = (user != null && user.id.length >= 4)
          ? user.id.substring(0, 4)
          : 'demo';
      final clientRequestId = 'req-${DateTime.now().millisecondsSinceEpoch}-$userSuffix';
      final repo = ref.read(posRepositoryProvider);

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
        border: Border(
          top: BorderSide(color: AppTheme.borderOutline, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pembayaran & Checkout',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.accentBlack),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.accentBlack),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppTheme.borderOutline, thickness: 1.0),
            const SizedBox(height: 8),

            // Summary Subtotal & Diskon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cartState.totalItemsCount} item)',
                  style: GoogleFonts.lexend(fontSize: 13.5, color: const Color(0xFF64748B)),
                ),
                Text(
                  currencyFormatter.format(subtotal),
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.accentBlack),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Diskon Field
            Row(
              children: [
                Text(
                  'Diskon:',
                  style: GoogleFonts.lexend(fontSize: 13.5, color: const Color(0xFF64748B)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.lexend(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Rp 0',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      ),
                    ),
                    onChanged: (val) {
                      final disc = int.tryParse(val) ?? 0;
                      ref.read(posCartProvider.notifier).setDiscount(disc);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Total Tagihan
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Tagihan',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.accentBlack),
                ),
                Text(
                  currencyFormatter.format(total),
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.primaryBlue),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),

            // Pilihan Metode Pembayaran
            Text(
              'Metode Pembayaran:',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildMethodChoice('cash', 'Tunai', Icons.payments_outlined, cartState.paymentMethod),
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
                style: GoogleFonts.lexend(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Uang Diterima',
                  hintText: 'Masukkan nominal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                  ),
                  prefixText: 'Rp ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryBlue),
                    tooltip: 'Uang Pas',
                    onPressed: () => _setExactCash(total),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text('Uang Pas', style: GoogleFonts.lexend(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () => _setExactCash(total),
                  ),
                  if (total <= 50000)
                    ActionChip(
                      label: Text('Rp 50.000', style: GoogleFonts.lexend(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _setPresetCash(50000),
                    ),
                  if (total <= 100000)
                    ActionChip(
                      label: Text('Rp 100.000', style: GoogleFonts.lexend(fontSize: 12)),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _setPresetCash(100000),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kembalian:',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.accentBlack),
                  ),
                  Text(
                    currencyFormatter.format(change),
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: currentPaid >= total ? AppTheme.accentBlack : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.lexend(color: const Color(0xFFDC2626), fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Konfirmasi & Bayar',
                        style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.borderOutline,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryBlue : AppTheme.accentBlack, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.lexend(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.accentBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
