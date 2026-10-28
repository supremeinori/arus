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
  final bool isDetailMode;
  final VoidCallback? onVoid;
  final bool canVoid;

  const PosReceiptDialog({
    super.key,
    required this.transaction,
    this.isDetailMode = false,
    this.onVoid,
    this.canVoid = false,
  });

  @override
  Widget build(BuildContext context) {
    final isVoided = transaction.status == 'voided';
    final isPending = transaction.isOfflinePending || transaction.status == 'offline_pending';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
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
                  Icon(
                    isVoided
                        ? Icons.cancel_outlined
                        : isDetailMode
                            ? Icons.receipt_long_rounded
                            : Icons.check_circle_rounded,
                    color: isVoided ? AppTheme.dangerRed : AppTheme.jadeTosca,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDetailMode
                          ? (isVoided ? 'Detail Transaksi (VOID)' : 'Detail Transaksi')
                          : 'Transaksi Berhasil!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isVoided ? AppTheme.dangerRed : AppTheme.textPrimaryDark,
                      ),
                    ),
                  ),
                  if (isDetailMode)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMutedDark),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Tutup',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      'ARUS POS',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimaryDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.outletName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No: ${transaction.receiptNo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryDark),
                    ),
                    Text(
                      _receiptDateFmt.format(transaction.createdAt),
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                    ),
                    const SizedBox(height: 6),
                    if (isVoided)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cancel_rounded, size: 14, color: AppTheme.dangerRed),
                                const SizedBox(width: 4),
                                Text(
                                  'VOID (Transaksi Dibatalkan)',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.dangerRed,
                                  ),
                                ),
                              ],
                            ),
                            if (transaction.voidReason != null && transaction.voidReason!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Alasan: ${transaction.voidReason}',
                                style: GoogleFonts.inter(fontSize: 9.5, color: AppTheme.dangerRed),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    else if (isPending)
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
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
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
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade800),
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
              if (transaction.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Tidak ada rincian item.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ...transaction.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.productName} x${item.quantity}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimaryDark),
                              ),
                              if (item.unitPriceIdr > 0)
                                Text(
                                  '@ ${MoneyFormatter.format(item.unitPriceIdr)}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        MoneyText(
                          item.lineTotalIdr,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                        ),
                      ],
                    ),
                  );
                }),

              const Divider(height: 24, color: AppTheme.darkCardBorder, thickness: 1.2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMutedDark)),
                  MoneyText(
                    transaction.subtotalIdr,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                  ),
                ],
              ),
              if (transaction.discountIdr > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Diskon', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626))),
                    MoneyText(
                      transaction.discountIdr,
                      prefix: '- ',
                      maxLines: 1,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
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
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimaryDark),
                  ),
                  MoneyText(
                    transaction.totalIdr,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isVoided ? AppTheme.dangerRed : AppTheme.jadeTosca,
                    ),
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
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMutedDark),
                    ),
                  ),
                  MoneyText(
                    transaction.paidIdr,
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Kembalian',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimaryDark),
                  ),
                  MoneyText(
                    transaction.changeIdr,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimaryDark),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Kasir: ${transaction.cashierName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isDetailMode) ...[
          if (!isVoided && !isPending && canVoid && onVoid != null)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onVoid!();
              },
              icon: const Icon(Icons.undo_rounded, size: 16, color: AppTheme.dangerRed),
              label: Text(
                'Void',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dangerRed),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.dangerRed),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          PrimaryButton(
            label: 'Tutup',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ] else ...[
          PrimaryButton(
            label: 'Selesai / Transaksi Baru',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}
