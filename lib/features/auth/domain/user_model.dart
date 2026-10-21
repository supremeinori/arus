import '../../../core/utils/money_formatter.dart';
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timezone': timezone,
      'address': address,
    };
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
    this.displayCurrency = MoneyFormatter.defaultCurrency,
    this.displayTimezone = 'Asia/Jakarta',
    this.biometricEnabled = false,
    this.shakeRefreshEnabled = true,
    this.tiltEnabled = true,
    this.dailyRevenueTargetIdr,
  });

  factory UserSettingsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserSettingsSummary();
    return UserSettingsSummary(
      displayCurrency:
          json['display_currency'] as String? ?? MoneyFormatter.defaultCurrency,
      displayTimezone: json['display_timezone'] as String? ?? 'Asia/Jakarta',
      biometricEnabled: json['biometric_enabled'] as bool? ?? false,
      shakeRefreshEnabled: json['shake_refresh_enabled'] as bool? ?? true,
      tiltEnabled: json['tilt_enabled'] as bool? ?? true,
      dailyRevenueTargetIdr: json['daily_revenue_target_idr'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_currency': displayCurrency,
      'display_timezone': displayTimezone,
      'biometric_enabled': biometricEnabled,
      'shake_refresh_enabled': shakeRefreshEnabled,
      'tilt_enabled': tiltEnabled,
      'daily_revenue_target_idr': dailyRevenueTargetIdr,
    };
  }

  UserSettingsSummary copyWith({
    String? displayCurrency,
    String? displayTimezone,
    bool? biometricEnabled,
    bool? shakeRefreshEnabled,
    bool? tiltEnabled,
    int? dailyRevenueTargetIdr,
  }) {
    return UserSettingsSummary(
      displayCurrency: displayCurrency ?? this.displayCurrency,
      displayTimezone: displayTimezone ?? this.displayTimezone,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      shakeRefreshEnabled: shakeRefreshEnabled ?? this.shakeRefreshEnabled,
      tiltEnabled: tiltEnabled ?? this.tiltEnabled,
      dailyRevenueTargetIdr: dailyRevenueTargetIdr ?? this.dailyRevenueTargetIdr,
    );
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final List<OutletSummary> outlets;
  final UserSettingsSummary settings;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.outlets = const [],
    this.settings = const UserSettingsSummary(),
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? avatarUrl,
    List<OutletSummary>? outlets,
    UserSettingsSummary? settings,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      outlets: outlets ?? this.outlets,
      settings: settings ?? this.settings,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawOutlets = json['outlets'] as List<dynamic>? ?? [];
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'staff'),
      avatarUrl: json['avatar_url'] as String?,
      outlets: rawOutlets
          .map((o) => OutletSummary.fromJson(o as Map<String, dynamic>))
          .toList(),
      settings: UserSettingsSummary.fromJson(json['settings'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'avatar_url': avatarUrl,
      'outlets': outlets.map((o) => o.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }
}

