import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCardSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
              ),
              child: Icon(icon, size: 40, color: AppTheme.textMutedDark),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: AppTheme.textMutedDark,
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
