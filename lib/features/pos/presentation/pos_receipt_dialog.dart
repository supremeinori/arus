import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/pos_models.dart';

class PosReceiptDialog extends StatelessWidget {
  final PosTransactionModel transaction;

  const PosReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
      ),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 22),
          const SizedBox(width: 8),
          Text(
            'Transaksi Berhasil!',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.accentBlack),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'ARUS POS',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.accentBlack),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.outletName,
                    style: GoogleFonts.lexend(color: const Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No: ${transaction.receiptNo}',
                    style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.accentBlack),
                  ),
                  Text(
                    dateFormatter.format(transaction.createdAt),
                    style: GoogleFonts.lexend(fontSize: 11, color: const Color(0xFF64748B)),
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
                          Text(
                            'OFFLINE (Tersimpan di SQLite Lokal)',
                            style: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
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
                          Text(
                            'ONLINE (Tersinkronkan ke Supabase)',
                            style: GoogleFonts.lexend(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green.shade800),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),

            // Item List
            ...transaction.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName} x${item.quantity}',
                        style: GoogleFonts.lexend(fontSize: 13, color: AppTheme.accentBlack),
                      ),
                    ),
                    Text(
                      currencyFormatter.format(item.lineTotalIdr),
                      style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Subtotal', style: GoogleFonts.lexend(fontSize: 13, color: const Color(0xFF64748B))),
                Text(
                  currencyFormatter.format(transaction.subtotalIdr),
                  style: GoogleFonts.lexend(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
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
                    '- ${currencyFormatter.format(transaction.discountIdr)}',
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
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.accentBlack),
                ),
                Text(
                  transaction.formattedTotal,
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryBlue),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderOutline, thickness: 1.2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metode (${transaction.paymentMethod.toUpperCase()})',
                  style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
                Text(
                  currencyFormatter.format(transaction.paidIdr),
                  style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.accentBlack),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kembalian',
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
                ),
                Text(
                  currencyFormatter.format(transaction.changeIdr),
                  style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.accentBlack),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Kasir: ${transaction.cashierName}',
                style: GoogleFonts.lexend(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Selesai / Transaksi Baru',
            style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
