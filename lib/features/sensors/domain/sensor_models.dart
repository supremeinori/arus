import 'dart:math' as math;

class AccelerometerReading {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  const AccelerometerReading({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  double get totalAcceleration => math.sqrt(x * x + y * y + z * z);

  factory AccelerometerReading.zero() => AccelerometerReading(
        x: 0.0,
        y: 0.0,
        z: 9.8, // Standar gravitasi bumi (1G)
        timestamp: DateTime.now(),
      );

  AccelerometerReading copyWith({
    double? x,
    double? y,
    double? z,
    DateTime? timestamp,
  }) {
    return AccelerometerReading(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class GyroscopeReading {
  /// Derajat kemiringan depan/belakang (sumbu X). 0° saat HP dipegang tegak
  /// portrait, positif = ujung atas HP condong menjauh pengguna (miring atas).
  final double pitch;

  /// Derajat kemiringan kiri/kanan (sumbu Y). 0° saat HP dipegang tegak
  /// portrait, positif = tepi kanan HP turun (miring kanan).
  final double roll;

  /// Derajat rotasi sumbu Z (0 s/d 360).
  final double yaw;
  final DateTime timestamp;

  const GyroscopeReading({
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.timestamp,
  });

  factory GyroscopeReading.zero() => GyroscopeReading(
        pitch: 0.0,
        roll: 0.0,
        yaw: 0.0,
        timestamp: DateTime.now(),
      );

  GyroscopeReading copyWith({
    double? pitch,
    double? roll,
    double? yaw,
    DateTime? timestamp,
  }) {
    return GyroscopeReading(
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      yaw: yaw ?? this.yaw,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

enum BiometricAuthType {
  fingerprint,
  face,
  pin,
}

enum BiometricResultStatus {
  success,
  failed,
  canceled,
  notAvailable,
}

class BiometricAuthResult {
  final BiometricResultStatus status;
  final String? message;
  final BiometricAuthType authType;

  const BiometricAuthResult({
    required this.status,
    this.message,
    required this.authType,
  });

  bool get isSuccess => status == BiometricResultStatus.success;
}

class UserSettingsModel {
  final String userId;
  final String displayCurrency;
  final String displayTimezone;
  final bool biometricEnabled;
  final bool shakeRefreshEnabled;
  final bool tiltEnabled;
  final int? dailyRevenueTargetIdr;
  final DateTime? updatedAt;

  const UserSettingsModel({
    required this.userId,
    required this.displayCurrency,
    required this.displayTimezone,
    required this.biometricEnabled,
    required this.shakeRefreshEnabled,
    required this.tiltEnabled,
    this.dailyRevenueTargetIdr,
    this.updatedAt,
  });

  factory UserSettingsModel.defaultSettings({String userId = ''}) {
    return UserSettingsModel(
      userId: userId,
      displayCurrency: 'IDR',
      displayTimezone: 'Asia/Jakarta',
      biometricEnabled: false,
      shakeRefreshEnabled: true,
      tiltEnabled: true,
      dailyRevenueTargetIdr: null,
      updatedAt: DateTime.now(),
    );
  }

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      userId: json['user_id'] as String? ?? '',
      displayCurrency: json['display_currency'] as String? ?? 'IDR',
      displayTimezone: json['display_timezone'] as String? ?? 'Asia/Jakarta',
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      shakeRefreshEnabled: json['shake_refresh_enabled'] as bool? ?? true,
      tiltEnabled: json['tilt_enabled'] as bool? ?? true,
      dailyRevenueTargetIdr: json['daily_revenue_target_idr'] as int?,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_currency': displayCurrency,
      'display_timezone': displayTimezone,
      'biometric_enabled': biometricEnabled,
      'shake_refresh_enabled': shakeRefreshEnabled,
      'tilt_enabled': tiltEnabled,
      if (dailyRevenueTargetIdr != null) 'daily_revenue_target_idr': dailyRevenueTargetIdr,
    };
  }

  UserSettingsModel copyWith({
    String? userId,
    String? displayCurrency,
    String? displayTimezone,
    bool? biometricEnabled,
    bool? shakeRefreshEnabled,
    bool? tiltEnabled,
    int? dailyRevenueTargetIdr,
    DateTime? updatedAt,
  }) {
    return UserSettingsModel(
      userId: userId ?? this.userId,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      displayTimezone: displayTimezone ?? this.displayTimezone,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      shakeRefreshEnabled: shakeRefreshEnabled ?? this.shakeRefreshEnabled,
      tiltEnabled: tiltEnabled ?? this.tiltEnabled,
      dailyRevenueTargetIdr: dailyRevenueTargetIdr ?? this.dailyRevenueTargetIdr,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
