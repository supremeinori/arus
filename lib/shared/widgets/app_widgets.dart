import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_formatter.dart';

/// Field teks standar ARUS — aman di dalam Row (aturan B7: handle lebar sendiri).
/// Memakai inputDecorationTheme global; screen cukup pass controller/hint.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  /// Catatan lebar (aturan B7): widget ini TIDAK memaksa [Expanded] sendiri
  /// agar aman dipakai di mana saja (Padding/Column/Form). Kalau dipakai
  /// langsung di dalam [Row], bungkus dengan [Expanded]/[Flexible] di call-site.
  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Dropdown standar ARUS — aman di dalam Row (B7).
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final String? hintText;
  final String? labelText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? Function(T?)? validator;

  /// Catatan lebar (aturan B7): widget ini TIDAK memaksa [Expanded] sendiri
  /// agar aman dipakai di mana saja. Kalau dipakai langsung di dalam [Row],
  /// bungkus dengan [Expanded]/[Flexible] di call-site.
  const AppDropdown({
    super.key,
    this.value,
    this.hintText,
    this.labelText,
    required this.items,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: AppTheme.darkCardSurface,
      hint: hintText != null ? Text(hintText!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      decoration: InputDecoration(labelText: labelText),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// Tombol utama ARUS — memakai ShadButton dengan aksen Jade Tosca
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = ShadButton(
      width: double.infinity,
      onPressed: isLoading ? null : onPressed,
      leading: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            )
          : (icon != null ? Icon(icon, size: 16) : null),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeLight,
        child: button,
      );
    }
    return button;
  }
}

/// Kartu KPI standar — memakai ShadCard dengan border tipis dan aksen Jade Tosca
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.jadeTosca;
    final card = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ShadCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMutedDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );

    if (ShadTheme.maybeOf(context) == null) {
      return ShadTheme(
        data: AppTheme.shadcnThemeLight,
        child: card,
      );
    }
    return card;
  }
}

/// Teks uang standar — formatter terpusat (ganti NumberFormat di build, E21).
class MoneyText extends StatelessWidget {
  final num amountIdr;
  final TextStyle? style;
  final int? maxLines;

  const MoneyText(this.amountIdr, {super.key, this.style, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Text(
      MoneyFormatter.format(amountIdr),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style ??
          GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppTheme.accentBlack,
          ),
    );
  }
}
