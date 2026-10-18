import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/pos_models.dart';

/// Format tanggal struk — top-level agar tidak diinstansiasi ulang tiap build
/// (aturan E21).
final _receiptDateFmt = DateFormat('dd MMM yyyy, HH:mm');

class PosReceiptDialog extends StatelessWidget {
  final PosTransactionModel transaction;

  const PosReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      // Batasi lebar dialog HP + tablet (aturan C15).
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.jadeTosca, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Transaksi Berhasil!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimaryDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    'ARUS POS',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.outletName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No: ${transaction.receiptNo}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryDark),
                  ),
                  Text(
                    _receiptDateFmt.format(transaction.createdAt),
                    style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMutedDark),
                  ),
                  const SizedBox(height: 6),
                  if (transaction.isOfflinePending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 14, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                            'OFFLINE (Tersimpan di SQLite Lokal)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done_rounded, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                            'ONLINE (Tersinkronkan ke Supabase)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.2),

            // Item List
            ...transaction.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName} x${item.quantity}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.textPrimaryDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MoneyText(item.lineTotalIdr,
                      style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.textMutedDark)),
                MoneyText(transaction.subtotalIdr,
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                ),
              ],
            ),
            if (transaction.discountIdr > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Diskon', style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFFDC2626))),
                  Text(
                    '- ${MoneyFormatter.format(transaction.discountIdr)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimaryDark),
                ),
                MoneyText(transaction.totalIdr,
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.jadeTosca),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                  'Metode (${transaction.paymentMethod.toUpperCase()})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textMutedDark),
                  ),
                ),
                MoneyText(transaction.paidIdr,
                  style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kembalian',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimaryDark),
                ),
                MoneyText(transaction.changeIdr,
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimaryDark),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Kasir: ${transaction.cashierName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lexend(fontSize: 11, color: AppTheme.textMutedDark),
              ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        PrimaryButton(
          label: 'Selesai / Transaksi Baru',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
