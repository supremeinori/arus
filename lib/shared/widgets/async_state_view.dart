import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/app_exception.dart';
import '../../core/l10n/strings_id.dart';

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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              loadingMessage ?? StringsId.loading,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
      error: (err, stack) {
        final message = err is AppException ? err.message : err.toString();
        final code = err is AppException ? err.code : 'ERROR';

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kode: $code',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                    ),
                    if (onRetry != null) ...[
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: onRetry,
                        child: const Text(StringsId.retry),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
