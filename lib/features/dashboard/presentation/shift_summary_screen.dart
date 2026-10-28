import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../analytics/presentation/analytics_provider.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../analytics/domain/analytics_models.dart';
import '../../settings/presentation/currency_provider.dart';
import '../../../core/sync/sync_service.dart';

class ShiftSummaryScreen extends ConsumerWidget {
  const ShiftSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final shiftAsync = ref.watch(shiftSummaryProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: AppTheme.darkCardBorder,
          ),
        ),
        title: Text(
          'Ringkasan Shift Saya',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 16.5,
            color: AppTheme.textPrimaryDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Refresh Shift',
            onPressed: () async {
              try {
                await ref.read(syncServiceProvider).syncPendingTransactions();
              } catch (_) {}
              ref.invalidate(shiftSummaryProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.jadeTosca,
        backgroundColor: AppTheme.darkCardSurfaceElevated,
        onRefresh: () async {
          try {
            await ref.read(syncServiceProvider).syncPendingTransactions();
          } catch (_) {}
          ref.invalidate(shiftSummaryProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Header Kasir
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.jadeTosca.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_outlined, color: AppTheme.jadeTosca, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Kasir',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                  color: AppTheme.textPrimaryDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Outlet: ${user?.outlets.isNotEmpty == true ? user!.outlets.first.name : "Utama"}',
                                style: GoogleFonts.inter(
                                  color: AppTheme.textMutedDark,
                                  fontSize: 12.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shift Card Data
                  AsyncStateView<ShiftSummaryModel>(
                    value: shiftAsync,
                    onRetry: () async {
                      try {
                        await ref.read(syncServiceProvider).syncPendingTransactions();
                      } catch (_) {}
                      ref.invalidate(shiftSummaryProvider);
                    },
                    dataBuilder: (shift) => _ShiftMetrics(shift: shift),
                  ),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.jadeTosca, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pastikan jumlah uang tunai di laci kasir cocok dengan total kas di atas saat serah terima shift.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeLight,
        child: scaffold,
      );
    }
    return scaffold;
  }
}

/// Metrik shift — widget class top-level
class _ShiftMetrics extends ConsumerWidget {
  final ShiftSummaryModel shift;

  const _ShiftMetrics({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shift.isDataAvailable) {
      return ShadCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFFD97706)),
            const SizedBox(height: 10),
            Text(
              'Data Shift Belum Tersedia Offline',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppTheme.textPrimaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada transaksi lokal yang tercatat di perangkat ini untuk hari ini. Hubungkan perangkat ke internet untuk memuat data server atau lakukan transaksi baru.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textMutedDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (shift.isOffline) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFFB45309), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Offline',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Menampilkan penjualan dari data lokal perangkat ini. Angka belum mencakup perubahan dari perangkat lain.',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (shift.pendingCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.jadeTosca.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.jadeTosca.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_rounded, color: AppTheme.jadeTosca, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${shift.pendingCount} transaksi lokal menunggu sinkronisasi.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.jadeTosca,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ShiftMetricTile(
          title: 'Total Penjualan Shift Hari Ini',
          value: ref.money(shift.todayRevenueIdr),
          icon: Icons.payments_rounded,
          color: AppTheme.jadeTosca,
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ShiftMetricTile(
                title: 'Uang Tunai (Cash)',
                value: ref.money(shift.cashRevenueIdr),
                icon: Icons.money_rounded,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ShiftMetricTile(
                title: 'Non-Tunai (QRIS)',
                value: ref.money(shift.qrisRevenueIdr),
                icon: Icons.qr_code_2_rounded,
                color: AppTheme.jadeTosca,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ShiftMetricTile(
          title: 'Jumlah Transaksi Berhasil',
          value: '${shift.transactionCount} Transaksi',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFFA855F7),
          subtitle: 'Ketuk untuk melihat riwayat & detail struk',
          onTap: () => context.push('/pos/history'),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/pos/history'),
            icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.jadeTosca),
            label: Text(
              'Buka Riwayat & Detail Transaksi',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.jadeTosca,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.jadeTosca),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tile metrik shift — widget class top-level memakai ShadCard
class _ShiftMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final String? subtitle;
  final VoidCallback? onTap;

  const _ShiftMetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = ShadCard(
      padding: EdgeInsets.all(isPrimary ? 18 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isPrimary ? 13 : 11,
                    color: AppTheme.textMutedDark,
                    fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textMutedDark,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: isPrimary ? 22 : 16,
              fontWeight: FontWeight.w800,
              color: isPrimary ? AppTheme.jadeTosca : AppTheme.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.jadeTosca,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }
}
