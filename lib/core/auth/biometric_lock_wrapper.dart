import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../auth/biometric_service.dart';
import '../../features/auth/presentation/auth_provider.dart';

/// Wrapper tingkat aplikasi yang mengamati daur hidup (App Lifecycle).
/// Jika aplikasi masuk background (paused) > 5 menit dan user mengaktifkan biometrik,
/// layar kunci biometrik akan dipaksakan saat aplikasi dibuka kembali (resumed).
class BiometricLockWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricLockWrapper({super.key, required this.child});

  @override
  ConsumerState<BiometricLockWrapper> createState() => _BiometricLockWrapperState();
}

class _BiometricLockWrapperState extends ConsumerState<BiometricLockWrapper> with WidgetsBindingObserver {
  DateTime? _pausedTimestamp;
  bool _isLocked = false;
  bool _isPrompting = false;

  /// Ambang batas timeout background lock sesuai SRS (5 menit)
  static const Duration lockTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTimestamp != null) {
        final elapsed = DateTime.now().difference(_pausedTimestamp!);
        _pausedTimestamp = null;

        final authState = ref.read(authProvider);
        final isUserAuthenticated = authState.isAuthenticated;
        final isBiometricEnabled = authState.user?.settings.biometricEnabled ?? false;

        if (isUserAuthenticated && isBiometricEnabled && elapsed >= lockTimeout) {
          setState(() {
            _isLocked = true;
          });
          _promptBiometricUnlock();
        }
      }
    }
  }

  Future<void> _promptBiometricUnlock() async {
    if (_isPrompting) return;
    _isPrompting = true;

    try {
      final bioService = ref.read(biometricServiceProvider);
      final success = await bioService.authenticate(
        localizedReason: 'Aplikasi terkunci karena tidak aktif lebih dari 5 menit. Pindai sidik jari atau wajah untuk melanjutkan.',
      );

      if (success && mounted) {
        setState(() {
          _isLocked = false;
        });
      }
    } finally {
      if (mounted) {
        _isPrompting = false;
      }
    }
  }

  Future<void> _logoutToPassword() async {
    setState(() {
      _isLocked = false;
    });
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Kunci hanya ditampilkan jika user aktif login dan biometrik diaktifkan
    final shouldShowLock = _isLocked &&
        authState.isAuthenticated &&
        (authState.user?.settings.biometricEnabled ?? false);

    return Stack(
      children: [
        widget.child,
        if (shouldShowLock)
          Positioned.fill(
            child: Material(
              color: Colors.white,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlueBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 44,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Aplikasi Terkunci',
                          style: GoogleFonts.lexend(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentBlack,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sesi Anda terkunci otomatis demi keamanan karena aplikasi di-minimize lebih dari 5 menit.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lexend(
                            fontSize: 13.5,
                            color: const Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 36),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                          label: Text(
                            'Buka dengan Biometrik',
                            style: GoogleFonts.lexend(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: _promptBiometricUnlock,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.textMuted),
                          label: Text(
                            'Masuk dengan Email & Password',
                            style: GoogleFonts.lexend(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: _logoutToPassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
