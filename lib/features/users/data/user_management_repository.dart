import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/prefs_store.dart';
import '../../auth/domain/user_model.dart';
import '../domain/user_management_models.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Fallback if sharedPreferencesProvider is not available in mock/testing
  }
  return UserManagementRepository(prefs);
});

class UserManagementRepository {
  final SharedPreferences? _prefs;
  static const String _storageKey = 'arus_managed_users_v1';

  List<ManagedUser> _memoryUsers = [];
  bool _isInitialized = false;

  UserManagementRepository(this._prefs);

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_prefs != null) {
      final jsonStr = _prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
          _memoryUsers = list
              .map((item) => ManagedUser.fromJson(item as Map<String, dynamic>))
              .toList();
          _isInitialized = true;
          return;
        } catch (_) {
          // If decode fails, fallback to defaults
        }
      }
    }

    _memoryUsers = List.from(defaultManagedUsers);
    _isInitialized = true;
  }

  Future<void> _persist() async {
    if (_prefs != null) {
      final jsonList = _memoryUsers.map((u) => u.toJson()).toList();
      await _prefs.setString(_storageKey, jsonEncode(jsonList));
    }
  }

  Future<List<ManagedUser>> getUsers() async {
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
    await _ensureInitialized();

    final newId = 'u-${role.name}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final newUser = ManagedUser(
      id: newId,
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

    _memoryUsers.insert(0, newUser);
    await _persist();
    return newUser;
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
    await _ensureInitialized();

    final index = _memoryUsers.indexWhere((u) => u.id == id);
    if (index == -1) {
      throw Exception('Pengguna dengan ID $id tidak ditemukan.');
    }

    final current = _memoryUsers[index];
    final updated = current.copyWith(
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
    await _ensureInitialized();
    _memoryUsers.removeWhere((u) => u.id == id);
    await _persist();
  }

  Future<void> resetToDefaults() async {
    _memoryUsers = List.from(defaultManagedUsers);
    await _persist();
  }
}
