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
      final refreshToken = await _secureStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        state = AuthState.unauthenticated();
        return;
      }

      // Validasi sesi ke backend
      final response = await _authRepo.refresh(refreshToken);
      await _secureStore.setAccessToken(response.accessToken);
      await _secureStore.setRefreshToken(response.refreshToken);

      // Cek preferensi biometrik dari SQLite lokal
      final localSettings = await _localDb.getSessionSettings(response.user.id);
      final isBiometricActive = localSettings?.biometricEnabled ?? response.user.settings.biometricEnabled;

      if (requireBiometricIfEnabled && isBiometricActive) {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Konfirmasi sidik jari untuk melanjutkan sesi ARUS',
        );
        if (!authenticated) {
          state = AuthState.unauthenticated('Verifikasi biometrik diperlukan.');
          return;
        }
      }

      // Sinkronkan ke local_session_settings SQLite
      await _localDb.saveSessionSettings(
        LocalSessionSettings(
          userId: response.user.id,
          name: response.user.name,
          email: response.user.email,
          role: response.user.role.name,
          avatarUrl: response.user.avatarUrl,
          biometricEnabled: isBiometricActive,
          displayCurrency: response.user.settings.displayCurrency,
          displayTimezone: response.user.settings.displayTimezone,
          shakeSensorEnabled: response.user.settings.shakeRefreshEnabled,
          tiltSensorEnabled: response.user.settings.tiltEnabled,
        ),
      );

      final userWithLocalBio = response.user.copyWith(
        settings: UserSettingsSummary(
          displayCurrency: response.user.settings.displayCurrency,
          displayTimezone: response.user.settings.displayTimezone,
          biometricEnabled: isBiometricActive,
          shakeRefreshEnabled: response.user.settings.shakeRefreshEnabled,
          tiltEnabled: response.user.settings.tiltEnabled,
          dailyRevenueTargetIdr: response.user.settings.dailyRevenueTargetIdr,
        ),
      );

      state = AuthState.authenticated(userWithLocalBio);
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

      // Cek apakah user ini sebelumnya mengaktifkan biometrik di SQLite
      final localSettings = await _localDb.getSessionSettings(response.user.id);
      final isBiometricActive = localSettings?.biometricEnabled ?? response.user.settings.biometricEnabled;

      // Simpan sesi ke tabel SQLite local_session_settings (Section 5)
      await _localDb.saveSessionSettings(
        LocalSessionSettings(
          userId: response.user.id,
          name: response.user.name,
          email: response.user.email,
          role: response.user.role.name,
          avatarUrl: response.user.avatarUrl,
          biometricEnabled: isBiometricActive,
          displayCurrency: response.user.settings.displayCurrency,
          displayTimezone: response.user.settings.displayTimezone,
          shakeSensorEnabled: response.user.settings.shakeRefreshEnabled,
          tiltSensorEnabled: response.user.settings.tiltEnabled,
        ),
      );

      final userWithSettings = response.user.copyWith(
        settings: UserSettingsSummary(
          displayCurrency: response.user.settings.displayCurrency,
          displayTimezone: response.user.settings.displayTimezone,
          biometricEnabled: isBiometricActive,
          shakeRefreshEnabled: response.user.settings.shakeRefreshEnabled,
          tiltEnabled: response.user.settings.tiltEnabled,
          dailyRevenueTargetIdr: response.user.settings.dailyRevenueTargetIdr,
        ),
      );

      state = AuthState.authenticated(userWithSettings);
      return true;
    } on AppException catch (e) {
      state = AuthState.unauthenticated(e.message);
      return false;
    } catch (e) {
      state = AuthState.unauthenticated('Gagal masuk. Periksa koneksi internet Anda.');
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke ARUS',
    );
    if (authenticated) {
      await checkAuth(false);
      return true;
    }
    return false;
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
