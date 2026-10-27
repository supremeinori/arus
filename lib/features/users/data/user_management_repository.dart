import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/prefs_store.dart';
import '../../auth/domain/user_model.dart';
import '../domain/user_management_models.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((
  ref,
) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // SharedPreferences may be unavailable in tests.
  }

  return UserManagementRepository(ref.watch(apiClientProvider), prefs: prefs);
});

class UserManagementRepository {
  final ApiClient? _client;
  final SharedPreferences? _prefs;

  static const String _storageKey = 'arus_managed_users_v1';

  List<ManagedUser> _memoryUsers = [];
  bool _isInitialized = false;

  UserManagementRepository(this._client, {this._prefs});

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    final stored = _prefs?.getString(_storageKey);

    if (stored != null && stored.isNotEmpty) {
      try {
        final list = jsonDecode(stored) as List<dynamic>;
        _memoryUsers = list
            .map((item) => ManagedUser.fromJson(item as Map<String, dynamic>))
            .toList();
        _isInitialized = true;
        return;
      } catch (_) {
        // Fall back to default data.
      }
    }

    _memoryUsers = List<ManagedUser>.from(defaultManagedUsers);
    _isInitialized = true;
  }

  Future<void> _persist() async {
    final jsonList = _memoryUsers.map((user) => user.toJson()).toList();
    await _prefs?.setString(_storageKey, jsonEncode(jsonList));
  }

  Future<List<ManagedUser>> getUsers() async {
    final client = _client;

    if (client != null) {
      final response = await client.get<Map<String, dynamic>>('/users');
      final data = response.data?['data'] as List<dynamic>? ?? [];

      return data.map((item) {
        final json = item as Map<String, dynamic>;
        final outlets = json['outlets'] as List<dynamic>? ?? [];
        final outlet = outlets.isNotEmpty
            ? outlets.first as Map<String, dynamic>
            : <String, dynamic>{};

        return ManagedUser(
          id: json['id'] as String? ?? '',
          name: json['name'] as String? ?? '',
          email: json['email'] as String? ?? '',
          role: UserRole.fromString(json['role'] as String? ?? 'staff'),
          outletId: outlet['id'] as String? ?? '',
          outletName: outlet['name'] as String? ?? '',
          isActive: json['is_active'] as bool? ?? true,
          createdAt:
              DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
          lastLogin: null,
        );
      }).toList();
    }

    await _ensureInitialized();
    return List.unmodifiable(_memoryUsers);
  }

  Future<ManagedUser> createUser({
    required String name,
    required String email,
    required UserRole role,
    required String outletId,
    required String outletName,
    String? phone,
    String? password,
  }) async {
    final client = _client;

    if (client != null) {
      if (password == null || password.length < 8) {
        throw Exception('Password minimal 8 karakter.');
      }

      final response = await client.post<Map<String, dynamic>>(
        '/users',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'role': role.name,
          'outlet_ids': outletId.isNotEmpty ? [outletId] : [],
        },
      );

      final json = response.data?['data'] as Map<String, dynamic>?;

      if (json == null) {
        throw Exception('Respons pembuatan user tidak valid.');
      }

      return ManagedUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.fromString(json['role'] as String),
        outletId: outletId,
        outletName: outletName,
        phone: phone,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.now(),
        lastLogin: null,
      );
    }

    await _ensureInitialized();

    final user = ManagedUser(
      id: 'u-${role.name}-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: email.trim().toLowerCase(),
      role: role,
      outletId: outletId,
      outletName: outletName,
      phone: phone?.trim().isNotEmpty == true ? phone!.trim() : null,
      isActive: true,
      createdAt: DateTime.now(),
      lastLogin: null,
    );

    _memoryUsers.insert(0, user);
    await _persist();
    return user;
  }

  Future<ManagedUser> updateUser({
    required String id,
    String? name,
    String? email,
    UserRole? role,
    String? outletId,
    String? outletName,
    String? phone,
    bool? isActive,
  }) async {
    final client = _client;

    if (client != null) {
      final data = <String, dynamic>{};

      if (name != null) data['name'] = name.trim();
      if (role != null) data['role'] = role.name;
      if (isActive != null) data['is_active'] = isActive;
      if (outletId != null) {
        data['outlet_ids'] = outletId.isNotEmpty ? [outletId] : [];
      }

      final response = await client.patch<Map<String, dynamic>>(
        '/users/$id',
        data: data,
      );

      final json = response.data?['data'] as Map<String, dynamic>?;

      if (json == null) {
        throw Exception('Respons update user tidak valid.');
      }

      return ManagedUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: UserRole.fromString(json['role'] as String),
        outletId: outletId ?? '',
        outletName: outletName ?? '',
        phone: phone,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.now(),
        lastLogin: null,
      );
    }

    await _ensureInitialized();

    final index = _memoryUsers.indexWhere((user) => user.id == id);
    if (index == -1) {
      throw Exception('Pengguna dengan ID $id tidak ditemukan.');
    }

    final updated = _memoryUsers[index].copyWith(
      name: name?.trim(),
      email: email?.trim().toLowerCase(),
      role: role,
      outletId: outletId,
      outletName: outletName,
      phone: phone?.trim(),
      isActive: isActive,
    );

    _memoryUsers[index] = updated;
    await _persist();
    return updated;
  }

  Future<void> deleteUser(String id) async {
    final client = _client;

    if (client == null) {
      await _ensureInitialized();

      final index = _memoryUsers.indexWhere((user) => user.id == id);
      if (index != -1) {
        _memoryUsers.removeAt(index);
        await _persist();
      }
      return;
    }

    await client.patch<Map<String, dynamic>>(
      '/users/$id',
      data: {'is_active': false},
    );
  }

  Future<void> resetToDefaults() async {
    if (_client != null) {
      throw UnsupportedError(
        'Reset user default lokal tidak tersedia saat menggunakan API.',
      );
    }

    _memoryUsers = List<ManagedUser>.from(defaultManagedUsers);
    _isInitialized = true;
    await _persist();
  }
}
