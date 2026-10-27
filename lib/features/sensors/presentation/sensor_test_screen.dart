import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../domain/sensor_models.dart';
import 'sensor_provider.dart';

class SensorTestScreen extends ConsumerStatefulWidget {
  const SensorTestScreen({super.key});

  @override
  ConsumerState<SensorTestScreen> createState() => _SensorTestScreenState();
}

class _SensorTestScreenState extends ConsumerState<SensorTestScreen> {
  String? _lastAuthResultText;
  Color _lastAuthResultColor = Colors.grey;

  void _showBiometricModal(BiometricAuthType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return _BiometricSimulationModal(
          authType: type,
          onResult: (result) {
            Navigator.of(modalContext).pop();
            setState(() {
              if (result.isSuccess) {
                _lastAuthResultText =
                    'Autentikasi ${type == BiometricAuthType.fingerprint ? "Sidik Jari" : "Wajah"} Berhasil! Akses Diberikan.';
                _lastAuthResultColor = Colors.green;
              } else if (result.status == BiometricResultStatus.failed) {
                _lastAuthResultText =
                    'Autentikasi Gagal: Identitas biometrik tidak cocok.';
                _lastAuthResultColor = Colors.red;
              } else {
                _lastAuthResultText = 'Autentikasi Dibatalkan oleh Pengguna.';
                _lastAuthResultColor = Colors.orange;
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accel = ref.watch(accelerometerProvider);
    final gyro = ref.watch(gyroscopeProvider);
    final settingsAsync = ref.watch(sensorSettingsProvider);
    final lastShake = ref.watch(shakeEventProvider);
    final threshold = ref.watch(shakeThresholdProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Diagnostik Sensor & Biometrik'),
      ),
      // Aturan E24: status settings dirender lewat AsyncStateView
      // (loading/error) — bukan silent fallback `.value ?? default`.
      body: AsyncStateView<UserSettingsModel>(
        value: settingsAsync,
        loadingMessage: 'Memuat pengaturan sensor...',
        onRetry: () => ref.refresh(sensorSettingsProvider),
        dataBuilder: (settings) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Status
            _SensorStatusOverview(settings: settings),
            const SizedBox(height: 20),

            // SECTION 1: Accelerometer Telemetry
            const _SensorSectionHeader(
              icon: Icons.speed_rounded,
              title: 'Telemetri Akselerometer (G-Force)',
              subtitle: 'Deteksi gaya dorong & gravitasi pada 3 sumbu fisik',
            ),
            const SizedBox(height: 12),
            _AccelerometerCard(accel: accel),
            const SizedBox(height: 20),

            // SECTION 2: Gyroscope & Spirit Bubble Level
            const _SensorSectionHeader(
              icon: Icons.screen_rotation_rounded,
              title: 'Giroskop & Level Kemiringan (Tilt)',
              subtitle:
                  'Visualisasi sudut rotasi Pitch, Roll, dan orientasi layar',
            ),
            const SizedBox(height: 12),
            _GyroscopeCard(gyro: gyro),
            const SizedBox(height: 20),

            // SECTION 3: Shake-to-Refresh Diagnostic
            const _SensorSectionHeader(
              icon: Icons.vibration_rounded,
              title: 'Diagnostik Guncangan (Shake-to-Refresh)',
              subtitle:
                  'Picu pembaruan data KPI dashboard saat perangkat diguncang',
            ),
            const SizedBox(height: 12),
            _ShakeDiagnosticCard(
              settings: settings,
              threshold: threshold,
              lastShake: lastShake,
            ),
            const SizedBox(height: 20),

            // SECTION 4: Biometric Authentication Diagnostic
            const _SensorSectionHeader(
              icon: Icons.fingerprint_rounded,
              title: 'Diagnostik Autentikasi Biometrik',
              subtitle: 'Simulasi sensor sidik jari & pemindai wajah (Face ID)',
            ),
            const SizedBox(height: 12),
            _BiometricDiagnosticCard(
              settings: settings,
              lastAuthResultText: _lastAuthResultText,
              lastAuthResultColor: _lastAuthResultColor,
              onTestFingerprint: () =>
                  _showBiometricModal(BiometricAuthType.fingerprint),
              onTestFace: () => _showBiometricModal(BiometricAuthType.face),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Banner status hardware sensor (aturan E23: widget class const).
class _SensorStatusOverview extends StatelessWidget {
  final UserSettingsModel settings;
  const _SensorStatusOverview({required this.settings});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.jadeTosca.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.jadeTosca.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.sensors_rounded,
                color: AppTheme.jadeTosca,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Status Sensor Hardware ARUS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.jadeTosca,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SensorStatusPill(
                label: 'Biometrik',
                isActive: settings.biometricEnabled,
                icon: Icons.fingerprint,
              ),
              const SizedBox(width: 8),
              _SensorStatusPill(
                label: 'Shake-Refresh',
                isActive: settings.shakeRefreshEnabled,
                icon: Icons.vibration,
              ),
              const SizedBox(width: 8),
              _SensorStatusPill(
                label: 'Tilt UI',
                isActive: settings.tiltEnabled,
                icon: Icons.screen_rotation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pil status sensor (aturan E23: widget class const).
class _SensorStatusPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData icon;
  const _SensorStatusPill({
    required this.label,
    required this.isActive,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.green.shade300 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.green.shade800 : Colors.grey.shade700,
              ),
            ),
            Text(
              isActive ? 'Aktif' : 'Nonaktif',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header section diagnostik (aturan E23: widget class const).
class _SensorSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SensorSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.jadeTosca),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// Kartu telemetri akselerometer (aturan E23: widget class const).
class _AccelerometerCard extends StatelessWidget {
  final AccelerometerReading accel;
  const _AccelerometerCard({required this.accel});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Akselerasi Total:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${accel.totalAcceleration.toStringAsFixed(2)} m/s²',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.jadeTosca,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AxisBar('Sumbu X (Lateral)', accel.x, Colors.red),
            const SizedBox(height: 8),
            _AxisBar('Sumbu Y (Longitudinal)', accel.y, Colors.green),
            const SizedBox(height: 8),
            _AxisBar('Sumbu Z (Vertikal / Gravitasi)', accel.z, Colors.blue),
          ],
        ),
      ),
    );
  }
}

/// Bar sumbu akselerometer (aturan E23: widget class const).
class _AxisBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _AxisBar(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    final clampedProgress = ((value + 20.0) / 40.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)} m/s²',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: clampedProgress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

/// Kartu giroskop & bubble level (aturan E23: widget class const,
/// state dibaca via provider di dalam build agar tidak stale).
class _GyroscopeCard extends ConsumerWidget {
  final GyroscopeReading gyro;
  const _GyroscopeCard({required this.gyro});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simulasi bubble level
    // Roll (-90 to +90) menggerakkan bubble ke kiri/kanan (-30 to +30 px)
    // Pitch (-90 to +90) menggerakkan bubble ke atas/bawah (-30 to +30 px)
    final bubbleOffsetX = (gyro.roll / 90.0 * 30.0).clamp(-30.0, 30.0);
    final bubbleOffsetY = (gyro.pitch / 90.0 * 30.0).clamp(-30.0, 30.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Spirit Bubble Level Circular Gauge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.teal.shade50,
                    border: Border.all(color: Colors.teal.shade300, width: 2),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Garis sumbu tengah
                      Divider(color: Colors.teal.shade200, height: 1),
                      VerticalDivider(color: Colors.teal.shade200, width: 1),
                      // Bubble widget
                      Transform.translate(
                        offset: Offset(bubbleOffsetX, bubbleOffsetY),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.teal.shade600,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withAlpha(80),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pitch (Kemiringan Depan/Belakang): ${gyro.pitch.toStringAsFixed(1)}°',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Roll (Kemiringan Kiri/Kanan): ${gyro.roll.toStringAsFixed(1)}°',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yaw (Kompas Rotasi): ${gyro.yaw.toStringAsFixed(1)}°',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Simulasi Sudut Kemiringan (Tilt Test):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                const Text('Pitch', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: gyro.pitch.clamp(-90.0, 90.0),
                    min: -90.0,
                    max: 90.0,
                    divisions: 36,
                    label: '${gyro.pitch.round()}°',
                    onChanged: (val) {
                      ref.read(gyroscopeProvider.notifier).setTilt(pitch: val);
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Roll ', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: gyro.roll.clamp(-90.0, 90.0),
                    min: -90.0,
                    max: 90.0,
                    divisions: 36,
                    label: '${gyro.roll.round()}°',
                    onChanged: (val) {
                      ref.read(gyroscopeProvider.notifier).setTilt(roll: val);
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text(
                  'Reset Posisi Datar',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () {
                  ref.read(gyroscopeProvider.notifier).reset();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu diagnostik shake-to-refresh (aturan E23: widget class const).
class _ShakeDiagnosticCard extends ConsumerWidget {
  final UserSettingsModel settings;
  final double threshold;
  final DateTime? lastShake;
  const _ShakeDiagnosticCard({
    required this.settings,
    required this.threshold,
    required this.lastShake,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aktifkan Shake-to-Refresh di Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Guncang ponsel untuk menyegarkan data KPI secara otomatis.',
                style: TextStyle(fontSize: 12),
              ),
              value: settings.shakeRefreshEnabled,
              onChanged: (val) {
                ref
                    .read(sensorSettingsProvider.notifier)
                    .toggleShakeRefresh(val);
              },
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sensitivitas Ambang Guncangan:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${threshold.toStringAsFixed(1)} m/s²',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: ShakeSensitivityLevel.values.map((preset) {
                final isSelected = (threshold - preset.threshold).abs() < 0.3;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        backgroundColor: isSelected
                            ? Colors.deepPurple
                            : Colors.transparent,
                        foregroundColor: isSelected
                            ? Colors.white
                            : Colors.deepPurple,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.deepPurple.shade200,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(shakeThresholdProvider.notifier)
                            .setPreset(preset);
                      },
                      child: Text(
                        preset.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Slider(
              value: threshold.clamp(3.0, 16.0),
              min: 3.0,
              max: 16.0,
              divisions: 26,
              label: '${threshold.toStringAsFixed(1)} m/s²',
              onChanged: (val) {
                ref.read(shakeThresholdProvider.notifier).state = val;
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.vibration_rounded),
                label: const Text('Simulasikan Guncangan (Shake Device)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  ref.read(shakeEventProvider.notifier).triggerShake();
                },
              ),
            ),
            if (lastShake != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final shake = lastShake;
                  if (shake == null) return const SizedBox.shrink();
                  return _ShakeDetectedBanner(lastShake: shake);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu diagnostik biometrik (aturan E23: widget class const).
class _BiometricDiagnosticCard extends ConsumerWidget {
  final UserSettingsModel settings;
  final String? lastAuthResultText;
  final Color lastAuthResultColor;
  final VoidCallback onTestFingerprint;
  final VoidCallback onTestFace;
  const _BiometricDiagnosticCard({
    required this.settings,
    required this.lastAuthResultText,
    required this.lastAuthResultColor,
    required this.onTestFingerprint,
    required this.onTestFace,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aktifkan Autentikasi Biometrik',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Gunakan sidik jari atau Face ID untuk login kilat dan konfirmasi transaksi void.',
                style: TextStyle(fontSize: 12),
              ),
              value: settings.biometricEnabled,
              onChanged: (val) {
                ref.read(sensorSettingsProvider.notifier).toggleBiometric(val);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text(
                      'Uji Sidik Jari',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => onTestFingerprint(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.face_rounded),
                    label: const Text(
                      'Uji Face ID',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () => onTestFace(),
                  ),
                ),
              ],
            ),
            if (lastAuthResultText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lastAuthResultColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lastAuthResultColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      lastAuthResultColor == Colors.green
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: lastAuthResultColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastAuthResultText!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: lastAuthResultColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner waktu guncangan terakhir (promosi non-null agar analyzer
/// tidak komplain pada field `lastShake` yang nullable).
class _ShakeDetectedBanner extends StatelessWidget {
  final DateTime lastShake;

  const _ShakeDetectedBanner({required this.lastShake});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.deepPurple,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Guncangan Terdeteksi pada ${lastShake.hour.toString().padLeft(2, '0')}:${lastShake.minute.toString().padLeft(2, '0')}:${lastShake.second.toString().padLeft(2, '0')}! (Event disalurkan ke Dashboard)',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricSimulationModal extends StatelessWidget {
  final BiometricAuthType authType;
  final ValueChanged<BiometricAuthResult> onResult;

  const _BiometricSimulationModal({
    required this.authType,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final isFingerprint = authType == BiometricAuthType.fingerprint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            isFingerprint
                ? Icons.fingerprint_rounded
                : Icons.face_retouching_natural_rounded,
            size: 64,
            color: isFingerprint ? AppTheme.jadeTosca : Colors.indigo,
          ),
          const SizedBox(height: 16),
          Text(
            isFingerprint
                ? 'Autentikasi Sidik Jari'
                : 'Pemindaian Wajah (Face ID)',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            isFingerprint
                ? 'Sentuhkan jari Anda pada sensor biometrik untuk memverifikasi identitas kasir / owner.'
                : 'Posisikan wajah Anda tepat di depan kamera depan perangkat.',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    onResult(
                      BiometricAuthResult(
                        status: BiometricResultStatus.success,
                        authType: authType,
                        message: 'Berhasil diverifikasi',
                      ),
                    );
                  },
                  child: const Text('Simulasi Berhasil'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    onResult(
                      BiometricAuthResult(
                        status: BiometricResultStatus.failed,
                        authType: authType,
                        message: 'Identitas tidak cocok',
                      ),
                    );
                  },
                  child: const Text('Simulasi Gagal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              onResult(
                BiometricAuthResult(
                  status: BiometricResultStatus.canceled,
                  authType: authType,
                ),
              );
            },
            child: const Text(
              'Batal / Gunakan Password',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
