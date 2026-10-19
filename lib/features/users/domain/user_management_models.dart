import 'package:flutter/material.dart';
import '../../auth/domain/user_model.dart';

class ManagedUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String outletId;
  final String outletName;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  const ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.outletId,
    required this.outletName,
    this.phone,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
  });

  String get roleDisplay {
    switch (role) {
      case UserRole.owner:
        return 'Owner (Pemilik)';
      case UserRole.manager:
        return 'Manager (Kepala Cabang)';
      case UserRole.staff:
        return 'Kasir (Staff)';
    }
  }

  Color get roleColor {
    switch (role) {
      case UserRole.owner:
        return const Color(0xFF2563EB); // Royal Blue
      case UserRole.manager:
        return const Color(0xFFD97706); // Warm Amber
      case UserRole.staff:
        return const Color(0xFF0F766E); // Teal / Jade
    }
  }

  String get initials {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  ManagedUser copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? outletId,
    String? outletName,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return ManagedUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      outletId: outletId ?? this.outletId,
      outletName: outletName ?? this.outletName,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  factory ManagedUser.fromJson(Map<String, dynamic> json) {
    return ManagedUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'staff'),
      outletId: json['outlet_id'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? '',
      phone: json['phone'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'outlet_id': outletId,
      'outlet_name': outletName,
      'phone': phone,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}

/// Standar Outlet Item untuk Dropdown Assignment
class AssignedOutletItem {
  final String id;
  final String name;
  final String address;

  const AssignedOutletItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory AssignedOutletItem.fromJson(Map<String, dynamic> json) {
    return AssignedOutletItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
  };
}

/// Pre-seeded default users
final List<ManagedUser> defaultManagedUsers = [
  ManagedUser(
    id: 'u-owner-001',
    name: 'Rina Kartika',
    email: 'owner@arus.demo',
    role: UserRole.owner,
    outletId: 'all',
    outletName: 'Semua Cabang (HQ)',
    phone: '081234567890',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
    lastLogin: DateTime.now(),
  ),
  ManagedUser(
    id: 'u-mgr-001',
    name: 'Budi Santoso',
    email: 'manager@arus.demo',
    role: UserRole.manager,
    outletId: 'out-sudirman',
    outletName: 'Kopi Arus - Sudirman (HQ)',
    phone: '081298765432',
    isActive: true,
    createdAt: DateTime(2026, 1, 15),
    lastLogin: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  ManagedUser(
    id: 'u-mgr-002',
    name: 'Hendra Wijaya',
    email: 'hendra@arus.demo',
    role: UserRole.manager,
    outletId: 'out-senopati',
    outletName: 'Kopi Arus - Senopati',
    phone: '081345678901',
    isActive: true,
    createdAt: DateTime(2026, 2, 1),
    lastLogin: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  ManagedUser(
    id: 'u-staff-001',
    name: 'Siti Rahma',
    email: 'staff@arus.demo',
    role: UserRole.staff,
    outletId: 'out-sudirman',
    outletName: 'Kopi Arus - Sudirman (HQ)',
    phone: '081567890123',
    isActive: true,
    createdAt: DateTime(2026, 2, 10),
    lastLogin: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  ManagedUser(
    id: 'u-staff-002',
    name: 'Dimas Pratama',
    email: 'dimas@arus.demo',
    role: UserRole.staff,
    outletId: 'out-sudirman',
    outletName: 'Kopi Arus - Sudirman (HQ)',
    phone: '081678901234',
    isActive: true,
    createdAt: DateTime(2026, 2, 15),
    lastLogin: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  ManagedUser(
    id: 'u-staff-003',
    name: 'Ahmad Fauzi',
    email: 'fauzi@arus.demo',
    role: UserRole.staff,
    outletId: 'out-senopati',
    outletName: 'Kopi Arus - Senopati',
    phone: '081789012345',
    isActive: true,
    createdAt: DateTime(2026, 2, 20),
    lastLogin: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  ManagedUser(
    id: 'u-staff-004',
    name: 'Nabila Putri',
    email: 'nabila@arus.demo',
    role: UserRole.staff,
    outletId: 'out-senopati',
    outletName: 'Kopi Arus - Senopati',
    phone: '081890123456',
    isActive: true,
    createdAt: DateTime(2026, 3, 1),
    lastLogin: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

/// Standar Outlet Bawaan Aplikasi
final List<AssignedOutletItem> defaultAvailableOutlets = [
  const AssignedOutletItem(
    id: 'out-sudirman',
    name: 'Kopi Arus - Sudirman (HQ)',
    address: 'Jl. Jend. Sudirman Kav. 21, Jakarta Pusat',
  ),
  const AssignedOutletItem(
    id: 'out-senopati',
    name: 'Kopi Arus - Senopati',
    address: 'Jl. Senopati No. 88, Kebayoran Baru, Jakarta Selatan',
  ),
  const AssignedOutletItem(
    id: 'out-bsd',
    name: 'Kopi Arus - BSD Serpong',
    address: 'Ruko Digital Hub No. 12, BSD City, Tangerang',
  ),
  const AssignedOutletItem(
    id: 'out-jogja',
    name: 'ARUS Jogja Malioboro',
    address: 'Jl. Malioboro No. 45, Yogyakarta',
  ),
];
