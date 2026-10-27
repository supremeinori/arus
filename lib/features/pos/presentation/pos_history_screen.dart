import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/dashboard_filter_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../settings/presentation/currency_provider.dart';
import '../data/pos_catalog_repository.dart';
import '../domain/pos_models.dart';
import 'pos_catalog_provider.dart';

/// Format jam struk riwayat — top-level, bukan di build (aturan E21).
final _historyTimeFmt = DateFormat('HH:mm');

/// Halaman "Riwayat Transaksi": daftar struk outlet + tombol Void
/// (input alasan) → POST /api/pos/void.
/// Filter mengikuti dashboard: Owner boleh pilih cabang & periode,
/// Manager hanya periode dan hanya cabangnya sendiri (dijaga backend).
/// Tombol void hanya tampil untuk owner/manager (sesuai guard backend).
class PosHistoryScreen extends ConsumerStatefulWidget {
  /// true  -> dipakai dari Dashboard: ikut filter cabang & periode dashboard.
  /// false -> dipakai dari tab POS: riwayat outlet kasir yang aktif.
  final bool useDashboardFilters;

  const PosHistoryScreen({
    super.key,
    this.useDashboardFilters = false,
  });

  @override
  ConsumerState<PosHistoryScreen> createState() => _PosHistoryScreenState();
}

class _PosHistoryScreenState extends ConsumerState<PosHistoryScreen> {
  bool _voiding = false;

  bool get _canVoid {
    final role = ref.watch(authProvider).user?.role;
    return role == UserRole.owner || role == UserRole.manager;
  }

  /// Provider riwayat sesuai konteks pemakaian layar:
  /// dashboard -> ikut filter cabang & periode; POS -> outlet kasir aktif.
  AutoDisposeFutureProvider<List<PosTransactionModel>> get _historyProvider =>
      widget.useDashboardFilters
          ? dashboardHistoryProvider
          : posHistoryProvider;

  Future<void> _askVoidReason(PosTransactionModel tx) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void ${tx.receiptNo}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
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
      ref.invalidate(_historyProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text('Transaksi ${tx.receiptNo} dibatalkan, stok dikembalikan.',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.dangerRed,
          content: Text(e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
        ));
      }
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    // Revisi 22 Okt 2026: owner punya pemilih cabang langsung di halaman ini.
    final isOwner = user?.role == UserRole.owner;
    // Kasir juga terkunci ke cabangnya sendiri (tab Beranda kini dipakai kasir).
    final isOutletLocked = user?.role != UserRole.owner;
    final selectedOutletId = isOutletLocked && (user?.outlets.isNotEmpty ?? false)
        ? user!.outlets.first.id
        : ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final selectedCustomDate = ref.watch(selectedCustomDateProvider);
    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    String branchLabel = 'Semua Cabang';
    if (isOutletLocked) {
      if (outlets.isNotEmpty) {
        branchLabel = outlets.first.name;
      } else {
        branchLabel = 'Cabang Saya';
      }
    } else if (selectedOutletId != null) {
      final found = outlets.where((o) => o.id == selectedOutletId);
      if (found.isNotEmpty) branchLabel = found.first.name;
    }

    final String dayLabel = selectedCustomDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(selectedCustomDate)
        : selectedDateFilter.label;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text('Riwayat Transaksi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(_historyProvider),
          ),
        ],
      ),
      // Satu .when() terpusat via AsyncStateView (aturan E24).
      body: Column(
        children: [
          // Baris filter aktif (cabang + periode) — hanya pada mode dashboard.
          if (widget.useDashboardFilters && isOwner)
            Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.darkCardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      size: 18, color: AppTheme.jadeTosca),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Di "$branchLabel" pada "$dayLabel".',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryDark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => showDashboardFilterSheet(
                      context,
                      outlets: outlets,
                      selectedOutletId: selectedOutletId,
                      selectedDateFilter: selectedDateFilter,
                      selectedCustomDate: selectedCustomDate,
                      isManager: isOutletLocked,
                      ownerTitle: 'Filter Riwayat Transaksi',
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.jadeTosca),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Ubah',
                        style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.jadeTosca)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncStateView<List<PosTransactionModel>>(
              value: ref.watch(_historyProvider),
              onRetry: () => ref.invalidate(_historyProvider),
              dataBuilder: (list) {
                if (list.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(_historyProvider);
                      await ref.read(_historyProvider.future);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyStateView(
                          message: 'Belum ada transaksi pada periode ini.',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ],
                    ),
                  );
                }
                // Kartu ringkasan total di atas daftar (lihat mockup Riwayat Transaksi).
                final totalAll = list
                    .where((tx) => tx.status != 'voided')
                    .fold<int>(0, (sum, tx) => sum + tx.totalIdr);
                final tunai = list
                    .where((tx) => tx.status != 'voided' && tx.paymentMethod == 'cash')
                    .fold<int>(0, (sum, tx) => sum + tx.totalIdr);
                final qris = totalAll - tunai;

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(_historyProvider);
                    await ref.read(_historyProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length + 1,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return _HistorySummaryCard(
                          totalText: ref.money(totalAll),
                          tunaiText: ref.money(tunai),
                          qrisText: ref.money(qris),
                          count: list.where((tx) => tx.status != 'voided').length,
                        );
                      }
                      final tx = list[i - 1];
                      return _HistoryCard(
                        tx: tx,
                        canVoid: _canVoid,
                        voiding: _voiding,
                        onVoid: () => _askVoidReason(tx),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan total pada periode & cabang yang sedang difilter.
class _HistorySummaryCard extends StatelessWidget {
  final String totalText;
  final String tunaiText;
  final String qrisText;
  final int count;

  const _HistorySummaryCard({
    required this.totalText,
    required this.tunaiText,
    required this.qrisText,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total $count Transaksi',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            totalText,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryDark,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PaymentChip(label: 'Tunai', amountText: tunaiText),
              _PaymentChip(label: 'QRIS', amountText: qrisText),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final String amountText;

  const _PaymentChip({required this.label, required this.amountText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.jadeTosca.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $amountText',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.jadeTosca,
        ),
      ),
    );
  }
}

/// Kartu satu struk riwayat — widget const agar build ringan (aturan E23).
class _HistoryCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final voided = tx.status == 'voided';
    final isPending = tx.isOfflinePending || tx.status == 'offline_pending';
    final isFailed = tx.status == 'failed';

    Color badgeBg;
    Color badgeTextColor;
    String badgeText;

    if (voided) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeTextColor = AppTheme.dangerRed;
      badgeText = 'VOID';
    } else if (isFailed) {
      badgeBg = const Color(0xFFFEE2E2);
      badgeTextColor = AppTheme.dangerRed;
      badgeText = '${_historyTimeFmt.format(tx.createdAt)} • Gagal Sinkron';
    } else if (isPending) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
      badgeText = '${_historyTimeFmt.format(tx.createdAt)} • Menunggu Sinkron';
    } else {
      badgeBg = const Color(0xFFDCFCE7);
      badgeTextColor = Colors.green.shade800;
      badgeText = '${_historyTimeFmt.format(tx.createdAt)} • ${tx.status}';
    }

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
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${tx.items.fold(0, (s, e) => s + e.quantity)} item • ${tx.cashierName} • ${ref.money(tx.totalIdr)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (!voided && !isPending && !isFailed && canVoid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: voiding ? null : onVoid,
                icon: const Icon(Icons.undo_rounded,
                    size: 16, color: AppTheme.dangerRed),
                label: Text('Void',
                    style: GoogleFonts.inter(
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
