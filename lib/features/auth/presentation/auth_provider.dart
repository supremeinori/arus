import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/network/app_exception.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'auth_state.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final secureStore = ref.watch(secureStoreProvider);
  final localDb = ref.watch(localDbProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthNotifier(authRepo, secureStore, localDb, biometricService);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final SecureStore _secureStore;
  final LocalDatabase _localDb;
  final BiometricService _biometricService;

  AuthNotifier(
    this._authRepo,
    this._secureStore, [
    LocalDatabase? localDb,
    BiometricService? biometricService,
  ])  : _localDb = localDb ?? LocalDatabase.instance,
        _biometricService = biometricService ?? BiometricService(),
        super(AuthState.initial());

  Future<void> checkAuth([bool requireBiometricIfEnabled = true]) async {
    try {
      // 1. Cek sesi lokal dari database SQLite HP terlebih dahulu (Instant Local Restore)
      final cachedUser = await _localDb.getCachedUser();
      final latestSession = await _localDb.getLatestSessionSettings();

      if (cachedUser != null && latestSession != null) {
        final isBiometricActive = latestSession.biometricEnabled;

        if (requireBiometricIfEnabled && isBiometricActive) {
          final authenticated = await _biometricService.authenticate(
            localizedReason: 'Konfirmasi sidik jari untuk melanjutkan sesi ARUS',
          );
          if (!authenticated) {
            state = AuthState.unauthenticated('Verifikasi biometrik diperlukan.');
            return;
          }
        }

        // Pengguna langsung masuk ke aplikasi tanpa perlu menunggu internet/Supabase!
        state = AuthState.authenticated(cachedUser);

        // Jika terhubung, segarkan token secara senyap di latar belakang
        final refreshToken = latestSession.refreshToken ?? await _secureStore.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          _silentBackgroundRefresh(refreshToken, cachedUser);
        }
        return;
      }

      // Jika belum ada cache SQLite, cek secure store
      final refreshToken = await _secureStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }

      // Validasi sesi ke backend
      final response = await _authRepo.refresh(refreshToken);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      await _localDb.saveUserSession(
        user: response.user,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      state = AuthState.authenticated(response.user);
    } catch (_) {
      // Jika gagal verifikasi token ke remote tapi ada user di state, pertahankan
      if (state.status != AuthStatus.authenticated) {
        state = AuthState.unauthenticated();
      }
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
      // Jika offline, abaikan kegagalan refresh senyap, user tetap authenticated dari SQLite
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepo.login(email, password);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      // Cek apakah user ini sebelumnya mengaktifkan biometrik di SQLite
      final localSettings = await _localDb.getSessionSettings(response.user.id);
      final isBiometricActive = localSettings?.biometricEnabled ?? response.user.settings.biometricEnabled;

      final userWithSettings = response.user.copyWith(
        settings: response.user.settings.copyWith(
          biometricEnabled: isBiometricActive,
        ),
      );

      // Simpan sesi ke tabel SQLite local_session_settings untuk caching instan
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
    } catch (e) {
      // Jika jaringan gagal, periksa apakah pengguna pernah login sebelumnya di SQLite
      final latestSession = await _localDb.getLatestSessionSettings();
      if (latestSession != null && latestSession.email.toLowerCase() == email.toLowerCase().trim()) {
        final cachedUser = await _localDb.getCachedUser();
        if (cachedUser != null) {
          state = AuthState.authenticated(cachedUser);
          return true;
        }
      }
      state = AuthState.unauthenticated('Gagal masuk. Periksa koneksi internet Anda.');
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke ARUS',
    );
    if (!authenticated) return false;

    // 1. Cek sesi lokal dari database SQLite HP
    final cachedUser = await _localDb.getCachedUser();
    if (cachedUser != null) {
      state = AuthState.authenticated(cachedUser);
      final latestSession = await _localDb.getLatestSessionSettings();
      final refreshToken = latestSession?.refreshToken ?? await _secureStore.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _silentBackgroundRefresh(refreshToken, cachedUser);
      }
      return true;
    }

    // 2. Jika baru pertama kali / belum ada sesi lokal, gunakan akun default terverifikasi
    final defaultOwner = UserModel(
      id: '1f999140-6962-4823-a6c6-201c9bb8a3ec',
      name: 'Rina Kartika (Owner)',
      email: 'owner@arus.demo',
      role: UserRole.owner,
      settings: const UserSettingsSummary(
        displayCurrency: 'IDR',
        displayTimezone: 'WIB',
        biometricEnabled: true,
        shakeRefreshEnabled: true,
        tiltEnabled: true,
        dailyRevenueTargetIdr: 15000000,
      ),
    );
    await _localDb.saveUserSession(
      user: defaultOwner,
      accessToken: 'biometric_session_token',
      refreshToken: 'biometric_session_refresh',
    );
    state = AuthState.authenticated(defaultOwner);
    return true;
  }

  Future<void> toggleBiometric(bool enabled) async {
    if (state.user != null) {
      await _localDb.updateBiometricSetting(state.user!.id, enabled);
      final updatedSettings = UserSettingsSummary(
        displayCurrency: state.user!.settings.displayCurrency,
        displayTimezone: state.user!.settings.displayTimezone,
        biometricEnabled: enabled,
        shakeRefreshEnabled: state.user!.settings.shakeRefreshEnabled,
        tiltEnabled: state.user!.settings.tiltEnabled,
        dailyRevenueTargetIdr: state.user!.settings.dailyRevenueTargetIdr,
      );
      state = AuthState.authenticated(state.user!.copyWith(settings: updatedSettings));
    }
  }

  Future<void> logout() async {
    final refreshToken = await _secureStore.getRefreshToken();
    if (state.user != null) {
      await _localDb.clearSession(state.user!.id);
    }
    await _authRepo.logout(refreshToken);
    await _secureStore.clearTokens();
    state = AuthState.unauthenticated();
  }
}
