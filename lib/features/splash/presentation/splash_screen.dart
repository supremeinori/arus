import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/l10n/strings_id.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/user_model.dart';
import 'health_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isBiometricPromptActive = false;
  bool _hasNavigated = false;
  bool _hasStartedCheck = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    // PERBAIKAN 2: Gunakan addPostFrameCallback agar UI logo Splash Screen
    // dipastikan sudah selesai di-render secara visual sebelum inisialisasi / prompt biometrik dipicu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startSessionCheck();
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  /// Navigasi keluar ke Beranda (Dashboard)
  void _goToDashboard() {
    _fallbackTimer?.cancel();
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    debugPrint('[SplashScreen] EXIT ROUTE -> Beranda (/shell)');
    context.go('/shell');
  }

  /// Navigasi keluar ke Halaman Login (Email/Password)
  void _goToLogin() {
    _fallbackTimer?.cancel();
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    debugPrint('[SplashScreen] EXIT ROUTE -> Login (/login)');
    ref.read(authProvider.notifier).setUnauthenticated();
    context.go('/login');
  }

  void _startSessionCheck() {
    if (_hasStartedCheck || _hasNavigated) return;
    _hasStartedCheck = true;

    // Safety fallback timer 4000ms: Memastikan aplikasi tidak pernah stuck di logo jika
    // storage OS mengalami kebuntuan atau latency tidak normal sebelum sensor biometrik dipicu.
    _fallbackTimer = Timer(const Duration(milliseconds: 4000), () {
      if (!_hasNavigated && !_isBiometricPromptActive && mounted) {
        debugPrint('[SplashScreen] Safety fallback timeout (4000ms) fired. Forcing exit to /login.');
        _goToLogin();
      }
    });

    _initiateSessionCheck();
  }

  /// PERBAIKAN 1 & 3: Try-Catch menyeluruh & setiap cabang logika memiliki exit route eksplisit
  Future<void> _initiateSessionCheck() async {
    try {
      final secureStore = ref.read(secureStoreProvider);
      final localDb = ref.read(localDbProvider);

      debugPrint('[SplashScreen] 1. Memeriksa status kedaluwarsa sesi...');
      final isExpired = await secureStore.isSessionExpired();
      if (isExpired) {
        debugPrint('[SplashScreen] Cabang: Sesi kedaluwarsa (> 7 hari). Navigasi ke /login.');
        await ref.read(authProvider.notifier).logout();
        _goToLogin();
        return;
      }

      debugPrint('[SplashScreen] 2. Membaca sesi dari secure storage & local DB...');
      final hasStoredSecureSession = await secureStore.hasValidStoredSession();
      final cachedUser = await ref.read(authProvider.notifier).getPersistedUser();
      final refreshToken = await secureStore.getRefreshToken() ??
          (await localDb.getLatestSessionSettings())?.refreshToken;

      final hasValidSession = hasStoredSecureSession ||
          (cachedUser != null &&
              cachedUser.id.isNotEmpty &&
              cachedUser.email.isNotEmpty &&
              refreshToken != null &&
              refreshToken.isNotEmpty);

      debugPrint('[SplashScreen] hasValidSession: $hasValidSession, user: ${cachedUser?.email}');

      // Cabang 1: Token kosong atau tidak ada sesi valid -> Langsung keluar ke /login
      if (!hasValidSession || cachedUser == null) {
        debugPrint('[SplashScreen] Cabang: Belum ada sesi tersimpan. Exit ke /login.');
        _goToLogin();
        return;
      }

      // Memeriksa flag biometrik yang diaktifkan pengguna
      final isBiometricActive = await secureStore.isBiometricEnabled() ||
          cachedUser.settings.biometricEnabled;

      debugPrint('[SplashScreen] isBiometricActive: $isBiometricActive');

      // Cabang 2: Sesi ada tetapi user belum mengaktifkan biometrik -> Keluar ke /login (form login manual)
      if (!isBiometricActive) {
        debugPrint('[SplashScreen] Cabang: Biometrik belum diaktifkan user. Exit ke /login.');
        _goToLogin();
        return;
      }

      // Matikan fallback timer saat biometrik aktif agar tidak mendahului pemindaian sidik jari user
      _fallbackTimer?.cancel();
      _fallbackTimer = null;

      // PERBAIKAN 2: Beri jeda via addPostFrameCallback agar layout dan badge
      // "Menunggu sensor biometrik..." terpasang di layar sebelum pop-up OS muncul
      if (mounted) {
        setState(() {
          _isBiometricPromptActive = true;
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasNavigated) return;
        _triggerBiometricPrompt(cachedUser, refreshToken);
      });
    } catch (e, stack) {
      debugPrint('[SplashScreen] Catch: Terjadi error saat inisialisasi storage: $e\n$stack');
      // PERBAIKAN 1: Jangan biarkan aplikasi hang. Paksa keluar ke /login
      _goToLogin();
    }
  }

  /// PERBAIKAN 1 & 2: Pemanggilan authenticate() dibungkus try-catch & aman
  Future<void> _triggerBiometricPrompt(UserModel user, String? refreshToken) async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    try {
      final bioService = ref.read(biometricServiceProvider);
      final isAvailable = await bioService.isBiometricAvailable();

      debugPrint('[SplashScreen] Sensor biometrik tersedia: $isAvailable');
      // Cabang 3: Hardware biometrik tidak tersedia atau tidak didukung -> Exit ke /login
      if (!isAvailable) {
        debugPrint('[SplashScreen] Cabang: Sensor tidak tersedia. Exit ke /login.');
        _goToLogin();
        return;
      }

      final authenticated = await bioService.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke ARUS',
      );

      debugPrint('[SplashScreen] Hasil verifikasi biometrik: $authenticated');

      // Cabang 4: Biometrik sukses -> Exit ke Beranda (/shell)
      if (authenticated) {
        debugPrint('[SplashScreen] Cabang: Biometrik sukses. Exit ke Beranda (/shell).');
        ref.read(authProvider.notifier).restoreSessionInstant(user, refreshToken);
        _goToDashboard();
      } else {
        // Cabang 5: Biometrik dibatalkan atau gagal -> Exit ke /login
        debugPrint('[SplashScreen] Cabang: Biometrik dibatalkan/gagal. Exit ke /login.');
        _goToLogin();
      }
    } catch (e, stack) {
      debugPrint('[SplashScreen] Catch: Terjadi error saat trigger biometrik: $e\n$stack');
      // PERBAIKAN 1: Fallback paksa ke /login jika terjadi PlatformException
      _goToLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthCheckProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Logo & Brand Identity
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.jadeTosca,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.jadeTosca.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  StringsId.appName,
                  style: GoogleFonts.lexend(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.textPrimaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  StringsId.appTagline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                const Spacer(),
                // Health Check Status Block (Milestone 1 Core Verification)
                Card(
                  color: AppTheme.darkCardSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AsyncStateView(
                      value: healthState,
                      loadingMessage: StringsId.checkingServer,
                      onRetry: () => ref.refresh(healthCheckProvider),
                      dataBuilder: (health) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.successGreen,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                StringsId.serverOnline,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successGreen,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status: ${health.status.toUpperCase()} • DB: ${health.db} • v${health.version}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(
                              fontSize: 12,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Waktu Server: ${health.time}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(
                              fontSize: 11,
                              color: AppTheme.textMutedDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isBiometricPromptActive) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCardSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fingerprint_rounded, size: 28, color: AppTheme.jadeTosca),
                            const SizedBox(width: 10),
                            Text(
                              'Menunggu sensor biometrik...',
                              style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.password_rounded, size: 16, color: AppTheme.jadeTosca),
                          label: Text(
                            'Batal & Masuk dengan Password',
                            style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.jadeTosca),
                          ),
                          onPressed: () {
                            _goToLogin();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
