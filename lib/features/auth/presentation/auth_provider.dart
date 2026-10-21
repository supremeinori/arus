import 'dart:convert';
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

  /// Mengambil data user yang tersimpan di SecureStore atau LocalDatabase SQLite
  Future<UserModel?> getPersistedUser() async {
    final secureUserJson = await _secureStore.getUserJson();
    if (secureUserJson != null && secureUserJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(secureUserJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(decoded);
        if (user.id.isNotEmpty && user.email.isNotEmpty) {
          final isBio = await _secureStore.isBiometricEnabled();
          return user.copyWith(
            settings: user.settings.copyWith(biometricEnabled: isBio),
          );
        }
      } catch (_) {}
    }

    final cached = await _localDb.getCachedUser();
    if (cached != null) {
      final isBio = await _secureStore.isBiometricEnabled();
      return cached.copyWith(
        settings: cached.settings.copyWith(biometricEnabled: isBio || cached.settings.biometricEnabled),
      );
    }
    return null;
  }

  /// Mengatur state in-memory menjadi unauthenticated tanpa menghapus session secure storage
  void setUnauthenticated([String? message]) {
    state = AuthState.unauthenticated(message);
  }

  /// Memulihkan sesi pengguna secara instan dari cache lokal tanpa memblokir UI
  void restoreSessionInstant(UserModel user, [String? refreshToken]) {
    state = AuthState.authenticated(user);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _silentBackgroundRefresh(refreshToken, user);
    }
  }

  /// Memeriksa status sesi saat startup / hot reload.
  /// Sesi HANYA dianggap aktif jika pengguna benar-benar pernah login dan memiliki token valid.
  Future<void> checkAuth([bool requireBiometricIfEnabled = false]) async {
    try {
      if (await _secureStore.isSessionExpired()) {
        await logout();
        state = AuthState.unauthenticated();
        return;
      }

      final cachedUser = await getPersistedUser();
      final latestSession = await _localDb.getLatestSessionSettings();
      final refreshToken = await _secureStore.getRefreshToken() ?? latestSession?.refreshToken;

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

      final isBioSecure = await _secureStore.isBiometricEnabled();
      final isBiometricActive = isBioSecure || cachedUser.settings.biometricEnabled;

      if (requireBiometricIfEnabled && isBiometricActive) {
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Konfirmasi sidik jari untuk melanjutkan sesi ARUS',
        );
        if (!authenticated) {
          state = AuthState.unauthenticated('Verifikasi biometrik diperlukan.');
          return;
        }
      }

      state = AuthState.authenticated(cachedUser);

      // Coba segarkan token ke backend web service
      try {
        final response = await _authRepo.refresh(refreshToken);
        final updatedUser = response.user.copyWith(
          settings: response.user.settings.copyWith(
            biometricEnabled: isBiometricActive,
          ),
        );

        await _secureStore.saveSession(
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
          userJson: jsonEncode(updatedUser.toJson()),
          biometricEnabled: isBiometricActive,
        );

        await _localDb.saveUserSession(
          user: updatedUser,
          accessToken: response.accessToken,
          refreshToken: response.refreshToken,
        );

        if (mounted) {
          state = AuthState.authenticated(updatedUser);
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
      final isBio = await _secureStore.isBiometricEnabled();
      final updatedUser = response.user.copyWith(
        settings: response.user.settings.copyWith(
          biometricEnabled: isBio,
        ),
      );

      await _secureStore.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userJson: jsonEncode(updatedUser.toJson()),
        biometricEnabled: isBio,
      );

      await _localDb.saveUserSession(
        user: updatedUser,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      if (mounted) {
        state = AuthState.authenticated(updatedUser);
      }
    } catch (_) {
      // Abaikan jika offline, sesi offline lokal tetap berjalan
    }
  }

  Future<bool> login(String email, String password) async {
    state = AuthState.loading();
    try {
      final response = await _authRepo.login(email, password);
      
      final isBioSecure = await _secureStore.isBiometricEnabled();
      final localSettings = await _localDb.getSessionSettings(response.user.id);
      final isBiometricActive = isBioSecure || (localSettings?.biometricEnabled ?? response.user.settings.biometricEnabled);

      final userWithSettings = response.user.copyWith(
        settings: response.user.settings.copyWith(
          biometricEnabled: isBiometricActive,
        ),
      );

      final userJson = jsonEncode(userWithSettings.toJson());

      // Simpan ke SecureStore (tahan banting di level OS Encrypted Storage)
      await _secureStore.saveSession(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userJson: userJson,
        biometricEnabled: isBiometricActive,
      );

      // Simpan ke LocalDatabase SQLite
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
    if (await _secureStore.isSessionExpired()) {
      await logout();
      state = AuthState.unauthenticated('Sesi telah kedaluwarsa (lebih dari 7 hari). Silakan login ulang.');
      return false;
    }

    final cachedUser = await getPersistedUser();
    final latestSession = await _localDb.getLatestSessionSettings();
    final refreshToken = await _secureStore.getRefreshToken() ?? latestSession?.refreshToken;

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
    if (!authenticated) {
      // Jangan hapus data sesi saat user membatalkan prompt biometrik
      return false;
    }

    state = AuthState.authenticated(cachedUser);
    _silentBackgroundRefresh(refreshToken, cachedUser);
    return true;
  }

  Future<void> toggleBiometric(bool enabled) async {
    await _secureStore.setBiometricEnabled(enabled);
    await _prefsStore?.setBiometricEnabled(enabled);

    final currentUser = state.user ?? await getPersistedUser();
    if (currentUser != null) {
      await _localDb.updateBiometricSetting(currentUser.id, enabled);
      final updatedSettings = currentUser.settings.copyWith(
        biometricEnabled: enabled,
      );
      final updatedUser = currentUser.copyWith(settings: updatedSettings);
      await _secureStore.setUserJson(jsonEncode(updatedUser.toJson()));
      if (state.isAuthenticated) {
        state = AuthState.authenticated(updatedUser);
      }
    }
  }

  /// Terapkan preferensi mata uang ke state sesi setelah berhasil disimpan
  /// di backend (PATCH /users/me/settings).
  ///
  /// Dipanggil oleh [DisplayCurrencyNotifier] supaya seluruh widget yang
  /// membaca `authProvider` ikut berubah tanpa perlu reload aplikasi.
  Future<void> applyDisplayCurrency(String currency) async {
    final currentUser = state.user;
    if (currentUser == null) return;
    if (currentUser.settings.displayCurrency == currency) return;

    final updatedUser = currentUser.copyWith(
      settings: currentUser.settings.copyWith(displayCurrency: currency),
    );

    try {
      await _secureStore.setUserJson(jsonEncode(updatedUser.toJson()));
    } catch (_) {}
    try {
      await _localDb.updateDisplayCurrencySetting(updatedUser.id, currency);
    } catch (_) {}

    if (mounted) {
      state = AuthState.authenticated(updatedUser);
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
