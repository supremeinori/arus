enum UserRole {
  owner,
  manager,
  staff;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }

  String toDisplayString() {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.manager:
        return 'Manager';
      case UserRole.staff:
        return 'Kasir (Staff)';
    }
  }
}

class OutletSummary {
  final String id;
  final String name;
  final String timezone;
  final String? address;

  const OutletSummary({
    required this.id,
    required this.name,
    required this.timezone,
    this.address,
  });

  factory OutletSummary.fromJson(Map<String, dynamic> json) {
    return OutletSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'Asia/Jakarta',
      address: json['address'] as String?,
    );
  }
}

class UserSettingsSummary {
  final String displayCurrency;
  final String displayTimezone;
  final bool biometricEnabled;
  final bool shakeRefreshEnabled;
  final bool tiltEnabled;
  final int? dailyRevenueTargetIdr;

  const UserSettingsSummary({
    this.displayCurrency = 'IDR',
    this.displayTimezone = 'Asia/Jakarta',
    this.biometricEnabled = false,
    this.shakeRefreshEnabled = true,
    this.tiltEnabled = true,
    this.dailyRevenueTargetIdr,
  });

  factory UserSettingsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserSettingsSummary();
    return UserSettingsSummary(
      displayCurrency: json['display_currency'] as String? ?? 'IDR',
      displayTimezone: json['display_timezone'] as String? ?? 'Asia/Jakarta',
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      shakeRefreshEnabled: json['shake_refresh_enabled'] as bool? ?? true,
      tiltEnabled: json['tilt_enabled'] as bool? ?? true,
      dailyRevenueTargetIdr: json['daily_revenue_target_idr'] as int?,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final List<OutletSummary> outlets;
  final UserSettingsSummary settings;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.outlets = const [],
    this.settings = const UserSettingsSummary(),
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawOutlets = json['outlets'] as List<dynamic>? ?? [];
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'staff'),
      outlets: rawOutlets
          .map((o) => OutletSummary.fromJson(o as Map<String, dynamic>))
          .toList(),
      settings: UserSettingsSummary.fromJson(json['settings'] as Map<String, dynamic>?),
    );
  }
}
