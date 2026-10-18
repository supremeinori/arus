import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import 'sensor_provider.dart';

class ShakeSettingsSheet extends ConsumerWidget {
  const ShakeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ShakeSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(shakeThresholdProvider);
    final settingsAsync = ref.watch(sensorSettingsProvider);
    final liveForce = ref.watch(lastShakeForceProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkCardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.vibration_rounded,
                    color: AppTheme.jadeTosca,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensitivitas Guncangan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDark,
                        ),
                      ),
                      Text(
                        'Atur ambang batas kekuatan Shake-to-Refresh',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Toggle Aktif / Nonaktif (aturan E24: via AsyncStateView,
            // bukan `settingsAsync.value?.x ?? default` yang diam saat loading).
            AsyncStateView(
              value: settingsAsync,
              loadingMessage: 'Memuat pengaturan shake...',
              onRetry: () => ref.refresh(sensorSettingsProvider),
              dataBuilder: (settings) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Fitur Shake-to-Refresh Aktif',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  'Segarkan data otomatis saat ponsel diguncangkan',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppTheme.textMuted,
                  ),
                ),
                activeThumbColor: AppTheme.jadeTosca,
                value: settings.shakeRefreshEnabled,
                onChanged: (val) {
                  ref
                      .read(sensorSettingsProvider.notifier)
                      .toggleShakeRefresh(val);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Pilihan Cepat (Presets)
            Text(
              'Pilihan Kekuatan Guncangan:',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ShakeSensitivityLevel.values.map((preset) {
                final isSelected = (threshold - preset.threshold).abs() < 0.3;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () {
                        ref
                            .read(shakeThresholdProvider.notifier)
                            .setPreset(preset);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.jadeTosca
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.jadeTosca
                                : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              preset.label,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preset.threshold.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isSelected
                                    ? Colors.white70
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Slider Penyesuaian Halus
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ambang Batas Custom:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${threshold.toStringAsFixed(1)} m/s²',
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
            Slider(
              value: threshold.clamp(3.0, 16.0),
              min: 3.0,
              max: 16.0,
              divisions: 26,
              activeColor: AppTheme.jadeTosca,
              label: '${threshold.toStringAsFixed(1)} m/s²',
              onChanged: (val) {
                ref.read(shakeThresholdProvider.notifier).setThreshold(val);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kecil / Sangat Peka (3.0)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  'Besar / Kuat (16.0)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Shake Diagnostic Gauge Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        size: 18,
                        color: AppTheme.textPrimaryDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uji Guncangan Langsung (Realtime)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Goyangkan HP Anda sekarang untuk menguji apakah kekuatan guncangan melampaui target ${threshold.toStringAsFixed(1)} m/s².',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Gauge bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (liveForce / 16.0).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        liveForce >= threshold
                            ? Colors.green.shade600
                            : Colors.amber.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kekuatan Terakhir: ${liveForce.toStringAsFixed(1)} m/s²',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: liveForce >= threshold
                              ? Colors.green.shade700
                              : AppTheme.textPrimaryDark,
                        ),
                      ),
                      if (liveForce > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: liveForce >= threshold
                                ? Colors.green.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: liveForce >= threshold
                                  ? Colors.green.shade300
                                  : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            liveForce >= threshold
                                ? '✅ Lolos Threshold'
                                : '⚠️ Kurang Kuat',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: liveForce >= threshold
                                  ? Colors.green.shade700
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tombol Simulasi Manual & Simpan
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () {
                      ref.read(shakeEventProvider.notifier).triggerShake();
                    },
                    leading: const Icon(Icons.touch_app_rounded, size: 16),
                    child: Text(
                      'Tes Getar',
                      style: GoogleFonts.inter(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShadButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Simpan & Tutup',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
