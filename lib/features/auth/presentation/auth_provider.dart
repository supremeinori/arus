import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/network/app_exception.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final secureStore = ref.watch(secureStoreProvider);
  return AuthNotifier(authRepo, secureStore);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final SecureStore _secureStore;

  AuthNotifier(this._authRepo, this._secureStore) : super(AuthState.initial());

  Future<void> checkAuth() async {
    try {
      final refreshToken = await _secureStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }

      // Coba segarkan token untuk validasi sesi
      final response = await _authRepo.refresh(refreshToken);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      state = AuthState.authenticated(response.user);
    } catch (_) {
      await _secureStore.clearTokens();
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepo.login(email, password);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      state = AuthState.authenticated(response.user);
      return true;
    } on AppException catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated('Gagal masuk. Periksa koneksi internet Anda.');
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _secureStore.getRefreshToken();
    await _authRepo.logout(refreshToken);
    await _secureStore.clearTokens();
    state = AuthState.unauthenticated();
  }
}
