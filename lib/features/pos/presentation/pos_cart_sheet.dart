import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'pos_provider.dart';

/// Bottom sheet detail keranjang: daftar baris + tombol +, -, hapus per baris,
/// kalkulasi Subtotal, Diskon, Total live.
///
/// Catatan: format rupiah memakai [MoneyFormatter]/[MoneyText] (aturan E21 —
/// jangan instansiasi NumberFormat di build).
class PosCartSheet extends ConsumerWidget {
  const PosCartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);

    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Keranjang (${cart.totalItemsCount} item)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimaryDark)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimaryDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: AppTheme.darkCardBorder, thickness: 1.0),
          if (cart.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Keranjang kosong.',
                    style: GoogleFonts.inter(color: AppTheme.textMutedDark)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cart.items.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (_, i) {
                  final item = cart.items[i];
                    return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryDark)),
                            Text(MoneyFormatter.format(item.unitPriceIdr),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 11.5, color: AppTheme.textMutedDark)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppTheme.textMutedDark),
                        onPressed: () => notifier.decrementProduct(item.productId),
                        tooltip: 'Kurangi',
                      ),
                      Text('${item.quantity}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimaryDark)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20, color: AppTheme.jadeTosca),
                        onPressed: () => notifier.addProductById(item.productId),
                        tooltip: 'Tambah',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.dangerRed),
                        onPressed: () => notifier.removeProduct(item.productId),
                        tooltip: 'Hapus baris',
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(MoneyFormatter.format(item.lineTotalIdr),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimaryDark)),
                      ),
                    ],
                  );
                },
              ),
            ),
          const Divider(color: AppTheme.darkCardBorder, thickness: 1.0),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark)),
            MoneyText(cart.subtotalIdr,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryDark)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Diskon', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark)),
            Text('- ${MoneyFormatter.format(cart.discountIdr)}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.dangerRed)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Tagihan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimaryDark)),
            MoneyText(cart.totalIdr,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.jadeTosca)),
          ]),
        ],
      ),
    );
  }
}
