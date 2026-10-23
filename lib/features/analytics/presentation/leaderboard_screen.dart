import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/dashboard_filter_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../settings/presentation/currency_provider.dart';
import '../domain/analytics_models.dart';
import 'analytics_provider.dart';

/// Halaman Leaderboard Menu Terlaris.
/// Data: GET /api/analytics/leaderboard (dihitung backend dari database).
/// Filter: Owner bisa pilih Semua Cabang / cabang tertentu + periode waktu.
/// Manager hanya periode waktu, dan backend mengunci ke cabang sendiri.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isManager = user?.role == UserRole.manager;

    final selectedOutletId = isManager && (user?.outlets.isNotEmpty ?? false)
        ? user!.outlets.first.id
        : ref.watch(selectedOutletFilterProvider);
    final selectedDateFilter = ref.watch(selectedDateFilterProvider);
    final selectedCustomDate = ref.watch(selectedCustomDateProvider);

    final List<({String id, String name})> outlets = (user?.outlets ?? [])
        .map((o) => (id: o.id, name: o.name))
        .toList();

    // Label cabang
    String branchLabel = 'Semua Cabang';
    if (isManager) {
      if (selectedOutletId != null) {
        final found = outlets.where((o) => o.id == selectedOutletId);
        if (found.isNotEmpty) {
          branchLabel = found.first.name;
        } else if (outlets.isNotEmpty) {
          branchLabel = outlets.first.name;
        }
      } else if (outlets.isNotEmpty) {
        branchLabel = outlets.first.name;
      } else {
        branchLabel = 'Cabang Saya';
      }
    } else if (selectedOutletId != null) {
      final found = outlets.where((o) => o.id == selectedOutletId);
      if (found.isNotEmpty) {
        branchLabel = found.first.name;
      }
    }

    final String dayLabel = selectedCustomDate != null
        ? DateFormat('d MMM yyyy', 'id_ID').format(selectedCustomDate)
        : selectedDateFilter.label;

    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Menu Terlaris',
          style: GoogleFonts.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            tooltip: 'Muat Ulang',
            onPressed: () => ref.invalidate(leaderboardProvider),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1.0, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00A896),
          onRefresh: () async => ref.invalidate(leaderboardProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Banner filter aktif
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 20,
                        color: Color(0xFF00A896),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Aktif',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              'Di "$branchLabel" pada "$dayLabel".',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => showDashboardFilterSheet(
                          context,
                          outlets: outlets,
                          selectedOutletId: selectedOutletId,
                          selectedDateFilter: selectedDateFilter,
                          selectedCustomDate: selectedCustomDate,
                          isManager: isManager,
                          ownerTitle: 'Filter Leaderboard Menu',
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.filter_alt_outlined,
                                size: 16,
                                color: Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ubah',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Daftar leaderboard
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: AsyncStateView<List<TopSellingProductModel>>(
                    value: leaderboardAsync,
                    onRetry: () => ref.invalidate(leaderboardProvider),
                    dataBuilder: (list) {
                      if (list.isEmpty) {
                        return const EmptyStateView(
                          message:
                              'Belum ada data penjualan menu untuk periode ini.',
                          icon: Icons.leaderboard_outlined,
                        );
                      }

                      final podium = list.take(3).toList(growable: false);
                      final rest = list.skip(3).toList(growable: false);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Podium 3 besar (lihat mockup Papan Peringkat).
                          if (podium.isNotEmpty)
                            _LeaderboardPodium(top3: podium),
                          for (final item in rest)
                            _LeaderboardItemCard(item: item),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Podium tiga besar: urutan tampil 2 - 1 - 3 supaya juara di tengah.
class _LeaderboardPodium extends StatelessWidget {
  final List<TopSellingProductModel> top3;

  const _LeaderboardPodium({required this.top3});

  @override
  Widget build(BuildContext context) {
    final order = <int>[1, 0, 2];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final idx in order)
            if (idx < top3.length)
              Expanded(
                child: _PodiumColumn(
                  item: top3[idx],
                  isWinner: idx == 0,
                ),
              ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final TopSellingProductModel item;
  final bool isWinner;

  const _PodiumColumn({required this.item, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    final Color accent = item.rank == 1
        ? const Color(0xFFF59E0B)
        : item.rank == 2
            ? const Color(0xFF94A3B8)
            : const Color(0xFFC2410C);
    final double blockHeight = item.rank == 1 ? 64 : (item.rank == 2 ? 50 : 40);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.rank == 1 ? Icons.emoji_events_rounded : Icons.workspace_premium_outlined,
            size: isWinner ? 26 : 20,
            color: accent,
          ),
          const SizedBox(height: 4),
          Text(
            item.productName,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: isWinner ? 12 : 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: blockHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(top: BorderSide(color: accent, width: 2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#${item.rank}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                Text(
                  '${item.quantitySold} terjual',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardItemCard extends ConsumerWidget {
  final TopSellingProductModel item;

  const _LeaderboardItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTop3 = item.rank <= 3;
    final Color badgeBg = item.rank == 1
        ? const Color(0xFFFEF3C7) // emas
        : item.rank == 2
            ? const Color(0xFFE2E8F0) // perak
            : item.rank == 3
                ? const Color(0xFFFFEDD5) // perunggu
                : const Color(0xFFF1F5F9);
    final Color badgeText = item.rank == 1
        ? const Color(0xFFB45309)
        : item.rank == 2
            ? const Color(0xFF475569)
            : item.rank == 3
                ? const Color(0xFFC2410C)
                : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge peringkat
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${item.rank}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: badgeText,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Nama menu & kategori
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.categoryName,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Jumlah terjual & omzet
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isTop3
                      ? const Color(0xFFE6F6F4)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.quantitySold} terjual',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isTop3
                        ? const Color(0xFF00A896)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ref.money(item.totalRevenueIdr),
                style: GoogleFonts.lexend(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
