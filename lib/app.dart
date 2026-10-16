import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/biometric_lock_wrapper.dart';
import 'core/l10n/strings_id.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class ArusApp extends ConsumerWidget {
  const ArusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: StringsId.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => BiometricLockWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
