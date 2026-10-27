import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../features/analytics/presentation/analytics_provider.dart';

/// Satu sumber filter bisnis untuk Dashboard, Riwayat Transaksi, dan
/// Leaderboard: cabang (khusus Owner) + periode waktu (semua role).
/// Menulis langsung ke [selectedOutletFilterProvider],
/// [selectedDateFilterProvider], dan [selectedCustomDateProvider] sehingga
/// seluruh layar yang membaca provider tersebut ikut ter-refresh.
class DashboardFilterSheet extends ConsumerStatefulWidget {
  final List<({String id, String name})> outlets;
  final String? selectedOutletId;
  final DashboardDateFilter selectedDateFilter;
  final DateTime? selectedCustomDate;
  final bool isManager;
  final String ownerTitle;
  final String managerTitle;

  const DashboardFilterSheet({
    super.key,
    required this.outlets,
    required this.selectedOutletId,
    required this.selectedDateFilter,
    required this.selectedCustomDate,
    this.isManager = false,
    this.ownerTitle = 'Kotak Filter Bisnis',
    this.managerTitle = 'Filter Periode Waktu',
  });

  @override
  ConsumerState<DashboardFilterSheet> createState() => _DashboardFilterSheetState();
}

class _DashboardFilterSheetState extends ConsumerState<DashboardFilterSheet> {
  static const _teal = AppTheme.jadeTosca;
  static const _tealLight = AppTheme.toscaSurface;
  static const _textPrimary = AppTheme.textPrimaryLight;
  static const _textSecondary = AppTheme.textSecondaryMid;
  static const _textMuted = AppTheme.textMutedLight;
  static const _border = AppTheme.lightCardBorder;

  late String? _tempOutletId;
  late DashboardDateFilter _tempDateFilter;
  late DateTime? _tempCustomDate;

  @override
  void initState() {
    super.initState();
    if (widget.isManager) {
      _tempOutletId = widget.outlets.isNotEmpty
          ? widget.outlets.first.id
          : widget.selectedOutletId;
    } else {
      _tempOutletId = widget.selectedOutletId;
    }
    _tempDateFilter = widget.selectedDateFilter;
    _tempCustomDate = widget.selectedCustomDate;
  }

  Future<void> _pickCustomCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempCustomDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _teal,
              onPrimary: Colors.white,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tempCustomDate = picked);
    }
  }

  void _apply() {
    if (!widget.isManager) {
      ref.read(selectedOutletFilterProvider.notifier).state = _tempOutletId;
    } else if (widget.outlets.isNotEmpty) {
      ref.read(selectedOutletFilterProvider.notifier).state =
          widget.outlets.first.id;
    }
    ref.read(selectedDateFilterProvider.notifier).state = _tempDateFilter;
    ref.read(selectedCustomDateProvider.notifier).state = _tempCustomDate;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderMid,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 20, color: _teal),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.isManager
                            ? widget.managerTitle
                            : widget.ownerTitle,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: _textMuted,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 16),

          // Pemilihan cabang hanya untuk Owner; manager terkunci ke cabangnya.
          if (!widget.isManager) ...[
            Text(
              'PILIH CABANG OUTLET',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border, width: 1.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _tempOutletId,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _textMuted,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Semua Cabang',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                    ...widget.outlets.map(
                      (o) => DropdownMenuItem<String?>(
                        value: o.id,
                        child: Text(
                          o.name,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _tempOutletId = val),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],

          Text(
            'PILIH HARI / PERIODE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...DashboardDateFilter.values.map((filter) {
                final isSelected =
                    _tempCustomDate == null && _tempDateFilter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : _textPrimary,
                  ),
                  selected: isSelected,
                  selectedColor: _teal,
                  backgroundColor: AppTheme.lightBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? _teal : _border,
                      width: AppTheme.hairline,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _tempDateFilter = filter;
                        _tempCustomDate = null;
                      });
                    }
                  },
                );
              }),
              ActionChip(
                avatar: const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: _teal,
                ),
                label: Text(
                  _tempCustomDate != null
                      ? DateFormat('d MMM yyyy', 'id_ID').format(_tempCustomDate!)
                      : 'Pilih Tanggal...',
                ),
                labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      _tempCustomDate != null ? FontWeight.w700 : FontWeight.w500,
                  color: _tempCustomDate != null ? _teal : _textSecondary,
                ),
                backgroundColor: _tempCustomDate != null
                    ? _tealLight
                    : AppTheme.lightBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _tempCustomDate != null ? _teal : _border,
                    width: AppTheme.hairline,
                  ),
                ),
                onPressed: _pickCustomCalendarDate,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: _apply,
              child: Text(
                'Terapkan Filter',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Helper pembuka sheet filter — dipakai semua layar supaya konsisten.
Future<void> showDashboardFilterSheet(
  BuildContext context, {
  required List<({String id, String name})> outlets,
  required String? selectedOutletId,
  required DashboardDateFilter selectedDateFilter,
  required DateTime? selectedCustomDate,
  required bool isManager,
  String ownerTitle = 'Kotak Filter Bisnis',
  String managerTitle = 'Filter Periode Waktu',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DashboardFilterSheet(
      outlets: outlets,
      selectedOutletId: selectedOutletId,
      selectedDateFilter: selectedDateFilter,
      selectedCustomDate: selectedCustomDate,
      isManager: isManager,
      ownerTitle: ownerTitle,
      managerTitle: managerTitle,
    ),
  );
}
