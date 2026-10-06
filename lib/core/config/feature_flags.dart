/// Feature Flags sesuai SRS Section 23.3
/// Menjamin supporting features tidak merusak core chain (Gate G1 / T-CORE-01)
class FeatureFlags {
  // Client-side features
  final bool lbs;
  final bool sensors;
  final bool biometric;

  // Server-synced features (diambil dari GET /auth/me saat login)
  final bool integrity;
  final bool notifications;
  final bool fx;
  final bool game;
  final bool ai;

  const FeatureFlags({
    this.lbs = true,
    this.sensors = true,
    this.biometric = true,
    this.integrity = true,
    this.notifications = true,
    this.fx = true,
    this.game = true,
    this.ai = true,
  });

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      lbs: json['lbs'] as bool? ?? true,
      sensors: json['sensors'] as bool? ?? true,
      biometric: json['biometric'] as bool? ?? true,
      integrity: json['integrity'] as bool? ?? true,
      notifications: json['notifications'] as bool? ?? true,
      fx: json['fx'] as bool? ?? true,
      game: json['game'] as bool? ?? true,
      ai: json['ai'] as bool? ?? true,
    );
  }

  /// Preset untuk verifikasi Gate G1 / T-CORE-01 (semua supporting feature dimatikan)
  static const FeatureFlags coreOnly = FeatureFlags(
    lbs: false,
    sensors: false,
    biometric: false,
    integrity: false,
    notifications: false,
    fx: false,
    game: false,
    ai: false,
  );
}
