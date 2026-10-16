import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../domain/pos_models.dart';
import 'pos_catalog_provider.dart';

/// Tab/halaman "Riwayat Transaksi Hari Ini": daftar struk outlet aktif +
/// tombol Void (input alasan) → POST /api/pos/void.
/// Tombol void hanya tampil untuk owner/manager (sesuai guard backend).
class PosHistoryScreen extends ConsumerStatefulWidget {
  const PosHistoryScreen({super.key});

  @override
  ConsumerState<PosHistoryScreen> createState() => _PosHistoryScreenState();
}

class _PosHistoryScreenState extends ConsumerState<PosHistoryScreen> {
  bool _voiding = false;

  bool get _canVoid {
    final role = ref.watch(authProvider).user?.role;
    return role == UserRole.owner || role == UserRole.manager;
  }

  Future<void> _askVoidReason(PosTransactionModel tx) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void ${tx.receiptNo}',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15)),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alasan void *',
            hintText: 'Contoh: salah input menu',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed, foregroundColor: Colors.white),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || reason.isEmpty) return;

    setState(() => _voiding = true);
    try {
      await ref.read(posCatalogRepositoryProvider).voidTransaction(
            transactionId: tx.id,
            outletId: tx.outletId,
            reason: reason,
          );
      ref.invalidate(posHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Transaksi ${tx.receiptNo} dibatalkan, stok dikembalikan.',
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.lexend(color: Colors.white, fontSize: 13)),
        ));
      }
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(posHistoryProvider);
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final timeFmt = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text('Riwayat Transaksi Hari Ini',
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(posHistoryProvider),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat riwayat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('Belum ada transaksi hari ini.',
                  style: GoogleFonts.lexend(color: AppTheme.textMuted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final tx = list[i];
              final voided = tx.status == 'voided';
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: voided ? const Color(0xFFF8FAFC) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderOutline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(tx.receiptNo,
                            style: GoogleFonts.lexend(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: voided
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            voided ? 'VOID' : '${timeFmt.format(tx.createdAt)} • ${tx.status}',
                            style: GoogleFonts.lexend(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: voided
                                    ? AppTheme.dangerRed
                                    : Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tx.items.fold(0, (s, e) => s + e.quantity)} item • ${tx.cashierName} • ${fmt.format(tx.totalIdr)}',
                      style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (!voided && _canVoid) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: _voiding ? null : () => _askVoidReason(tx),
                          icon: const Icon(Icons.undo_rounded,
                              size: 16, color: AppTheme.dangerRed),
                          label: Text('Void',
                              style: GoogleFonts.lexend(
                                  fontSize: 12, color: AppTheme.dangerRed)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.dangerRed),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
