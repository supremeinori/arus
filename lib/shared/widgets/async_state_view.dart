import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
                style: GoogleFonts.lexend(color: AppTheme.textMutedDark, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) {
        final message = err is AppException ? err.message : err.toString();
        final code = err is AppException ? err.code : 'ERROR';

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33EF4444), width: 1.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0x26EF4444),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexend(
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
                    style: GoogleFonts.lexend(fontSize: 11.5, color: AppTheme.textMutedDark),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkCardSurfaceElevated,
                        foregroundColor: AppTheme.textPrimaryDark,
                        side: const BorderSide(color: AppTheme.darkCardBorder),
                      ),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.jadeTosca),
                      label: const Text(StringsId.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
