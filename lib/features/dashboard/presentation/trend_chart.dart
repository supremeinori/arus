import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/domain/analytics_models.dart';

/// Grafik tren omset 7 hari. Batang puncak disorot, dan ketuk batang
/// untuk melihat detail hari tersebut.
class TrendChart extends StatefulWidget {
  final List<SalesTrendPoint> points;

  const TrendChart({super.key, required this.points});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selected;

  // Nama hari dan bulan ditulis manual agar tidak bergantung pada initializeDateFormatting.
  static const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  DateTime? _parse(String date) {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  String _dayLabel(String date) {
    final d = _parse(date);
    return d == null ? date : _dayNames[d.weekday - 1];
  }

  String _dateLabel(String date) {
    final d = _parse(date);
    return d == null ? date : '${d.day} ${_monthNames[d.month - 1]}';
  }

  String _rupiah(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) {
      return Text(
        'Belum ada data tren.',
        style: GoogleFonts.lexend(color: AppTheme.textMuted, fontSize: 13),
      );
    }

    final total = points.fold<int>(0, (sum, p) => sum + p.revenueIdr);
    final maxRevenue = points.fold<int>(0, (m, p) => p.revenueIdr > m ? p.revenueIdr : m);
    final peakIndex = maxRevenue > 0 ? points.indexWhere((p) => p.revenueIdr == maxRevenue) : -1;
    final active = _selected ?? (peakIndex >= 0 ? peakIndex : null);
    final activePoint = active != null ? points[active] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ringkasan total dan hari puncak
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total 7 hari terakhir',
                    style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rupiah(total),
                    style: GoogleFonts.lexend(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accentBlack,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            if (peakIndex >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.lightToskaBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Puncak: ${_dayLabel(points[peakIndex].date)}',
                  style: GoogleFonts.lexend(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkToska,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Batang grafik
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(points.length, (i) {
              final p = points[i];
              final isActive = i == active;
              final ratio = maxRevenue > 0
                  ? (p.revenueIdr / maxRevenue).clamp(0.06, 1.0).toDouble()
                  : 0.06;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = i),
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            alignment: Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: AppTheme.lightToskaBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: ratio),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => FractionallySizedBox(
                                heightFactor: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: isActive
                                        ? const LinearGradient(
                                            colors: [AppTheme.primaryToska, AppTheme.darkToska],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          )
                                        : null,
                                    color: isActive
                                        ? null
                                        : AppTheme.primaryToska.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dayLabel(p.date),
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive ? AppTheme.darkToska : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Detail hari yang dipilih
        if (activePoint != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.lightToskaBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryToska.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_dateLabel(activePoint.date)} • ${activePoint.count} transaksi',
                    style: GoogleFonts.lexend(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
                Text(
                  _rupiah(activePoint.revenueIdr),
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkToska,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
