import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
import '../../settings/presentation/currency_provider.dart';

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
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Ledger Integritas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Fitur audit blockchain hanya tersedia untuk Owner dan Manager.',
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Ledger Transaksi & Blockchain',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AsyncStateView<List<OutletModel>>(
        value: outletsAsync,
        onRetry: () => ref.invalidate(outletsListProvider),
        dataBuilder: (outlets) => _OutletLedger(
          outlets: outlets,
          isOwner: role == UserRole.owner,
        ),
      ),
    );
  }
}

class _OutletLedger extends ConsumerStatefulWidget {
  final List<OutletModel> outlets;
  // Revisi 22 Okt 2026: filter cabang hanya untuk owner,
  // manager terkunci ke cabang yang ditugaskan.
  final bool isOwner;

  const _OutletLedger({required this.outlets, required this.isOwner});

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
    final fallbackOutlet = outlets[selectedIndex >= 0 ? selectedIndex : 0];
    final user = ref.watch(authProvider).user;
    final lockedOutletId =
        (user?.outlets.isNotEmpty ?? false) ? user!.outlets.first.id : null;
    // Owner bebas memilih cabang, manager terkunci ke cabangnya sendiri.
    final outlet = widget.isOwner
        ? fallbackOutlet
        : outlets.firstWhere(
            (item) => item.id == lockedOutletId,
            orElse: () => fallbackOutlet,
          );

    return Column(
      children: [
        if (widget.isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: AppDropdown<String>(
              value: outlet.id,
              labelText: 'Pilih Cabang (Chain Independen)',
              items: outlets
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.id,
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) => setState(() => _selectedOutletId = id),
            ),
          )
        else
          // Non-owner: cabang terkunci, ditampilkan sebagai teks saja.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Cabang',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    outlet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: AsyncStateView<IntegrityChainSnapshot>(
            value: ref.watch(integrityChainProvider(outlet.id)),
            onRetry: () => ref.invalidate(integrityChainProvider(outlet.id)),
            dataBuilder: (snapshot) =>
                _SingleChainLedgerView(outlet: outlet, snapshot: snapshot),
          ),
        ),
      ],
    );
  }
}

class _SingleChainLedgerView extends ConsumerStatefulWidget {
  final OutletModel outlet;
  final IntegrityChainSnapshot snapshot;

  const _SingleChainLedgerView({
    required this.outlet,
    required this.snapshot,
  });

  @override
  ConsumerState<_SingleChainLedgerView> createState() =>
      _SingleChainLedgerViewState();
}

class _SingleChainLedgerViewState extends ConsumerState<_SingleChainLedgerView> {
  bool _isActionLoading = false;

  Future<void> _verifyChain(String outletId) async {
    setState(() => _isActionLoading = true);
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
          content: Text(
            'Verifikasi gagal: $error',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _simulateTamper(String outletId, int blockIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Simulasi Manipulasi Blok #$blockIndex?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            'Sistem akan sengaja mengubah nominal transaksi blok #$blockIndex menjadi ${ref.read(moneyFormatterProvider)(99999999)} di database. Ini untuk mendemonstrasikan bahwa sistem ARUS mendeteksi kecurangan (TAMPERED).',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simulasikan Tamper'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await ref
          .read(integrityRepositoryProvider)
          .simulateTamper(outletId, blockIndex, fakeAmount: 99999999);
      ref.invalidate(integrityChainProvider(outletId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Simulasi tamper berhasil pada Blok #$blockIndex! Periksa status verifikasi.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal simulasi tamper: $error'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _recoverBlock(String outletId, int blockIndex) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(integrityRepositoryProvider).recoverBlock(outletId, blockIndex);
      ref.invalidate(integrityChainProvider(outletId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blok #$blockIndex berhasil dipulihkan dari cadangan snapshot valid!',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memulihkan blok: $error'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outlet = widget.outlet;
    final snapshot = widget.snapshot;
    final overview = snapshot.overview;
    final validation = snapshot.validation;
    final isTampered = !validation.isValid;
    final tamperedIdx = validation.tamperedBlockIndex;

    final statusColor = validation.isValid
        ? AppTheme.jadeTosca
        : AppTheme.dangerRed;

    // Seluruh blok ditampilkan tanpa filter periode.
    final blocks = overview.blocks;

    return RefreshIndicator(
      color: AppTheme.jadeTosca,
      onRefresh: () async =>
          ref.refresh(integrityChainProvider(outlet.id).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Status Integritas Rantai
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: validation.isValid
                  ? const Color(0x1810B981)
                  : const Color(0x18EF4444),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: validation.isValid
                    ? const Color(0x3310B981)
                    : const Color(0x33EF4444),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  validation.isValid
                      ? Icons.verified_user_rounded
                      : Icons.gpp_bad_rounded,
                  color: statusColor,
                  size: 36,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        validation.isValid
                            ? 'Rantai Kriptografis Valid'
                            : 'Peringatan: Manipulasi Data Terdeteksi!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${validation.status} · ${validation.message}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
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

          // Metrik Ringkasan
          Chip(
            backgroundColor: AppTheme.darkCardSurfaceElevated,
            side: const BorderSide(color: AppTheme.darkCardBorder),
            label: Text(
              '${blocks.length} Blok Transaksi',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Uji Integritas (kembali ke satu tombol lebar penuh)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isActionLoading ? null : () => _verifyChain(outlet.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.jadeTosca,
                side: const BorderSide(color: AppTheme.jadeTosca),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: _isActionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.jadeTosca,
                      ),
                    )
                  : const Icon(Icons.shield_outlined, size: 18),
              label: const Text('Uji Integritas'),
            ),
          ),
          const SizedBox(height: 16),

          // Header List Transaksi
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rantai Transaksi · ${outlet.name}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SHA-256 Per-Cabang',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (blocks.isEmpty)
            const EmptyStateView(
              message:
                  'Belum ada blok transaksi tercatat untuk cabang ini.\nLakukan transaksi di Kasir POS untuk membentuk blok baru.',
              icon: Icons.link_off_rounded,
            )
          else ...[
            for (int i = 0; i < blocks.length; i++) ...[
              _TransactionBlockCard(
                block: blocks[i],
                isTampered: isTampered &&
                    (tamperedIdx == blocks[i].index ||
                        blocks[i].data['total_idr'] == 99999999 ||
                        blocks[i].data['totalAmount'] == 99999999),
                onSimulateTamper: () =>
                    _simulateTamper(outlet.id, blocks[i].index),
                onRecover: () =>
                    _recoverBlock(outlet.id, blocks[i].index),
              ),
              if (i < blocks.length - 1)
                _ChainConnector(
                  sourceIndex: blocks[i].index,
                  targetIndex: blocks[i + 1].index,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TransactionBlockCard extends ConsumerWidget {
  final IntegrityBlockItem block;
  final bool isTampered;
  final VoidCallback onSimulateTamper;
  final VoidCallback onRecover;

  const _TransactionBlockCard({
    required this.block,
    required this.isTampered,
    required this.onSimulateTamper,
    required this.onRecover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGenesis = block.isGenesis;
    final isSale = block.eventType == 'sale';
    final date = DateTime.tryParse(block.timestamp)?.toLocal();
    final formattedDate = date == null
        ? block.timestamp
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final borderColor = isTampered
        ? AppTheme.dangerRed
        : isGenesis
            ? const Color(0xFFF59E0B)
            : AppTheme.darkCardBorder;

    final badgeColor = isTampered
        ? AppTheme.dangerRed
        : isGenesis
            ? const Color(0xFFF59E0B)
            : AppTheme.jadeTosca;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: isTampered ? const Color(0x18EF4444) : AppTheme.darkCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: isTampered ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris 1: Header Blok
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withAlpha(70)),
                  ),
                  child: Text(
                    isGenesis
                        ? 'BLOK #${block.index} (GENESIS)'
                        : 'BLOK #${block.index}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSale
                        ? const Color(0x2210B981)
                        : const Color(0x22EF4444),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSale ? const Color(0x3310B981) : const Color(0x33EF4444),
                    ),
                  ),
                  child: Text(
                    isSale ? 'SALE' : block.eventType.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSale
                          ? const Color(0xFF34D399)
                          : AppTheme.dangerRed,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  ref.money(block.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isTampered ? AppTheme.dangerRed : AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Baris 2: Info Struk & Waktu
            Row(
              children: [
                Icon(
                  isSale
                      ? Icons.receipt_long_outlined
                      : Icons.swap_horiz_rounded,
                  size: 16,
                  color: AppTheme.jadeTosca,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    block.receiptNo.isNotEmpty
                        ? 'Struk: ${block.receiptNo}'
                        : 'Event ID: ${block.eventId}',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMutedDark,
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: AppTheme.darkCardBorder),

            // Baris 3: Data Hash Kriptografis
            _HashLine(label: 'Block Hash', value: block.hash, isPrimary: true),
            const SizedBox(height: 4),
            _HashLine(
              label: 'Prev Hash',
              value: block.previousHash,
              isGenesis: isGenesis,
            ),

            // Baris 4: Tombol Aksi Demo (Tamper / Pulihkan)
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isTampered) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.jadeTosca,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRecover,
                    icon: const Icon(Icons.restore_rounded, size: 15),
                    label: const Text('Pulihkan Blok'),
                  ),
                ] else ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.dangerRed,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onSimulateTamper,
                    icon: const Icon(Icons.bug_report_outlined, size: 14),
                    label: const Text(
                      'Simulasi Tamper',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HashLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;
  final bool isGenesis;

  const _HashLine({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isGenesis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: Text(
            '$label:',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMutedDark,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            isGenesis && value.startsWith('0000000000')
                ? '000000000000... (Genesis Block)'
                : value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
              color: isPrimary ? AppTheme.textPrimaryDark : AppTheme.textMutedDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChainConnector extends StatelessWidget {
  final int sourceIndex;
  final int targetIndex;

  const _ChainConnector({
    required this.sourceIndex,
    required this.targetIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 1.5,
              height: 18,
              color: AppTheme.jadeTosca.withAlpha(120),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.link_rounded,
              size: 16,
              color: AppTheme.jadeTosca,
            ),
            const SizedBox(width: 6),
            Text(
              'Terkunci SHA-256 (Blok #$sourceIndex ➔ Blok #$targetIndex)',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.jadeTosca,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 1.5,
              height: 18,
              color: AppTheme.jadeTosca.withAlpha(120),
            ),
          ],
        ),
      ),
    );
  }
}
