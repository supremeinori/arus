import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/analytics_models.dart';
import 'analytics_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with WidgetsBindingObserver {
  Timer? _autoSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Refresh data saat layar pertama kali dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(salesForecastProvider);
        ref.invalidate(stockoutForecastProvider);
      }
    });

    // Auto-sync otomatis setiap 30 detik untuk memperbarui analitik secara stabil dan hemat daya
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(salesForecastProvider);
        ref.invalidate(stockoutForecastProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(salesForecastProvider);
      ref.invalidate(stockoutForecastProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(analyticsActiveTabProvider);

    final scaffold = Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(
            height: 1.0,
            thickness: 1.0,
            color: AppTheme.darkCardBorder,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analitik Prediktif',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: AppTheme.textPrimaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Peramalan Deret Waktu & Estimasi Stok Habis',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.jadeTosca,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryDark),
            tooltip: 'Segarkan Prediksi',
            onPressed: () {
              ref.invalidate(salesForecastProvider);
              ref.invalidate(stockoutForecastProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.jadeTosca,
        backgroundColor: AppTheme.darkCardSurfaceElevated,
        onRefresh: () async {
          ref.invalidate(salesForecastProvider);
          ref.invalidate(stockoutForecastProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Tab Switcher Modern
                  _AnalyticsSegmentedTab(
                    selectedIndex: activeTab,
                    onTabChanged: (index) {
                      ref.read(analyticsActiveTabProvider.notifier).state = index;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Konten Berdasarkan Tab
                  if (activeTab == 0)
                    const _SalesForecastSection()
                  else
                    const _StockoutForecastSection(),
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

// =========================================================================
// TAB SWITCHER
// =========================================================================

class _AnalyticsSegmentedTab extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const _AnalyticsSegmentedTab({
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Prediksi Penjualan',
              icon: Icons.trending_up_rounded,
              isSelected: selectedIndex == 0,
              onTap: () => onTabChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: 'Radar Stok Habis',
              icon: Icons.inventory_2_outlined,
              isSelected: selectedIndex == 1,
              onTap: () => onTabChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkCardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.jadeTosca : AppTheme.textMutedDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimaryDark : AppTheme.textMutedDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// SECTION 1: PREDIKSI PENJUALAN PERIODIK (TIME SERIES FORECASTING)
// =========================================================================

class _SalesForecastSection extends ConsumerWidget {
  const _SalesForecastSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horizon = ref.watch(selectedForecastHorizonProvider);
    final forecastAsync = ref.watch(salesForecastProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Horizon Waktu (Minggu Depan vs Bulan Depan)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Peramalan Deret Waktu',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Dekomposisi tren musiman harian',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMutedDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HorizonPicker(
              selectedHorizon: horizon,
              onChanged: (newVal) {
                ref.read(selectedForecastHorizonProvider.notifier).state = newVal;
              },
            ),
          ],
        ),

        const SizedBox(height: 16),

        AsyncStateView<SalesForecastModel>(
          value: forecastAsync,
          onRetry: () => ref.invalidate(salesForecastProvider),
          dataBuilder: (model) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3 Kartu Metrik Ringkasan Prediksi
                _SalesForecastKpis(summary: model.summary, horizonDays: model.horizonDays),

                const SizedBox(height: 16),

                // AI Insight Card
                _AiInsightBanner(text: model.summary.aiInsight),

                const SizedBox(height: 16),

                // Grafik Garis Interaktif: Aktual vs Prediksi
                _PredictiveChartCard(model: model),

                const SizedBox(height: 20),

                // Detail Proyeksi Harian
                Text(
                  'Rincian Proyeksi Harian',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                _DailyForecastList(forecast: model.forecast),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HorizonPicker extends StatelessWidget {
  final int selectedHorizon;
  final ValueChanged<int> onChanged;

  const _HorizonPicker({
    required this.selectedHorizon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.darkCardSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HorizonPill(
            label: '7 Hari',
            isSelected: selectedHorizon == 7,
            onTap: () => onChanged(7),
          ),
          _HorizonPill(
            label: '30 Hari',
            isSelected: selectedHorizon == 30,
            onTap: () => onChanged(30),
          ),
        ],
      ),
    );
  }
}

class _HorizonPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _HorizonPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.jadeTosca : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textMutedDark,
          ),
        ),
      ),
    );
  }
}

class _SalesForecastKpis extends StatelessWidget {
  final SalesForecastSummary summary;
  final int horizonDays;

  const _SalesForecastKpis({
    required this.summary,
    required this.horizonDays,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.growthPct >= 0;

    return Row(
      children: [
        // Kartu 1: Total Proyeksi
        Expanded(
          child: ShadCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimasi Omzet',
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  summary.formattedProjectedTotal,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.formattedAvgDaily}/hari',
                  style: GoogleFonts.inter(color: AppTheme.jadeTosca, fontSize: 10.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Kartu 2: Pertumbuhan Model
        Expanded(
          child: ShadCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tren Model',
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 16,
                      color: isPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${isPositive ? '+' : ''}${summary.growthPct.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isPositive ? AppTheme.successGreen : AppTheme.dangerRed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'vs $horizonDays hari lalu',
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Kartu 3: Puncak Penjualan
        Expanded(
          child: ShadCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hari Puncak',
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  summary.peakProjectedDay.dayName.isNotEmpty
                      ? summary.peakProjectedDay.dayName
                      : 'Sabtu',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppTheme.textPrimaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  summary.peakProjectedDay.formattedRevenue,
                  style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AiInsightBanner extends StatelessWidget {
  final String text;

  const _AiInsightBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.jadeTosca.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.jadeTosca.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.jadeTosca.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.jadeTosca,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Business Copilot Insight',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppTheme.jadeTosca,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textPrimaryDark,
                    height: 1.35,
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

// =========================================================================
// INTERACTIVE PREDICTIVE LINE CHART CARD
// =========================================================================

class _PredictiveChartCard extends StatefulWidget {
  final SalesForecastModel model;

  const _PredictiveChartCard({required this.model});

  @override
  State<_PredictiveChartCard> createState() => _PredictiveChartCardState();
}

class _PredictiveChartCardState extends State<_PredictiveChartCard> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final allPoints = <ForecastPoint>[
      ...widget.model.historical,
      ...widget.model.forecast,
    ];

    if (allPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVal = allPoints.map((p) => math.max(p.upperBoundIdr, p.revenueIdr)).reduce(math.max);
    final minVal = allPoints.map((p) => p.revenueIdr).reduce(math.min);

    ForecastPoint? activePoint;
    if (touchedIndex != null && touchedIndex! >= 0 && touchedIndex! < allPoints.length) {
      activePoint = allPoints[touchedIndex!];
    }

    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Grafik Proyeksi Omzet',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppTheme.textPrimaryDark,
                ),
              ),
              // Legend
              Row(
                children: [
                  _LegendIndicator(
                    color: AppTheme.jadeTosca,
                    label: 'Aktual',
                    isDashed: false,
                  ),
                  const SizedBox(width: 8),
                  _LegendIndicator(
                    color: const Color(0xFF0284C7), // Sky Blue
                    label: 'Prediksi',
                    isDashed: true,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Active Touch Info Box
          if (activePoint != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkCardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${activePoint.dayName.isNotEmpty ? activePoint.dayName : ''} ${activePoint.date}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                  ),
                  Text(
                    '${activePoint.isProjected ? "Estimasi: " : "Aktual: "}${MoneyFormatter.format(activePoint.revenueIdr)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: activePoint.isProjected ? const Color(0xFF0284C7) : AppTheme.jadeTosca,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ketuk titik pada grafik untuk rincian',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark, fontStyle: FontStyle.italic),
              ),
            ),

          // Canvas Chart
          GestureDetector(
            onPanDown: (details) => _handleTouch(details.localPosition.dx, allPoints.length),
            onPanUpdate: (details) => _handleTouch(details.localPosition.dx, allPoints.length),
            child: SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _PredictiveChartPainter(
                  historicalCount: widget.model.historical.length,
                  points: allPoints,
                  maxVal: math.max(1, maxVal),
                  minVal: math.max(0, minVal),
                  touchedIndex: touchedIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTouch(double localX, int totalPoints) {
    if (totalPoints <= 1) return;
    const padding = 16.0;
    final renderBox = context.findRenderObject() as RenderBox?;
    final chartWidth = (renderBox?.size.width ?? 320) - 32; // card padding
    final usableWidth = chartWidth - (padding * 2);
    final relativeX = (localX - padding).clamp(0.0, usableWidth);
    final index = ((relativeX / usableWidth) * (totalPoints - 1)).round();
    setState(() {
      touchedIndex = index.clamp(0, totalPoints - 1);
    });
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _LegendIndicator({
    required this.color,
    required this.label,
    required this.isDashed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
        ),
      ],
    );
  }
}

class _PredictiveChartPainter extends CustomPainter {
  final int historicalCount;
  final List<ForecastPoint> points;
  final int maxVal;
  final int minVal;
  final int? touchedIndex;

  _PredictiveChartPainter({
    required this.historicalCount,
    required this.points,
    required this.maxVal,
    required this.minVal,
    this.touchedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final n = points.length;
    final double left = 10.0;
    final double right = size.width - 10.0;
    final double top = 10.0;
    final double bottom = size.height - 20.0;
    final double chartH = bottom - top;
    final double stepX = (right - left) / (n - 1);

    // 1. Gambar Garis Grid Horizontal
    final gridPaint = Paint()
      ..color = AppTheme.darkCardBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    for (int g = 0; g <= 3; g++) {
      final y = top + (chartH / 3) * g;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
    }

    // Hitung koordinat (x, y) untuk tiap titik
    final coords = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = left + i * stepX;
      final ratio = (points[i].revenueIdr - (minVal * 0.8)) / (maxVal - (minVal * 0.8));
      final y = bottom - (ratio.clamp(0.05, 1.0) * chartH);
      coords.add(Offset(x, y));
    }

    // 2. Gambar Confidence Interval Band untuk Proyeksi
    if (historicalCount < n) {
      final bandPath = Path();
      // Garis atas
      for (int i = historicalCount - 1; i < n; i++) {
        final x = left + i * stepX;
        final upRatio = (points[i].upperBoundIdr - (minVal * 0.8)) / (maxVal - (minVal * 0.8));
        final yUp = bottom - (upRatio.clamp(0.05, 1.0) * chartH);
        if (i == historicalCount - 1) {
          bandPath.moveTo(x, coords[i].dy);
        } else {
          bandPath.lineTo(x, yUp);
        }
      }
      // Garis bawah terbalik
      for (int i = n - 1; i >= historicalCount - 1; i--) {
        final x = left + i * stepX;
        final lowRatio = (points[i].lowerBoundIdr - (minVal * 0.8)) / (maxVal - (minVal * 0.8));
        final yLow = bottom - (lowRatio.clamp(0.05, 1.0) * chartH);
        bandPath.lineTo(x, yLow);
      }
      bandPath.close();

      final bandPaint = Paint()
        ..color = const Color(0xFF0284C7).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawPath(bandPath, bandPaint);
    }

    // 3. Garis Solid untuk Data Riwayat Aktual
    if (historicalCount > 1) {
      final histPath = Path();
      histPath.moveTo(coords[0].dx, coords[0].dy);
      for (int i = 1; i < historicalCount; i++) {
        histPath.lineTo(coords[i].dx, coords[i].dy);
      }

      final histPaint = Paint()
        ..color = AppTheme.jadeTosca
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(histPath, histPaint);
    }

    // 4. Garis Putus-putus untuk Data Prediksi Masa Depan
    if (historicalCount <= n && coords.length >= historicalCount) {
      final startIdx = math.max(0, historicalCount - 1);
      final fcstPaint = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = startIdx; i < n - 1; i++) {
        _drawDashedLine(canvas, coords[i], coords[i + 1], fcstPaint);
      }
    }

    // 5. Titik-titik Lingkaran & Highlight
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < n; i++) {
      final isProjected = points[i].isProjected;
      final isTouched = touchedIndex == i;

      dotPaint.color = isProjected ? const Color(0xFF0284C7) : AppTheme.jadeTosca;
      final radius = isTouched ? 5.5 : 3.0;

      canvas.drawCircle(coords[i], radius, dotPaint);
      canvas.drawCircle(coords[i], radius, ringPaint);

      // Garis pandu vertikal jika disentuh
      if (isTouched) {
        final guidePaint = Paint()
          ..color = AppTheme.textMutedDark.withValues(alpha: 0.4)
          ..strokeWidth = 1.0;
        canvas.drawLine(Offset(coords[i].dx, top), Offset(coords[i].dx, bottom), guidePaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final double dx = p2.dx - p1.dx;
    final double dy = p2.dy - p1.dy;
    final double dist = math.sqrt(dx * dx + dy * dy);
    const double dashWidth = 4.0;
    const double dashSpace = 3.0;
    double currentDist = 0.0;

    while (currentDist < dist) {
      final double startFraction = currentDist / dist;
      final double endFraction = math.min((currentDist + dashWidth) / dist, 1.0);
      final Offset start = Offset(p1.dx + dx * startFraction, p1.dy + dy * startFraction);
      final Offset end = Offset(p1.dx + dx * endFraction, p1.dy + dy * endFraction);
      canvas.drawLine(start, end, paint);
      currentDist += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _PredictiveChartPainter oldDelegate) {
    return oldDelegate.touchedIndex != touchedIndex || oldDelegate.points != points;
  }
}

class _DailyForecastList extends StatelessWidget {
  final List<ForecastPoint> forecast;

  const _DailyForecastList({required this.forecast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: forecast.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ShadCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      f.dayName.isNotEmpty ? f.dayName.substring(0, 3) : 'H+?',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.dayName}, ${f.date}',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Rentang: ${MoneyFormatter.format(f.lowerBoundIdr)} - ${MoneyFormatter.format(f.upperBoundIdr)}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  f.formattedRevenue,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =========================================================================
// SECTION 2: RADAR PREDIKSI KAPAN STOK HABIS (STOCK RUNOUT ESTIMATION)
// =========================================================================

class _StockoutForecastSection extends ConsumerWidget {
  const _StockoutForecastSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockoutAsync = ref.watch(stockoutForecastProvider);
    final activeFilter = ref.watch(selectedStockoutFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AsyncStateView<StockoutForecastModel>(
          value: stockoutAsync,
          onRetry: () => ref.invalidate(stockoutForecastProvider),
          dataBuilder: (model) {
            final summary = model.summary;
            var items = model.items;

            if (activeFilter == 'critical') {
              items = items.where((i) => i.isCritical).toList();
            } else if (activeFilter == 'warning') {
              items = items.where((i) => i.isWarning).toList();
            } else if (activeFilter == 'safe') {
              items = items.where((i) => i.isSafe).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3 Status Counter Cards
                Row(
                  children: [
                    Expanded(
                      child: _StockStatusCard(
                        label: 'Kritis (<3 hari)',
                        count: summary.criticalCount,
                        color: AppTheme.dangerRed,
                        isSelected: activeFilter == 'critical',
                        onTap: () {
                          ref.read(selectedStockoutFilterProvider.notifier).state =
                              activeFilter == 'critical' ? 'all' : 'critical';
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StockStatusCard(
                        label: 'Waspada (3-6 hr)',
                        count: summary.warningCount,
                        color: AppTheme.warningAmber,
                        isSelected: activeFilter == 'warning',
                        onTap: () {
                          ref.read(selectedStockoutFilterProvider.notifier).state =
                              activeFilter == 'warning' ? 'all' : 'warning';
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StockStatusCard(
                        label: 'Aman (>7 hari)',
                        count: summary.safeCount,
                        color: AppTheme.successGreen,
                        isSelected: activeFilter == 'safe',
                        onTap: () {
                          ref.read(selectedStockoutFilterProvider.notifier).state =
                              activeFilter == 'safe' ? 'all' : 'safe';
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // AI Recommendation Banner
                _AiInsightBanner(text: summary.aiRecommendation),

                const SizedBox(height: 20),

                // Header List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimasi Runout Bahan (${items.length})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimaryDark,
                      ),
                    ),
                    if (activeFilter != 'all')
                      InkWell(
                        onTap: () => ref.read(selectedStockoutFilterProvider.notifier).state = 'all',
                        child: Text(
                          'Tampilkan Semua',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.jadeTosca,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (items.isEmpty)
                  const EmptyStateView(
                    message: 'Tidak ada bahan baku dalam kategori filter ini.',
                    icon: Icons.check_circle_outline_rounded,
                  )
                else
                  ...items.map((item) => _StockoutItemCard(item: item)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StockStatusCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StockStatusCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.darkCardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.darkCardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMutedDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$count Item',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isSelected ? color : AppTheme.textPrimaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockoutItemCard extends StatelessWidget {
  final StockoutItem item;

  const _StockoutItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isCritical
        ? AppTheme.dangerRed
        : item.isWarning
            ? AppTheme.warningAmber
            : AppTheme.successGreen;

    final statusText = item.daysUntilStockout <= 0
        ? 'Habis Hari Ini!'
        : item.daysUntilStockout == 1
            ? 'Habis Besok'
            : 'Habis dlm ${item.daysUntilStockout} hari';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Nama Bahan & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ingredientName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Cabang: ${item.outletName}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMutedDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Indikator Kecepatan Penjualan (Velocity) & Sisa Stok
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stok: ${item.currentStock} ${item.unit} (Min: ${item.reorderLevel})',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                ),
                Text(
                  'Laju: ~${item.dailyVelocity} ${item.unit}/hari',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.jadeTosca, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Progress Bar Kapasitas
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.stockCapacityPct / 100.0).clamp(0.0, 1.0),
                backgroundColor: AppTheme.darkCardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.darkCardBorder),
            const SizedBox(height: 10),

            // Footer: Rekomendasi Restock & Tanggal Proyeksi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimasi Tanggal Habis:',
                        style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMutedDark),
                      ),
                      Text(
                        item.projectedStockoutDate,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rekomendasi Restock:',
                      style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMutedDark),
                    ),
                    Text(
                      '+${item.recommendedReorderQty} ${item.unit} (${item.formattedRestockCost})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.jadeTosca,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
