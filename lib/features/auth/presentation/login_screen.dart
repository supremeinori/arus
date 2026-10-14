import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/l10n/strings_id.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.white,
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
                          colors: [Color(0xFF0D9488), Color(0xFF115E59)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x330D9488),
                            blurRadius: 16,
                            offset: Offset(0, 6),
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
                    style: GoogleFonts.lexend(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Decision Support System Multi-Cabang',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error Banner
                  if (authState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: GoogleFonts.lexend(fontSize: 12.5, color: const Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.lexend(fontSize: 14, color: AppTheme.accentBlack),
                    decoration: InputDecoration(
                      labelText: 'Alamat Email',
                      hintText: 'nama@email.com',
                      prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.accentBlack, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      ),
                    ),
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
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.lexend(fontSize: 14, color: AppTheme.accentBlack),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.accentBlack, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.accentBlack,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      ),
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
                  ElevatedButton(
                    onPressed: isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: AppTheme.borderOutline, width: 1.5),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Masuk',
                            style: GoogleFonts.lexend(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),

                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).authenticateWithBiometric(),
                    icon: const Icon(Icons.fingerprint, color: AppTheme.primaryBlue, size: 20),
                    label: Text(
                      'Masuk dengan Biometrik (Sidik Jari)',
                      style: GoogleFonts.lexend(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Demo Accounts Fill Chips
                  const Divider(color: AppTheme.borderOutline, thickness: 1.5),
                  const SizedBox(height: 14),
                  Text(
                    'Pilih Akun Demo (Garis Cepat):',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lexend(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.star, size: 16, color: AppTheme.primaryBlue),
                        label: Text('Owner', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12)),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('owner@arus.demo', 'Demo1234'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.storefront, size: 16, color: AppTheme.primaryBlue),
                        label: Text('Manager', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12)),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('manager@arus.demo', 'Demo1234'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.point_of_sale, size: 16, color: AppTheme.primaryBlue),
                        label: Text('Kasir', style: GoogleFonts.lexend(fontWeight: FontWeight.w600, fontSize: 12)),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: AppTheme.borderOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        onPressed: () => _fillAccount('staff@arus.demo', 'Demo1234'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
