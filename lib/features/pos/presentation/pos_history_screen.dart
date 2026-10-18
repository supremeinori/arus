import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../domain/pos_models.dart';
import 'pos_catalog_provider.dart';

/// Format jam struk riwayat — top-level, bukan di build (aturan E21).
final _historyTimeFmt = DateFormat('HH:mm');

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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 15)),
        // Batasi lebar dialog + field standar (aturan C15).
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AppTextField(
          controller: reasonCtrl,
          labelText: 'Alasan void *',
          hintText: 'Contoh: salah input menu',
          maxLines: 2,
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text('Riwayat Transaksi Hari Ini',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(posHistoryProvider),
          ),
        ],
      ),
      // Satu .when() terpusat via AsyncStateView (aturan E24).
      body: AsyncStateView<List<PosTransactionModel>>(
        value: ref.watch(posHistoryProvider),
        onRetry: () => ref.invalidate(posHistoryProvider),
        dataBuilder: (list) {
          if (list.isEmpty) {
            return const EmptyStateView(
              message: 'Belum ada transaksi hari ini.',
              icon: Icons.receipt_long_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final tx = list[i];
              return _HistoryCard(
                tx: tx,
                canVoid: _canVoid,
                voiding: _voiding,
                onVoid: () => _askVoidReason(tx),
              );
            },
          );
        },
      ),
    );
  }
}

/// Kartu satu struk riwayat — widget const agar build ringan (aturan E23).
class _HistoryCard extends StatelessWidget {
  final PosTransactionModel tx;
  final bool canVoid;
  final bool voiding;
  final VoidCallback onVoid;

  const _HistoryCard({
    required this.tx,
    required this.canVoid,
    required this.voiding,
    required this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final voided = tx.status == 'voided';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: voided ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tx.receiptNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: voided
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  voided ? 'VOID' : '${_historyTimeFmt.format(tx.createdAt)} • ${tx.status}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            '${tx.items.fold(0, (s, e) => s + e.quantity)} item • ${tx.cashierName} • ${MoneyFormatter.format(tx.totalIdr)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (!voided && canVoid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: voiding ? null : onVoid,
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
  }
}
