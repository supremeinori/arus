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
import 'health_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isBiometricPromptActive = false;
  int _attemptCount = 1;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _initiateSessionCheck();
      }
    });
  }

  Future<void> _initiateSessionCheck() async {
    final localDb = ref.read(localDbProvider);
    final secureStore = ref.read(secureStoreProvider);
    final cachedUser = await localDb.getCachedUser();
    final latestSession = await localDb.getLatestSessionSettings();
    final refreshToken = latestSession?.refreshToken ?? await secureStore.getRefreshToken();

    final hasValidSession = cachedUser != null &&
        cachedUser.id.isNotEmpty &&
        cachedUser.email.isNotEmpty &&
        cachedUser.name.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty;

    if (!hasValidSession) {
      if (mounted) {
        await ref.read(authProvider.notifier).checkAuth();
      }
      return;
    }

    final isBiometricActive = latestSession?.biometricEnabled ?? cachedUser.settings.biometricEnabled;

    if (isBiometricActive) {
      setState(() {
        _isBiometricPromptActive = true;
      });
      await _handleBiometricInterception();
    } else {
      if (mounted) {
        await ref.read(authProvider.notifier).checkAuth(false);
      }
    }
  }

  Future<void> _handleBiometricInterception() async {
    final bioService = ref.read(biometricServiceProvider);
    final isAvailable = await bioService.isBiometricAvailable();

    if (!isAvailable) {
      if (mounted) {
        await ref.read(authProvider.notifier).checkAuth(false);
      }
      return;
    }

    int attempts = 0;
    bool authenticated = false;

    while (attempts < 3 && !authenticated && mounted) {
      attempts++;
      setState(() {
        _attemptCount = attempts;
      });

      authenticated = await bioService.authenticate(
        localizedReason: 'Pindai sidik jari atau wajah Anda untuk masuk ke ARUS',
      );

      if (authenticated) {
        break;
      }

      if (attempts < 3 && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (authenticated && mounted) {
      await ref.read(authProvider.notifier).checkAuth(false);
      if (mounted) {
        context.go('/shell');
      }
    } else if (mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
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
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.3),
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
                const Text(
                  StringsId.appName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  StringsId.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                // Health Check Status Block (Milestone 1 Core Verification)
                Card(
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Waktu Server: ${health.time}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fingerprint_rounded, size: 28, color: AppTheme.primaryBlue),
                            const SizedBox(width: 10),
                            Text(
                              'Menunggu sensor biometrik... ($_attemptCount/3)',
                              style: GoogleFonts.lexend(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          icon: const Icon(Icons.password_rounded, size: 16, color: AppTheme.primaryBlue),
                          label: Text(
                            'Batal & Masuk dengan Password',
                            style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                          ),
                          onPressed: () async {
                            await ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              context.go('/login');
                            }
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
