import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/storage/prefs_store.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final secureStore = ref.watch(secureStoreProvider);
  final localDb = ref.watch(localDbProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  PrefsStore? prefsStore;
  try {
    prefsStore = ref.watch(prefsStoreProvider);
  } catch (_) {}
  return AuthNotifier(authRepo, secureStore, localDb, biometricService, prefsStore);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final SecureStore _secureStore;
  final LocalDatabase _localDb;
  final BiometricService _biometricService;
  final PrefsStore? _prefsStore;

  AuthNotifier(
    this._authRepo,
    this._secureStore, [
    LocalDatabase? localDb,
    BiometricService? biometricService,
    PrefsStore? prefsStore,
  ])  : _localDb = localDb ?? LocalDatabase.instance,
        _biometricService = biometricService ?? BiometricService(),
        _prefsStore = prefsStore,
        super(AuthState.initial());

  /// Memeriksa status sesi saat startup / hot reload.
  /// Sesi HANYA dianggap aktif jika pengguna benar-benar pernah login dan memiliki token valid.
  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {
    try {
      final cachedUser = await _localDb.getCachedUser();
      final latestSession = await _localDb.getLatestSessionSettings();
      final refreshToken = latestSession?.refreshToken ?? await _secureStore.getRefreshToken();

      // Validasi ketat: Wajib ada profil lengkap (id, email, nama) dan refresh token aktif
      final hasValidSession = cachedUser != null &&
          cachedUser.id.isNotEmpty &&
          cachedUser.email.isNotEmpty &&
          cachedUser.name.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty;

      if (!hasValidSession) {
        state = AuthState.unauthenticated();
        return;
      }

      // Jika user mengaktifkan biometrik, wajib verifikasi sensor fisik
      final isBiometricActive = latestSession?.biometricEnabled ?? cachedUser.settings.biometricEnabled;
      if (requireBiometricIfEnabled && isBiometricActive) {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Konfirmasi sidik jari untuk melanjutkan sesi ARUS',
        );
        if (!authenticated) {
          state = AuthState.unauthenticated('Verifikasi biometrik diperlukan.');
          return;
        }
      }

      // Coba segarkan token ke backend web service
      try {
        final response = await _authRepo.refresh(refreshToken);
        await _secureStore.setAccessToken(response.accessToken);
        await _secureStore.setRefreshToken(response.refreshToken);

        await _localDb.saveUserSession(
          user: response.user,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        );

        if (mounted) {
          state = AuthState.authenticated(response.user);
        }
      } on AppException catch (e) {
        // Jika token ditolak oleh server (kadaluarsa / dicabut), paksa logout
        if (e.statusCode == 401 || e.statusCode == 403) {
          await logout();
          return;
        }
        // Jika koneksi web service terputus tapi sesi lokal sebelumnya sah, gunakan cache lokal
        if (mounted) {
          state = AuthState.authenticated(cachedUser);
        }
      } catch (_) {
        if (mounted) {
          state = AuthState.authenticated(cachedUser);
        }
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  void _silentBackgroundRefresh(String refreshToken, UserModel currentUser) async {
    try {
      final response = await _authRepo.refresh(refreshToken);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      await _localDb.saveUserSession(
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      if (mounted) {
        state = AuthState.authenticated(response.user);
      }
    } catch (_) {
      // Abaikan jika offline, sesi offline lokal tetap berjalan
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepo.login(email, password);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      final localSettings = await _localDb.getSessionSettings(response.user.id);
      final isBiometricActive = localSettings?.biometricEnabled ?? response.user.settings.biometricEnabled;

      final userWithSettings = response.user.copyWith(
        settings: response.user.settings.copyWith(
          biometricEnabled: isBiometricActive,
        ),
      );

      await _localDb.saveUserSession(
        user: userWithSettings,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      state = AuthState.authenticated(userWithSettings);
      return true;
    } on AppException catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (_) {
      state = AuthState.unauthenticated('Koneksi ke web service terputus. Gagal menghubungi server.');
      return false;
    }
  }

  /// Autentikasi biometrik HANYA jika ada akun sah yang pernah login di HP ini.
  Future<bool> authenticateWithBiometric() async {
    final cachedUser = await _localDb.getCachedUser();
    final latestSession = await _localDb.getLatestSessionSettings();
    final refreshToken = latestSession?.refreshToken ?? await _secureStore.getRefreshToken();

    if (cachedUser == null ||
        cachedUser.id.isEmpty ||
        cachedUser.email.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      state = AuthState.unauthenticated('Belum ada akun yang terdaftar untuk biometrik. Silakan login terlebih dahulu.');
      return false;
    }

    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke ARUS',
    );
    if (!authenticated) return false;

    state = AuthState.authenticated(cachedUser);
    _silentBackgroundRefresh(refreshToken, cachedUser);
    return true;
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (state.user != null) {
      await _localDb.updateBiometricSetting(state.user!.id, enabled);
      await _prefsStore?.setBiometricEnabled(enabled);
      final updatedSettings = state.user!.settings.copyWith(
        biometricEnabled: enabled,
      );
      state = AuthState.authenticated(state.user!.copyWith(settings: updatedSettings));
    }
  }

  Future<void> logout() async {
    final refreshToken = await _secureStore.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authRepo.logout(refreshToken);
      } catch (_) {}
    }
    await _localDb.clearSession();
    await _secureStore.clearTokens();
    state = AuthState.unauthenticated();
  }
}
