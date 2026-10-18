import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/l10n/strings_id.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'auth_provider.dart';
import 'auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'owner@arus.demo');
  final _passwordController = TextEditingController(text: 'Demo1234');
  late final TextEditingController _serverController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(text: AppEnv.apiBaseUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  void _fillAccount(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (success && mounted) {
      final authState = ref.read(authProvider);
      final user = authState.user;
      final isBiometricAvailable = await ref.read(biometricServiceProvider).isBiometricAvailable();
      final isAlreadyEnabled = user?.settings.biometricEnabled ?? false;

      if (isBiometricAvailable && !isAlreadyEnabled && mounted) {
        final shouldEnable = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlueBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryBlue, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aktifkan Login Biometrik?',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'Aktifkan login biometrik untuk akses lebih cepat?',
                style: GoogleFonts.lexend(fontSize: 13.5, color: const Color(0xFF475569), height: 1.4),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Nanti Saja',
                  style: GoogleFonts.lexend(color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Ya, Aktifkan',
                  style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

        if (shouldEnable == true && mounted) {
          final confirmed = await ref.read(biometricServiceProvider).authenticate(
            localizedReason: 'Konfirmasi sidik jari atau wajah Anda untuk mengaktifkan login biometrik',
          );

          if (confirmed && mounted) {
            await ref.read(authProvider.notifier).toggleBiometric(true);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.successGreen,
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Login biometrik berhasil diaktifkan!',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }

      if (mounted) {
        context.go('/shell');
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    final success = await ref.read(authProvider.notifier).authenticateWithBiometric();
    if (success && mounted) {
      context.go('/shell');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Header
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.jadeTosca, Color(0xFF0F766E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.jadeTosca.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Masuk ke ${StringsId.appName}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Decision Support System Multi-Cabang',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error Banner
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x26EF4444),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x40EF4444), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFFEF4444)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  AppTextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    labelText: 'Alamat Email',
                    hintText: 'nama@email.com',
                    prefixIcon: Icons.email_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Email wajib diisi';
                      }
                      if (!val.contains('@')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  AppTextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    labelText: 'Password',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.textMutedDark,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Password wajib diisi';
                      }
                      if (val.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),

                  // Submit Button
                  PrimaryButton(
                    label: 'Masuk',
                    isLoading: isLoading,
                    onPressed: _submitLogin,
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _handleBiometricLogin,
                    icon: const Icon(Icons.fingerprint, color: AppTheme.jadeTosca, size: 20),
                    label: Text(
                      'Masuk dengan Biometrik (Sidik Jari)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lexend(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.jadeTosca),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Demo Accounts Fill Chips
                  const Divider(color: AppTheme.darkCardBorder, thickness: 1.0),
                  const SizedBox(height: 14),
                  Text(
                    'Pilih Akun Demo (Garis Cepat):',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMutedDark),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.star, size: 16, color: AppTheme.jadeTosca),
                        label: Text('Owner', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryDark)),
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('owner@arus.demo', 'Demo1234'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.storefront, size: 16, color: AppTheme.jadeTosca),
                        label: Text('Manager', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryDark)),
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('manager@arus.demo', 'Demo1234'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.point_of_sale, size: 16, color: AppTheme.jadeTosca),
                        label: Text('Kasir', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textPrimaryDark)),
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('staff@arus.demo', 'Demo1234'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Tombol Konfigurasi Server IP (Memudahkan testing di HP fisik)
                  Center(
                    child: InkWell(
                      onTap: () => _showServerConfigDialog(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.dns_outlined, size: 14, color: AppTheme.textMutedDark),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Server: ${AppEnv.apiBaseUrl}',
                                maxLines: 1,
                                style: GoogleFonts.lexend(
                                  fontSize: 11.5,
                                  color: AppTheme.textMutedDark,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context) {
    _serverController.text = AppEnv.apiBaseUrl;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.darkCardBorder),
          ),
          title: Row(
            children: [
              const Icon(Icons.settings_ethernet_rounded, color: AppTheme.jadeTosca, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Alamat Web Service',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimaryDark),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubah IP server jika laptop berpindah Wi-Fi/Hotspot (contoh: http://192.168.1.10:5000/api)',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textMutedDark),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _serverController,
                  labelText: 'URL Server Backend',
                  hintText: 'http://10.3.25.69:5000/api',
                  prefixIcon: Icons.link,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Batal', style: GoogleFonts.lexend(color: AppTheme.textMutedDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.jadeTosca,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final newUrl = _serverController.text.trim();
                if (newUrl.isNotEmpty) {
                  AppEnv.setCustomBaseUrl(newUrl);
                  ref.read(apiClientProvider).updateBaseUrl(AppEnv.apiBaseUrl);
                  setState(() {});
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.darkCardSurfaceElevated,
                      content: Text(
                        'URL Server diubah ke: ${AppEnv.apiBaseUrl}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(fontSize: 12.5, color: AppTheme.textPrimaryDark),
                      ),
                    ),
                  );
                }
              },
              child: Text('Simpan & Hubungkan', style: GoogleFonts.lexend(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
