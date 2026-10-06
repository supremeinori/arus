import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/pos_models.dart';

class PosReceiptDialog extends StatelessWidget {
  final PosTransactionModel transaction;

  const PosReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd MMM yyyy, HH:mm');

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green),
          SizedBox(width: 8),
          Text('Transaksi Berhasil!'),
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
                  const Text('ARUS POS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(transaction.outletName, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('No: ${transaction.receiptNo}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(dateFormatter.format(transaction.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const Divider(height: 24),

            // Item List
            ...transaction.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item.productName} x${item.quantity}'),
                    ),
                    Text(currencyFormatter.format(item.lineTotalIdr)),
                  ],
                ),
              );
            }),

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(currencyFormatter.format(transaction.subtotalIdr)),
              ],
            ),
            if (transaction.discountIdr > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Diskon', style: TextStyle(color: Colors.red)),
                  Text('- ${currencyFormatter.format(transaction.discountIdr)}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  transaction.formattedTotal,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Metode (${transaction.paymentMethod.toUpperCase()})'),
                Text(currencyFormatter.format(transaction.paidIdr)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kembalian', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(currencyFormatter.format(transaction.changeIdr), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Kasir: ${transaction.cashierName}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          child: const Text('Selesai / Transaksi Baru', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
