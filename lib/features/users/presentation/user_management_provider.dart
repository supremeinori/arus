import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../outlets/presentation/outlets_provider.dart';
import '../data/user_management_repository.dart';
import '../domain/user_management_models.dart';

/// Provider daftar outlet yang tersedia untuk assignment pengguna
final availableOutletsProvider = Provider<List<AssignedOutletItem>>((ref) {
  final outletsAsync = ref.watch(outletsListProvider);
  final dynamicOutlets = outletsAsync.valueOrNull;

  if (dynamicOutlets != null && dynamicOutlets.isNotEmpty) {
    return dynamicOutlets.map((o) => AssignedOutletItem(
      id: o.id,
      name: o.name,
      address: o.address,
    )).toList();
  }

  return defaultAvailableOutlets;
});

/// Filter state providers
final userRoleFilterProvider = StateProvider<String>((ref) => 'all'); // 'all' | 'manager' | 'staff'
final userOutletFilterProvider = StateProvider<String?>((ref) => null); // null = Semua Cabang
final userSearchQueryProvider = StateProvider<String>((ref) => '');

/// Notifier State untuk Daftar Pengguna
class UserManagementNotifier extends StateNotifier<AsyncValue<List<ManagedUser>>> {
  final UserManagementRepository _repo;
  final Ref _ref;

  UserManagementNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getUsers();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    final authUser = _ref.read(authProvider).user;
    if (authUser == null) {
      throw Exception('Sesi tidak valid. Silakan login kembali.');
    }

    // Role-based Security Enforcement
    if (authUser.role == UserRole.manager) {
      // Manager HANYA boleh membuat Kasir (Staff)
      if (role != UserRole.staff) {
        throw Exception('Manager hanya diizinkan untuk membuat akun Kasir (Staff).');
      }

      // Outlet Kasir WAJIB di-assign ke cabang Manager
      final managerOutletId = authUser.outlets.isNotEmpty ? authUser.outlets.first.id : 'out-sudirman';
      final managerOutletName = authUser.outlets.isNotEmpty ? authUser.outlets.first.name : 'Kopi Arus - Sudirman (HQ)';
      if (outletId != managerOutletId) {
        throw Exception('Manager hanya dapat menambahkan kasir untuk cabangnya sendiri ($managerOutletName).');
      }
    } else if (authUser.role != UserRole.owner) {
      throw Exception('Anda tidak memiliki izin untuk membuat pengguna.');
    }

    final newUser = await _repo.createUser(
      name: name,
      email: email,
      role: role,
      outletId: outletId,
      outletName: outletName,
      phone: phone,
      password: password,
    );

    // Refresh state
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data([newUser, ...currentList.where((u) => u.id != newUser.id)]);
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
    final authUser = _ref.read(authProvider).user;
    if (authUser == null) {
      throw Exception('Sesi tidak valid.');
    }

    final currentList = state.valueOrNull ?? [];
    final existingUser = currentList.firstWhere(
      (u) => u.id == id,
      orElse: () => throw Exception('Pengguna tidak ditemukan.'),
    );

    // Role-based Security Enforcement
    if (authUser.role == UserRole.manager) {
      final managerOutletId = authUser.outlets.isNotEmpty ? authUser.outlets.first.id : 'out-sudirman';
      
      // Manager hanya boleh edit Kasir di cabangnya sendiri
      if (existingUser.role != UserRole.staff || existingUser.outletId != managerOutletId) {
        throw Exception('Manager hanya dapat mengedit kasir pada cabang yang dikelolanya.');
      }

      // Manager tidak boleh mengubah role kasir menjadi manager/owner
      if (role != null && role != UserRole.staff) {
        throw Exception('Manager tidak dapat mengubah role kasir.');
      }

      // Manager tidak boleh memindahkan kasir ke cabang lain
      if (outletId != null && outletId != managerOutletId) {
        throw Exception('Manager tidak dapat memindahkan kasir ke cabang lain.');
      }
    } else if (authUser.role != UserRole.owner) {
      throw Exception('Anda tidak memiliki izin untuk mengedit pengguna.');
    }

    final updated = await _repo.updateUser(
      id: id,
      name: name,
      email: email,
      role: role,
      outletId: outletId,
      outletName: outletName,
      phone: phone,
      isActive: isActive,
    );

    state = AsyncValue.data([
      for (final u in currentList)
        if (u.id == id) updated else u,
    ]);

    return updated;
  }

  Future<void> deleteUser(String id) async {
    final authUser = _ref.read(authProvider).user;
    if (authUser == null) {
      throw Exception('Sesi tidak valid.');
    }

    final currentList = state.valueOrNull ?? [];
    final existingUser = currentList.firstWhere(
      (u) => u.id == id,
      orElse: () => throw Exception('Pengguna tidak ditemukan.'),
    );

    // Jangan izinkan owner menghapus akun miliknya sendiri
    if (existingUser.id == authUser.id) {
      throw Exception('Anda tidak dapat menghapus akun Anda sendiri.');
    }

    // Role-based Security Enforcement
    if (authUser.role == UserRole.manager) {
      final managerOutletId = authUser.outlets.isNotEmpty ? authUser.outlets.first.id : 'out-sudirman';

      // Manager hanya bisa menghapus Kasir di cabangnya sendiri
      if (existingUser.role != UserRole.staff || existingUser.outletId != managerOutletId) {
        throw Exception('Manager hanya dapat menghapus kasir di cabangnya sendiri.');
      }
    } else if (authUser.role != UserRole.owner) {
      throw Exception('Anda tidak memiliki izin untuk menghapus pengguna.');
    }

    await _repo.deleteUser(id);

    state = AsyncValue.data(
      currentList.where((u) => u.id != id).toList(),
    );
  }
}

final userManagementProvider = StateNotifierProvider<UserManagementNotifier, AsyncValue<List<ManagedUser>>>((ref) {
  final repo = ref.watch(userManagementRepositoryProvider);
  return UserManagementNotifier(repo, ref);
});

/// Provider daftar pengguna yang TERFILTER sesuai hak akses pengguna login
final visibleUsersProvider = Provider<List<ManagedUser>>((ref) {
  final authUser = ref.watch(authProvider).user;
  final usersAsync = ref.watch(userManagementProvider);
  final allUsers = usersAsync.valueOrNull ?? [];

  if (authUser == null) return [];

  final searchQuery = ref.watch(userSearchQueryProvider).trim().toLowerCase();

  // 1. Jika pengguna adalah MANAGER:
  // HANYA boleh melihat KASIR (Staff) di cabangnya sendiri
  if (authUser.role == UserRole.manager) {
    final managerOutletId = authUser.outlets.isNotEmpty ? authUser.outlets.first.id : 'out-sudirman';

    return allUsers.where((u) {
      // Wajib role staff
      if (u.role != UserRole.staff) return false;
      // Wajib di cabang manager ini
      if (u.outletId != managerOutletId) return false;
      // Filter search
      if (searchQuery.isNotEmpty) {
        final matchName = u.name.toLowerCase().contains(searchQuery);
        final matchEmail = u.email.toLowerCase().contains(searchQuery);
        return matchName || matchEmail;
      }
      return true;
    }).toList();
  }

  // 2. Jika pengguna adalah OWNER:
  // Dapat melihat SEMUA pengguna, dengan filter Role, Cabang, dan Search
  if (authUser.role == UserRole.owner) {
    final roleFilter = ref.watch(userRoleFilterProvider);
    final outletFilter = ref.watch(userOutletFilterProvider);

    return allUsers.where((u) {
      // Filter Role
      if (roleFilter == 'manager' && u.role != UserRole.manager) return false;
      if (roleFilter == 'staff' && u.role != UserRole.staff) return false;

      // Filter Outlet
      if (outletFilter != null && outletFilter.isNotEmpty && outletFilter != 'all') {
        if (u.outletId != outletFilter) return false;
      }

      // Filter Search
      if (searchQuery.isNotEmpty) {
        final matchName = u.name.toLowerCase().contains(searchQuery);
        final matchEmail = u.email.toLowerCase().contains(searchQuery);
        final matchOutlet = u.outletName.toLowerCase().contains(searchQuery);
        return matchName || matchEmail || matchOutlet;
      }

      return true;
    }).toList();
  }

  // Staff tidak memiliki izin melihat list manajemen pengguna
  return [];
});
