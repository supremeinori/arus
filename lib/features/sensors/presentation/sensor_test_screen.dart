import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
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
                _lastAuthResultText = 'Autentikasi ${type == BiometricAuthType.fingerprint ? "Sidik Jari" : "Wajah"} Berhasil! Akses Diberikan.';
                _lastAuthResultColor = Colors.green;
              } else if (result.status == BiometricResultStatus.failed) {
                _lastAuthResultText = 'Autentikasi Gagal: Identitas biometrik tidak cocok.';
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

    final settings = settingsAsync.value ?? UserSettingsModel.defaultSettings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostik Sensor & Biometrik'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Status
          _buildStatusOverview(settings),
          const SizedBox(height: 20),

          // SECTION 1: Accelerometer Telemetry
          _buildSectionHeader(
            icon: Icons.speed_rounded,
            title: 'Telemetri Akselerometer (G-Force)',
            subtitle: 'Deteksi gaya dorong & gravitasi pada 3 sumbu fisik',
          ),
          const SizedBox(height: 12),
          _buildAccelerometerCard(accel),
          const SizedBox(height: 20),

          // SECTION 2: Gyroscope & Spirit Bubble Level
          _buildSectionHeader(
            icon: Icons.screen_rotation_rounded,
            title: 'Giroskop & Level Kemiringan (Tilt)',
            subtitle: 'Visualisasi sudut rotasi Pitch, Roll, dan orientasi layar',
          ),
          const SizedBox(height: 12),
          _buildGyroscopeCard(gyro),
          const SizedBox(height: 20),

          // SECTION 3: Shake-to-Refresh Diagnostic
          _buildSectionHeader(
            icon: Icons.vibration_rounded,
            title: 'Diagnostik Guncangan (Shake-to-Refresh)',
            subtitle: 'Picu pembaruan data KPI dashboard saat perangkat diguncang',
          ),
          const SizedBox(height: 12),
          _buildShakeCard(settings, threshold, lastShake),
          const SizedBox(height: 20),

          // SECTION 4: Biometric Authentication Diagnostic
          _buildSectionHeader(
            icon: Icons.fingerprint_rounded,
            title: 'Diagnostik Autentikasi Biometrik',
            subtitle: 'Simulasi sensor sidik jari & pemindai wajah (Face ID)',
          ),
          const SizedBox(height: 12),
          _buildBiometricCard(settings),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusOverview(UserSettingsModel settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors_rounded, color: AppTheme.primaryBlue, size: 22),
              SizedBox(width: 8),
              Text(
                'Status Sensor Hardware ARUS',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusPill(
                label: 'Biometrik',
                isActive: settings.biometricEnabled,
                icon: Icons.fingerprint,
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
                label: 'Shake-Refresh',
                isActive: settings.shakeRefreshEnabled,
                icon: Icons.vibration,
              ),
              const SizedBox(width: 8),
              _buildStatusPill(
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

  Widget _buildStatusPill({required String label, required bool isActive, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.green.shade300 : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.green.shade700 : Colors.grey.shade600),
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
                fontSize: 10,
                color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildAccelerometerCard(AccelerometerReading accel) {
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
                const Text('Akselerasi Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${accel.totalAcceleration.toStringAsFixed(2)} m/s²',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAxisBar('Sumbu X (Lateral)', accel.x, Colors.red),
            const SizedBox(height: 8),
            _buildAxisBar('Sumbu Y (Longitudinal)', accel.y, Colors.green),
            const SizedBox(height: 8),
            _buildAxisBar('Sumbu Z (Vertikal / Gravitasi)', accel.z, Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAxisBar(String label, double value, Color color) {
    final clampedProgress = ((value + 20.0) / 40.0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)} m/s²',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
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

  Widget _buildGyroscopeCard(GyroscopeReading gyro) {
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
                    Text('Pitch (Kemiringan Depan/Belakang): ${gyro.pitch.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Roll (Kemiringan Kiri/Kanan): ${gyro.roll.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Yaw (Kompas Rotasi): ${gyro.yaw.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Simulasi Sudut Kemiringan (Tilt Test):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
              label: const Text('Reset Posisi Datar', style: TextStyle(fontSize: 12)),
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

  Widget _buildShakeCard(UserSettingsModel settings, double threshold, DateTime? lastShake) {
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
              title: const Text('Aktifkan Shake-to-Refresh di Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Guncang ponsel untuk menyegarkan data KPI secara otomatis.', style: TextStyle(fontSize: 12)),
              value: settings.shakeRefreshEnabled,
              onChanged: (val) {
                ref.read(sensorSettingsProvider.notifier).toggleShakeRefresh(val);
              },
            ),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sensitivitas Ambang Guncangan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${threshold.toStringAsFixed(1)} m/s²', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ],
            ),
            Slider(
              value: threshold.clamp(8.0, 20.0),
              min: 8.0,
              max: 20.0,
              divisions: 12,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ref.read(shakeEventProvider.notifier).triggerShake();
                },
              ),
            ),
            if (lastShake != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.deepPurple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guncangan Terdeteksi pada ${lastShake.hour.toString().padLeft(2, '0')}:${lastShake.minute.toString().padLeft(2, '0')}:${lastShake.second.toString().padLeft(2, '0')}! (Event disalurkan ke Dashboard)',
                        style: const TextStyle(fontSize: 12, color: Colors.deepPurple, fontWeight: FontWeight.w500),
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

  Widget _buildBiometricCard(UserSettingsModel settings) {
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
              title: const Text('Aktifkan Autentikasi Biometrik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Gunakan sidik jari atau Face ID untuk login kilat dan konfirmasi transaksi void.', style: TextStyle(fontSize: 12)),
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
                    icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue),
                    label: const Text('Uji Sidik Jari', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showBiometricModal(BiometricAuthType.fingerprint),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.face_rounded, color: Colors.indigo),
                    label: const Text('Uji Face ID', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showBiometricModal(BiometricAuthType.face),
                  ),
                ),
              ],
            ),
            if (_lastAuthResultText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _lastAuthResultColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _lastAuthResultColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastAuthResultColor == Colors.green ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: _lastAuthResultColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastAuthResultText!,
                        style: TextStyle(fontSize: 12, color: _lastAuthResultColor, fontWeight: FontWeight.bold),
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
            isFingerprint ? Icons.fingerprint_rounded : Icons.face_retouching_natural_rounded,
            size: 64,
            color: isFingerprint ? AppTheme.primaryBlue : Colors.indigo,
          ),
          const SizedBox(height: 16),
          Text(
            isFingerprint ? 'Autentikasi Sidik Jari' : 'Pemindaian Wajah (Face ID)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            isFingerprint
                ? 'Sentuhkan jari Anda pada sensor biometrik untuk memverifikasi identitas kasir / owner.'
                : 'Posisikan wajah Anda tepat di depan kamera depan perangkat.',
            textAlign: TextAlign.center,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    onResult(BiometricAuthResult(
                      status: BiometricResultStatus.success,
                      authType: authType,
                      message: 'Berhasil diverifikasi',
                    ));
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    onResult(BiometricAuthResult(
                      status: BiometricResultStatus.failed,
                      authType: authType,
                      message: 'Identitas tidak cocok',
                    ));
                  },
                  child: const Text('Simulasi Gagal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              onResult(BiometricAuthResult(
                status: BiometricResultStatus.canceled,
                authType: authType,
              ));
            },
            child: const Text('Batal / Gunakan Password', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
