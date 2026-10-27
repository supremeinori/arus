import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../catalog/presentation/catalog_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../data/pos_repository.dart';
import 'pos_catalog_provider.dart';
import 'pos_provider.dart';
import 'pos_receipt_dialog.dart';
import '../../settings/presentation/currency_provider.dart';

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

  void _appendDigit(String digit) {
    final current = _paidController.text.trim();
    final next = current.isEmpty || current == '0' ? digit : '$current$digit';
    if (next.length > 12) return;
    _paidController.text = next;
    setState(() {});
  }

  void _backspace() {
    final current = _paidController.text.trim();
    if (current.isEmpty) return;
    _paidController.text = current.substring(0, current.length - 1);
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

    // Idempotency: gunakan clientRequestId yang stabil dan sama persis baik online maupun fallback offline
    final clientRequestId = UuidGenerator.v4();

    try {
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

      // Reset keranjang + refresh stok katalog & riwayat & shift
      ref.read(posCartProvider.notifier).clearCart();
      ref.invalidate(posCatalogProvider);
      ref.invalidate(posHistoryProvider);
      ref.invalidate(productListProvider);
      ref.invalidate(shiftSummaryProvider);
      ref.invalidate(salesForecastProvider);
      ref.invalidate(stockoutForecastProvider);
      ref.invalidate(analyticsOverviewProvider);
      ref.invalidate(salesTrendProvider);

      if (mounted) {
        Navigator.of(context).pop(); // Tutup bottom sheet
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PosReceiptDialog(transaction: transaction),
        );
      }
    } catch (e) {
      if (e is AppException && e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
        return;
      }

      // Fallback offline: simpan ke antrean SQLite lokal (reuse clientRequestId stabil)
      try {
        final user = ref.read(authProvider).user;
        final offlineRepo = ref.read(posRepositoryProvider);
        final transaction = await offlineRepo.createTransaction(
          clientRequestId: clientRequestId,
          outletId: outletId,
          paymentMethod: cartState.paymentMethod,
          paidIdr: paidAmount,
          discountIdr: cartState.discountIdr,
          items: cartState.items,
          cashierName: user?.name,
          outletName: user?.outlets.isNotEmpty == true ? user!.outlets.first.name : null,
        );
        ref.read(posCartProvider.notifier).clearCart();
        ref.invalidate(posCatalogProvider);
        ref.invalidate(posHistoryProvider);
        ref.invalidate(productListProvider);
        ref.invalidate(shiftSummaryProvider);
        ref.invalidate(salesForecastProvider);
        ref.invalidate(stockoutForecastProvider);
        ref.invalidate(analyticsOverviewProvider);
        ref.invalidate(salesTrendProvider);
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
    final paidEnough = currentPaid >= total;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetTopBar(),
            const SizedBox(height: 8),

            // Total tagihan duduk paling atas supaya kasir langsung melihat angkanya.
            Text(
              'Total Tagihan',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMutedDark),
            ),
            const SizedBox(height: 2),
            Text(
              ref.money(total),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 26,
                letterSpacing: -0.7,
                color: AppTheme.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _MethodPill(
                  label: 'Tunai',
                  icon: Icons.payments_outlined,
                  isSelected: cartState.paymentMethod == 'cash',
                  onTap: () => _selectMethod('cash'),
                ),
                const SizedBox(width: 8),
                _MethodPill(
                  label: 'QRIS',
                  icon: Icons.qr_code_2_rounded,
                  isSelected: cartState.paymentMethod == 'qris_simulated',
                  onTap: () => _selectMethod('qris_simulated'),
                ),
                const SizedBox(width: 8),
                _MethodPill(
                  label: 'Kartu EDC',
                  icon: Icons.credit_card_rounded,
                  isSelected: cartState.paymentMethod == 'card_simulated',
                  onTap: () => _selectMethod('card_simulated'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Divider(height: 1, color: AppTheme.darkCardBorder, thickness: 1.0),
            const SizedBox(height: 12),

            // Rincian tetap tersedia: subtotal dan diskon manual.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal (${cartState.totalItemsCount} item)',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  ref.money(subtotal),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Diskon',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    hintText: ref.money(0),
                    onChanged: (val) {
                      final disc = int.tryParse(val) ?? 0;
                      ref.read(posCartProvider.notifier).setDiscount(disc);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (isCash) ...[
              Row(
                children: [
                  _MiniStat(
                    label: 'Dibayar',
                    value: currentPaid == 0 ? '—' : ref.money(currentPaid),
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    label: 'Kembalian',
                    value: ref.money(change),
                    valueColor: paidEnough ? AppTheme.jadeTosca : AppTheme.textMutedDark,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CashKeypad(onDigit: _appendDigit, onBackspace: _backspace),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickAmountChip(label: 'Uang Pas', onTap: () => _setExactCash(total)),
                  if (total <= 50000)
                    _QuickAmountChip(label: ref.money(50000), onTap: () => _setPresetCash(50000)),
                  if (total <= 100000)
                    _QuickAmountChip(label: ref.money(100000), onTap: () => _setPresetCash(100000)),
                ],
              ),
            ] else
              // Simulasi QRIS / Kartu: tampilkan kode bayar + konfirmasi
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 96, color: AppTheme.textPrimaryDark),
                    const SizedBox(height: 8),
                    Text(
                      cartState.paymentMethod == 'qris_simulated'
                          ? 'Scan QR untuk membayar ${ref.money(total)}'
                          : 'Gesek kartu EDC sebesar ${ref.money(total)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simulasi — tekan "Konfirmasi Pembayaran Diterima" setelah pelanggan membayar.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                    ),
                  ],
                ),
              ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dangerRed.withAlpha(90), width: 1.0),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: AppTheme.dangerRed, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 16),
            PrimaryButton(
              label: isCash ? 'Bayar & Cetak Struk' : 'Konfirmasi Pembayaran Diterima',
              isLoading: _isLoading,
              onPressed: (_isLoading || (isCash && currentPaid < total)) ? null : _processCheckout,
            ),
          ],
        ),
      ),
    );
  }

  void _selectMethod(String method) {
    ref.read(posCartProvider.notifier).setPaymentMethod(method);
    setState(() {});
  }
}

/// Pegangan sheet dan tombol tutup di baris paling atas.
class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.darkCardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: IconButton(
            iconSize: 18,
            tooltip: 'Tutup',
            icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimaryDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

/// Kartu kecil untuk nilai dibayar dan kembalian.
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.darkCardSurfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppTheme.textPrimaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol metode pembayaran berbentuk pil.
class _MethodPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.jadeTosca.withAlpha(28) : AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: isSelected ? AppTheme.jadeTosca : AppTheme.textPrimaryDark),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppTheme.jadeTosca : AppTheme.textPrimaryDark,
                  ),
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

/// Papan angka cepat supaya kasir tidak perlu memunculkan keyboard.
class _CashKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _CashKeypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '000'];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final digit in digits)
          _KeypadKey(label: digit, onTap: () => onDigit(digit)),
        _KeypadKey(icon: Icons.backspace_outlined, onTap: onBackspace, isAccent: true),
      ],
    );
  }
}

/// Satu tombol papan angka.
class _KeypadKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isAccent;
  final VoidCallback onTap;

  const _KeypadKey({this.label, this.icon, required this.onTap, this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isAccent ? AppTheme.jadeTosca : AppTheme.darkCardSurfaceElevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAccent ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
              width: 1.0,
            ),
          ),
          child: icon != null
              ? Icon(icon, size: 18, color: Colors.white)
              : Text(
                  label!,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}

/// Chip nominal cepat di bawah papan angka.
class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimaryDark)),
      backgroundColor: AppTheme.darkCardSurfaceElevated,
      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }
}
