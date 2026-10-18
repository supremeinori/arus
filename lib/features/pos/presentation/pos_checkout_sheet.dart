import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../data/pos_repository.dart';
import 'pos_catalog_provider.dart';
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

    if (cartState.items.isEmpty) return;

    final outletId = ref.read(posOutletIdProvider);
    if (outletId == null || outletId.isEmpty) {
      setState(() => _errorMessage = 'Outlet kasir tidak terdeteksi. Login ulang.');
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
      final clientRequestId = UuidGenerator.v4();
      final posRepo = ref.read(posCatalogRepositoryProvider);

      final transaction = await posRepo.checkout(
        outletId: outletId,
        clientRequestId: clientRequestId,
        paymentMethod: cartState.paymentMethod,
        paidIdr: paidAmount,
        discountIdr: cartState.discountIdr,
        items: cartState.items
            .map((item) => {'product_id': item.productId, 'quantity': item.quantity})
            .toList(),
      );

      // Reset keranjang + refresh stok katalog & riwayat
      ref.read(posCartProvider.notifier).clearCart();
      ref.invalidate(posCatalogProvider);
      ref.invalidate(posHistoryProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Tutup bottom sheet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PosReceiptDialog(transaction: transaction),
        );
      }
    } catch (e) {
      // Fallback offline: simpan ke antrean SQLite lokal (jalur lama)
      try {
        final user = ref.read(authProvider).user;
        final offlineRepo = ref.read(posRepositoryProvider);
        final transaction = await offlineRepo.createTransaction(
          clientRequestId: UuidGenerator.v4(),
          outletId: outletId,
          paymentMethod: cartState.paymentMethod,
          paidIdr: paidAmount,
          discountIdr: cartState.discountIdr,
          items: cartState.items,
          cashierName: user?.name,
          outletName: user?.outlets.isNotEmpty == true ? user!.outlets.first.name : null,
        );
        ref.read(posCartProvider.notifier).clearCart();
        if (mounted) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PosReceiptDialog(transaction: transaction),
          );
        }
      } catch (offlineErr) {
        setState(() {
          _isLoading = false;
          _errorMessage = offlineErr.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(posCartProvider);

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
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17, color: AppTheme.textPrimaryDark),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimaryDark),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: AppTheme.darkCardBorder, thickness: 1.0),
            const SizedBox(height: 8),

            // Summary Subtotal & Diskon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cartState.totalItemsCount} item)',
                  style: GoogleFonts.lexend(fontSize: 13.5, color: AppTheme.textMutedDark),
                ),
                Text(
                  MoneyFormatter.format(subtotal),
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Diskon Field
            Row(
              children: [
                Text(
                  'Diskon:',
                  style: GoogleFonts.lexend(fontSize: 13.5, color: AppTheme.textMutedDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    hintText: 'Rp 0',
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
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimaryDark),
                ),
                Text(
                  MoneyFormatter.format(total),
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.jadeTosca),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.2),

            // Pilihan Metode Pembayaran
            Text(
              'Metode Pembayaran:',
              style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimaryDark),
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

            // Simulasi QRIS / Kartu: tampilkan kode bayar + konfirmasi
            if (!isCash) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkCardBorder),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 120, color: AppTheme.textPrimaryDark),
                    const SizedBox(height: 8),
                    Text(
                      cartState.paymentMethod == 'qris_simulated'
                          ? 'Scan QR untuk membayar ${MoneyFormatter.format(total)}'
                          : 'Gesek kartu EDC sebesar ${MoneyFormatter.format(total)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simulasi — tekan "Konfirmasi Pembayaran Diterima" setelah pelanggan membayar.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Jika Tunai: Input Uang & Preset Cepat
            if (isCash) ...[
              AppTextField(
                controller: _paidController,
                keyboardType: TextInputType.number,
                labelText: 'Uang Diterima',
                hintText: 'Masukkan nominal',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: AppTheme.jadeTosca),
                  tooltip: 'Uang Pas',
                  onPressed: () => _setExactCash(total),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text('Uang Pas', style: GoogleFonts.lexend(fontSize: 12)),
                    backgroundColor: AppTheme.darkCardSurface,
                    side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () => _setExactCash(total),
                  ),
                  if (total <= 50000)
                    ActionChip(
                      label: Text('Rp 50.000', style: GoogleFonts.lexend(fontSize: 12)),
                      backgroundColor: AppTheme.darkCardSurface,
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onPressed: () => _setPresetCash(50000),
                    ),
                  if (total <= 100000)
                    ActionChip(
                      label: Text('Rp 100.000', style: GoogleFonts.lexend(fontSize: 12)),
                      backgroundColor: AppTheme.darkCardSurface,
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
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
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimaryDark),
                  ),
                  Text(
                    MoneyFormatter.format(change),
                    style: GoogleFonts.lexend(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: currentPaid >= total ? AppTheme.textPrimaryDark : const Color(0xFF94A3B8),
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
              child: PrimaryButton(
                label: isCash
                    ? 'Selesaikan Transaksi'
                    : 'Konfirmasi Pembayaran Diterima',
                isLoading: _isLoading,
                onPressed: (_isLoading || (isCash && currentPaid < total))
                    ? null
                    : _processCheckout,
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
            color: isSelected ? const Color(0xFFEFF6FF) : AppTheme.darkCardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.jadeTosca : AppTheme.textPrimaryDark, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.lexend(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.jadeTosca : AppTheme.textPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
