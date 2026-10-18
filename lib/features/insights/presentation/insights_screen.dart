import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../data/insights_repository.dart';
import '../domain/insight_models.dart';
import 'insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  void _updateStatus(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(insightsRepositoryProvider).updateStatus(id, status);
      ref.invalidate(insightsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'acknowledged' ? 'Rekomendasi diterima.' : 'Rekomendasi diabaikan.',
              style: GoogleFonts.lexend(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppTheme.textPrimaryDark,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e', style: GoogleFonts.lexend(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _triggerGeneration(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(insightsRepositoryProvider).triggerGeneration();
      ref.invalidate(insightsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rule engine selesai mengevaluasi inventaris & transaksi!',
              style: GoogleFonts.lexend(fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppTheme.jadeTosca,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menjalankan rule engine: $e', style: GoogleFonts.lexend(fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsListProvider);
    final selectedSeverity = ref.watch(selectedSeverityFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          'Rekomendasi Keputusan (AI/DSS)',
          style: GoogleFonts.lexend(fontWeight: FontWeight.w700, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: AppTheme.jadeTosca),
            tooltip: 'Evaluasi Rule Engine Sekarang',
            onPressed: () => _triggerGeneration(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(insightsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          _SeverityFilters(selectedSeverity: selectedSeverity),
          const Divider(height: 1, color: AppTheme.darkCardBorder),

          // List Insights
          Expanded(
            child: AsyncStateView<List<BusinessInsightModel>>(
              value: insightsAsync,
              onRetry: () => ref.invalidate(insightsListProvider),
              dataBuilder: (insights) {
                if (insights.isEmpty) {
                  return const EmptyStateView(
                    message: 'Kondisi Bisnis Prima! Tidak ada peringatan kritis atau anomali stok yang terdeteksi.',
                    icon: Icons.verified_rounded,
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.jadeTosca,
                  onRefresh: () async => ref.invalidate(insightsListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: insights.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = insights[index];
                      return _InsightCard(
                        item: item,
                        onDismiss: () => _updateStatus(context, ref, item.id, 'dismissed'),
                        onAcknowledge: () => _updateStatus(context, ref, item.id, 'acknowledged'),
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

/// Filter severity — widget class top-level ConsumerWidget (aturan E23).
class _SeverityFilters extends ConsumerWidget {
  final String? selectedSeverity;

  const _SeverityFilters({required this.selectedSeverity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(String label, String? value, Color selectedColor) {
      final selected = selectedSeverity == value;
      return ChoiceChip(
        label: Text(
          label,
          style: GoogleFonts.lexend(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        selectedColor: selectedColor,
        backgroundColor: AppTheme.darkCardSurface,
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondaryDark),
        onSelected: (isSelected) {
          ref.read(selectedSeverityFilterProvider.notifier).state =
              isSelected ? value : null;
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          chip('Semua', null, AppTheme.jadeTosca),
          const SizedBox(width: 8),
          chip('Kritis', 'critical', AppTheme.dangerRed),
          const SizedBox(width: 8),
          chip('Peringatan', 'warning', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

/// Kartu satu insight — widget class top-level (aturan E23).
class _InsightCard extends StatelessWidget {
  final BusinessInsightModel item;
  final VoidCallback onDismiss;
  final VoidCallback onAcknowledge;

  const _InsightCard({
    required this.item,
    required this.onDismiss,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final isCritical = item.isCritical;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0x18EF4444) : AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? const Color(0x33EF4444) : AppTheme.darkCardBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? Icons.warning_rounded : Icons.info_outline_rounded,
                size: 20,
                color: isCritical ? AppTheme.dangerRed : AppTheme.jadeTosca,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: GoogleFonts.lexend(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical ? const Color(0x22EF4444) : AppTheme.darkCardSurfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCritical ? const Color(0x33EF4444) : AppTheme.darkCardBorder,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  item.ruleCode,
                  style: GoogleFonts.lexend(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isCritical ? AppTheme.dangerRed : AppTheme.jadeTosca,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textSecondaryDark, height: 1.35),
          ),
          const SizedBox(height: 10),

          // Saran / Rekomendasi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.jadeTosca.withAlpha(100), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 16, color: AppTheme.jadeTosca),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rekomendasi: ${item.recommendation}',
                    style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.jadeTosca),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  'Abaikan',
                  style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAcknowledge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jadeTosca,
                  minimumSize: const Size(110, 36),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Tindak Lanjuti',
                  style: GoogleFonts.lexend(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
