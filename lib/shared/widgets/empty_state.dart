import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
    final view = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightCardSurfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.lightCardBorder,
                  width: AppTheme.hairline,
                ),
              ),
              // Sebelumnya #64748B di atas #F1F5F9 hanya 4,34:1, tipis untuk
              // ikon sebesar ini. Dinaikkan ke #334155 supaya ikonnya jelas.
              child: Icon(icon, size: 40, color: AppTheme.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              // maxLines 3 sebelumnya memotong ajakan aksi dengan elipsis.
              // Pesan kosong harus utuh karena ia yang mengundang langkah
              // berikutnya, jadi batas barisnya dilepas.
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryLight,
              ),
            ),
            if (ctaText != null && onCtaPressed != null) ...[
              const SizedBox(height: 20),
              ShadButton.outline(
                onPressed: onCtaPressed,
                child: Text(ctaText!),
              ),
            ],
          ],
        ),
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeLight,
        child: view,
      );
    }
    return view;
  }
}
