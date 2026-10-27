import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'pos_provider.dart';
import '../../settings/presentation/currency_provider.dart';

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
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetTopBar(),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Keranjang',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimaryDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                ),
                child: Text(
                  '${cart.totalItemsCount} item',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cart.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Keranjang kosong.',
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: cart.items.length,
                separatorBuilder: (_, _) => const Divider(height: 14, color: AppTheme.darkCardBorder),
                itemBuilder: (_, i) {
                  final item = cart.items[i];
                  return _CartLine(
                    name: item.productName,
                    unitPriceText: ref.money(item.unitPriceIdr),
                    lineTotalText: ref.money(item.lineTotalIdr),
                    quantity: item.quantity,
                    onIncrement: () => notifier.addProductById(item.productId),
                    onDecrement: () => notifier.decrementProduct(item.productId),
                    onRemove: () => notifier.removeProduct(item.productId),
                  );
                },
              ),
            ),
          const Divider(height: 16, color: AppTheme.darkCardBorder, thickness: 1.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark)),
              MoneyText(
                cart.subtotalIdr,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Diskon', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark)),
              Text(
                '- ${ref.money(cart.discountIdr)}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.dangerRed),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Tagihan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimaryDark),
              ),
              MoneyText(
                cart.totalIdr,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppTheme.jadeTosca,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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

/// Satu baris produk di keranjang: nama, harga satuan, jumlah, dan total baris.
class _CartLine extends StatelessWidget {
  final String name;
  final String unitPriceText;
  final String lineTotalText;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartLine({
    required this.name,
    required this.unitPriceText,
    required this.lineTotalText,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$unitPriceText · $lineTotalText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _QtyStepper(
          quantity: quantity,
          onIncrement: onIncrement,
          onDecrement: onDecrement,
        ),
        IconButton(
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: 'Hapus baris',
          icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed),
          onPressed: onRemove,
        ),
      ],
    );
  }
}

/// Pengatur jumlah dengan tap target 48dp, tombol plus diberi warna aksi.
class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: Icons.remove_rounded,
          tooltip: 'Kurangi',
          onTap: onDecrement,
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppTheme.textPrimaryDark,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          tooltip: 'Tambah',
          isPrimary: true,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

/// Tombol bulat 32dp di dalam area sentuh 48dp.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isPrimary;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isPrimary ? AppTheme.jadeTosca : AppTheme.darkCardSurfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isPrimary ? AppTheme.jadeTosca : AppTheme.darkCardBorder,
                width: 1.0,
              ),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : AppTheme.textPrimaryDark,
            ),
          ),
        ),
      ),
    );
  }
}
