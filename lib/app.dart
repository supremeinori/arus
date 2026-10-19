import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'core/auth/biometric_lock_wrapper.dart';
import 'core/l10n/strings_id.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class ArusApp extends ConsumerWidget {
  const ArusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return ShadApp.router(
      title: StringsId.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.shadcnThemeLight,
      darkTheme: AppTheme.shadcnThemeLight,
      themeMode: ThemeMode.light,
      routerConfig: router,
      materialThemeBuilder: (context, theme) {
        return AppTheme.lightTheme;
      },
      builder: (context, child) => BiometricLockWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

