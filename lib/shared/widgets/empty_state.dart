import 'package:flutter/material.dart';

class EmptyStateView extends StatelessWidget {
  final String message;
  final String? ctaText;
  final VoidCallback? onCtaPressed;
  final IconData icon;

  const EmptyStateView({
    super.key,
    required this.message,
    this.ctaText,
    this.onCtaPressed,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
            if (ctaText != null && onCtaPressed != null) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onCtaPressed,
                child: Text(ctaText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
