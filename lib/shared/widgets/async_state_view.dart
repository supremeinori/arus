import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/network/app_exception.dart';
import '../../core/l10n/strings_id.dart';
import '../../core/theme/app_theme.dart';

/// Universal Async State View per SRS Section 15.2
/// Mempermudah penanganan Loading, Error, dan Data secara seragam
class AsyncStateView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) dataBuilder;
  final VoidCallback? onRetry;
  final String? loadingMessage;

  const AsyncStateView({
    super.key,
    required this.value,
    required this.dataBuilder,
    this.onRetry,
    this.loadingMessage,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) => dataBuilder(data),
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.jadeTosca),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                loadingMessage ?? StringsId.loading,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: AppTheme.textMutedDark, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) {
        final message = err is AppException ? err.message : err.toString();
        final code = err is AppException ? err.code : 'ERROR';

        final content = Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ShadCard(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: AppTheme.dangerRed, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kode: $code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMutedDark),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    ShadButton.outline(
                      onPressed: onRetry,
                      leading: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.jadeTosca),
                      child: const Text(StringsId.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        if (ShadTheme.maybeOf(context) == null) {
          return ShadTheme(
            data: AppTheme.shadcnThemeLight,
            child: content,
          );
        }
        return content;
      },
    );
  }
}
