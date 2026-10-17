import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../outlets/domain/outlet_models.dart';
import '../../outlets/presentation/outlets_provider.dart';
import '../data/integrity_repository.dart';
import '../domain/integrity_models.dart';
import 'integrity_provider.dart';

class IntegrityChainScreen extends ConsumerStatefulWidget {
  const IntegrityChainScreen({super.key});

  @override
  ConsumerState<IntegrityChainScreen> createState() =>
      _IntegrityChainScreenState();
}

class _IntegrityChainScreenState extends ConsumerState<IntegrityChainScreen> {
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    if (role != UserRole.owner && role != UserRole.manager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ledger Integritas', maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Fitur ini hanya tersedia untuk Owner dan Manager.',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    final outletsAsync = ref.watch(outletsListProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text(
          'Ledger Integritas & Blockchain',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AsyncStateView<List<OutletModel>>(
        value: outletsAsync,
        onRetry: () => ref.invalidate(outletsListProvider),
        dataBuilder: (outlets) => _OutletLedger(outlets: outlets),
      ),
    );
  }
}

/// Ledger per outlet — widget class top-level (aturan E23).
class _OutletLedger extends ConsumerStatefulWidget {
  final List<OutletModel> outlets;

  const _OutletLedger({required this.outlets});

  @override
  ConsumerState<_OutletLedger> createState() => _OutletLedgerState();
}

class _OutletLedgerState extends ConsumerState<_OutletLedger> {
  String? _selectedOutletId;

  @override
  Widget build(BuildContext context) {
    final outlets = widget.outlets;
    if (outlets.isEmpty) {
      return const EmptyStateView(
        message: 'Tidak ada cabang yang dapat diakses.',
        icon: Icons.storefront_outlined,
      );
    }
    final selectedIndex = outlets.indexWhere(
      (item) => item.id == _selectedOutletId,
    );
    final outlet = outlets[selectedIndex >= 0 ? selectedIndex : 0];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: AppDropdown<String>(
            value: outlet.id,
            labelText: 'Cabang',
            items: outlets
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) => setState(() => _selectedOutletId = id),
          ),
        ),
        Expanded(
          child: AsyncStateView<IntegrityChainSnapshot>(
            value: ref.watch(integrityChainProvider(outlet.id)),
            onRetry: () => ref.invalidate(integrityChainProvider(outlet.id)),
            dataBuilder: (snapshot) => _LedgerView(outlet: outlet, snapshot: snapshot),
          ),
        ),
      ],
    );
  }
}

/// Tampilan ledger — widget class top-level (aturan E23).
class _LedgerView extends ConsumerStatefulWidget {
  final OutletModel outlet;
  final IntegrityChainSnapshot snapshot;

  const _LedgerView({required this.outlet, required this.snapshot});

  @override
  ConsumerState<_LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends ConsumerState<_LedgerView> {
  bool _isVerifying = false;
  bool _isClosingDay = false;

  Future<void> _verifyChain(String outletId) async {
    setState(() => _isVerifying = true);
    try {
      final snapshot = await ref.refresh(
        integrityChainProvider(outletId).future,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${snapshot.validation.status}: ${snapshot.validation.message}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: snapshot.validation.isValid
              ? const Color(0xFF15803D)
              : AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verifikasi gagal: $error', maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _closeCurrentDay(String outletId) async {
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tutup blok transaksi hari ini?', maxLines: 2, overflow: TextOverflow.ellipsis),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: const SingleChildScrollView(
            child: Text(
              'Transaksi aktif akan dirangkum ke dalam parent daily block.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tutup hari'),
          ),
        ],
      ),
    );
    if (shouldClose != true || !mounted) return;

    setState(() => _isClosingDay = true);
    try {
      await ref.read(integrityRepositoryProvider).closeCurrentDay(outletId);
      ref.invalidate(integrityChainProvider(outletId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily block berhasil dibuat.', maxLines: 2, overflow: TextOverflow.ellipsis),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menutup hari: $error', maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isClosingDay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;
    final snapshot = widget.snapshot;
    final overview = snapshot.overview;
    final validation = snapshot.validation;
    final statusColor = validation.isValid
        ? const Color(0xFF15803D)
        : AppTheme.dangerRed;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.refresh(integrityChainProvider(outlet.id).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: validation.isValid
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: validation.isValid
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  validation.isValid
                      ? Icons.verified_user_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 34,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        validation.isValid
                            ? 'Rantai valid'
                            : 'Integritas perlu diperiksa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${validation.status} · ${validation.message}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'Daily blocks',
                value: '${overview.totalDays}',
              ),
              _MetricChip(
                label: 'Transaksi aktif',
                value: '${overview.currentActiveTxCount}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isVerifying ? null : () => _verifyChain(outlet.id),
                icon: _isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_outlined),
                label: Text(_isVerifying ? 'Memeriksa...' : 'Uji Integritas', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (overview.currentActiveTxCount > 0)
                FilledButton.tonalIcon(
                  onPressed: _isClosingDay
                      ? null
                      : () => _closeCurrentDay(outlet.id),
                  icon: _isClosingDay
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_clock_outlined),
                  label: Text(_isClosingDay ? 'Menutup...' : 'Tutup hari', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Daily chain · ${outlet.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.lexend(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (overview.days.isEmpty)
            const EmptyStateView(
              message: 'Belum ada daily block yang ditutup untuk cabang ini.',
              icon: Icons.inventory_2_outlined,
            ),
          // List kecil — render inline tanpa scroll bersarang (aturan A4).
          ...overview.days.map((block) => _DailyBlockCard(block: block)),
        ],
      ),
    );
  }

}

/// Kartu satu daily block — widget class top-level (aturan E23).
class _DailyBlockCard extends StatelessWidget {
  final IntegrityDailyBlock block;

  const _DailyBlockCard({required this.block});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderOutline),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          'Daily block #${block.dayIndex} · ${block.date}',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 13),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${block.transactionCount} catatan transaksi / inventaris',
          style: GoogleFonts.lexend(fontSize: 11),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          _HashRow(label: 'Parent hash', value: block.parentHash),
          _HashRow(label: 'Previous parent', value: block.previousParentHash),
          _HashRow(label: 'Merkle root', value: block.merkleRoot),
          const Divider(),
          if (block.transactions.isEmpty)
            const Text('Tidak ada transaksi dalam blok ini.')
          else
            ...block.transactions.map(
              (transaction) => _TransactionBlockTile(transaction: transaction),
            ),
        ],
      ),
    );
  }
}

class _TransactionBlockTile extends StatelessWidget {
  final IntegrityTransactionBlock transaction;

  const _TransactionBlockTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isSale = transaction.eventType == 'sale';
    final title = transaction.receiptNo.isEmpty
        ? transaction.sourceId
        : transaction.receiptNo;
    final date = DateTime.tryParse(transaction.timestamp)?.toLocal();
    final formattedDate = date == null
        ? transaction.timestamp
        : '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSale ? Icons.receipt_long_outlined : Icons.inventory_2_outlined,
        color: AppTheme.primaryBlue,
      ),
      title: Text(
        title,
        style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${transaction.eventType} · $formattedDate\nHash ${transaction.hash}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.lexend(fontSize: 10),
      ),
      trailing: Text(
        MoneyFormatter.format(transaction.totalAmount),
        style: GoogleFonts.lexend(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HashRow extends StatelessWidget {
  final String label;
  final String value;

  const _HashRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              '$label:',
              style: GoogleFonts.lexend(
                fontSize: 10,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip metrik ledger — widget class top-level const (aturan E23).
class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '$label: $value',
        style: GoogleFonts.lexend(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
