import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/status_badge.dart';
import '../data/insights_repository.dart';
import '../domain/insight_models.dart';
import 'insights_provider.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  void _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String id,
    String status,
  ) async {
    try {
      await ref.read(insightsRepositoryProvider).updateStatus(id, status);
      ref.invalidate(insightsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'acknowledged'
                  ? 'Rekomendasi diterima.'
                  : 'Rekomendasi diabaikan.',
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
            content: Text(
              'Gagal mengubah status: $e',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppTheme.dangerRedStrong,
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
            content: Text(
              'Gagal menjalankan rule engine: $e',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppTheme.dangerRedStrong,
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
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rekomendasi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Keputusan bisnis berbasis data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMutedDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: insights.length + 3,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _InsightSummaryCard(
                          item: _priorityInsight(insights),
                        );
                      }
                      if (index == 1) {
                        return _SectionHead(count: insights.length);
                      }
                      if (index == insights.length + 2) {
                        return const _PipelineNote();
                      }

                      final item = insights[index - 2];
                      return _InsightCard(
                        item: item,
                        onDismiss: () =>
                            _updateStatus(context, ref, item.id, 'dismissed'),
                        onAcknowledge: () => _updateStatus(
                          context,
                          ref,
                          item.id,
                          'acknowledged',
                        ),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
        ),
        selected: selected,
        selectedColor: selectedColor,
        backgroundColor: AppTheme.darkCardSurface,
        side: const BorderSide(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondaryDark,
        ),
        onSelected: (isSelected) {
          ref.read(selectedSeverityFilterProvider.notifier).state = isSelected
              ? value
              : null;
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
          chip('Peringatan', 'warning', AppTheme.warningAmber),
        ],
      ),
    );
  }
}

/// Temuan paling berat dipakai sebagai ringkasan di kepala daftar.
BusinessInsightModel _priorityInsight(List<BusinessInsightModel> insights) {
  for (final severity in const ['critical', 'warning']) {
    for (final item in insights) {
      if (item.severity == severity) return item;
    }
  }
  return insights.first;
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
        color: isCritical ? AppTheme.dangerTintSoft : AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical ? AppTheme.dangerTintStrong : AppTheme.darkCardBorder,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryDark,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: item.ruleCode,
                kind: isCritical ? StatusKind.danger : StatusKind.primary,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 10),

          // Saran / Rekomendasi
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.jadeTosca.withAlpha(100),
                width: AppTheme.hairline,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  size: 16,
                  color: AppTheme.jadeTosca,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rekomendasi: ${item.recommendation}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.jadeTosca,
                        ),
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
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppTheme.textMutedDark,
                        fontWeight: FontWeight.w600,
                      ),
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
                ),
                child: Text(
                  'Tindak Lanjuti',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

StatusKind _severityToKind(String severity) {
  switch (severity) {
    case 'critical':
      return StatusKind.danger;
    case 'warning':
      return StatusKind.warning;
    default:
      return StatusKind.primary;
  }
}

Color _severityTone(String severity) {
  switch (severity) {
    case 'critical':
      return AppTheme.dangerRed;
    case 'warning':
      return AppTheme.warningAmber;
    default:
      return AppTheme.jadeTosca;
  }
}

/// Tingkat keyakinan: rule engine ARUS memakai ambang batas tetap, jadi
/// tingkat keparahan temuan menentukan seberapa kuat rekomendasi disarankan.
({String label, double ratio}) _confidenceOf(String severity) {
  switch (severity) {
    case 'critical':
      return (label: 'SANGAT TINGGI', ratio: 0.92);
    case 'warning':
      return (label: 'TINGGI', ratio: 0.74);
    default:
      return (label: 'SEDANG', ratio: 0.52);
  }
}

/// Label prioritas tindakan yang menyertai tingkat keparahan temuan.
({String label, IconData icon}) _priorityTag(String severity) {
  switch (severity) {
    case 'critical':
      return (label: 'Prioritas tinggi', icon: Icons.priority_high_rounded);
    case 'warning':
      return (label: 'Perlu tindakan', icon: Icons.schedule_rounded);
    default:
      return (label: 'Informasi', icon: Icons.info_outline_rounded);
  }
}

/// Ringkasan temuan paling berat di kepala daftar rekomendasi.
class _InsightSummaryCard extends StatelessWidget {
  final BusinessInsightModel item;

  const _InsightSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final tone = _severityTone(item.severity);
    final confidence = _confidenceOf(item.severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withAlpha(70), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Keyakinan',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMutedDark,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              StatusBadge(
                label: confidence.label,
                kind: _severityToKind(item.severity),
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.ratio,
              minHeight: 6,
              backgroundColor: AppTheme.darkCardSurfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(tone),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.recommendation,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                  color: AppTheme.textPrimaryDark,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.outletName != null)
                _SummaryChip(
                  icon: Icons.storefront_rounded,
                  label: item.outletName!,
                  tone: tone,
                ),
              if (item.productName != null)
                _SummaryChip(
                  icon: Icons.inventory_2_outlined,
                  label: item.productName!,
                  tone: tone,
                ),
              _SummaryChip(
                icon: _priorityTag(item.severity).icon,
                label: _priorityTag(item.severity).label,
                tone: tone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Label kecil di dalam kartu ringkasan.
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tone;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryDark,
                ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian daftar rekomendasi.
class _SectionHead extends StatelessWidget {
  final int count;

  const _SectionHead({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            'Semua Rekomendasi',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryDark,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.darkCardSurfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.darkCardBorder, width: AppTheme.hairline),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryDark,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Catatan alur pengambilan keputusan di kaki daftar.
class _PipelineNote extends StatelessWidget {
  const _PipelineNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_tree_outlined,
            size: 14,
            color: AppTheme.textMutedDark,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Rekomendasi mengikuti alur Data → Informasi → Wawasan → Rekomendasi → Keputusan.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    height: 1.4,
                    color: AppTheme.textMutedDark,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
