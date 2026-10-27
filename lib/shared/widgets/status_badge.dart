import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Badge status terpusat untuk menggantikan chip/badge tersebar di banyak layar.
/// Setiap varian pakai token warna semantik dari AppTheme agar konsisten dan
/// mudah diubah di satu tempat.
enum StatusKind {
  neutral,    // abu-abu netral
  info,       // biru informasi
  success,    // hijau sukses
  warning,    // amber peringatan
  danger,     // merah bahaya
  primary,    // tosca utama (brand)
}

/// Badge kecil (label + opsional ikon) dengan warna semantik.
/// Ukuran default 20px tinggi, cocok untuk daftar, kartu, header.
class StatusBadge extends StatelessWidget {
  final String label;
  final StatusKind kind;
  final IconData? icon;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const StatusBadge({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
    this.fontSize,
    this.padding,
    this.borderRadius,
  });

  const StatusBadge._({
    super.key,
    required this.label,
    required this.kind,
    this.icon,
    this.fontSize,
    this.padding,
    this.borderRadius,
  });

  /// Varian preset untuk kasus umum.
  const StatusBadge.neutral({
    Key? key,
    required String label,
    IconData? icon,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) : this._(
          key: key,
          label: label,
          kind: StatusKind.neutral,
          icon: icon,
          fontSize: fontSize,
          padding: padding,
        );

  const StatusBadge.success({
    Key? key,
    required String label,
    IconData? icon,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) : this._(
          key: key,
          label: label,
          kind: StatusKind.success,
          icon: icon,
          fontSize: fontSize,
          padding: padding,
        );

  const StatusBadge.warning({
    Key? key,
    required String label,
    IconData? icon,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) : this._(
          key: key,
          label: label,
          kind: StatusKind.warning,
          icon: icon,
          fontSize: fontSize,
          padding: padding,
        );

  const StatusBadge.danger({
    Key? key,
    required String label,
    IconData? icon,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) : this._(
          key: key,
          label: label,
          kind: StatusKind.danger,
          icon: icon,
          fontSize: fontSize,
          padding: padding,
        );

  const StatusBadge.primary({
    Key? key,
    required String label,
    IconData? icon,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) : this._(
          key: key,
          label: label,
          kind: StatusKind.primary,
          icon: icon,
          fontSize: fontSize,
          padding: padding,
        );

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, borderColor) = _colorsForKind(kind);
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusSm);
    final pad = padding ??
        const EdgeInsets.symmetric(horizontal: 8, vertical: 3);
    final size = fontSize ?? 11.0;

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: AppTheme.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: size + 1,
              color: textColor,
            ),
            const SizedBox(width: 4),
          ],

          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _colorsForKind(StatusKind k) {
    switch (k) {
      case StatusKind.neutral:
        return (AppTheme.lightCardSurfaceElevated, AppTheme.textMutedDark, AppTheme.lightCardBorder);
      case StatusKind.info:
        return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), const Color(0xFFBFDBFE)); // blue-50/700/200
      case StatusKind.success:
        return (AppTheme.successSurface, AppTheme.successGreenStrong, AppTheme.successGreenLight);
      case StatusKind.warning:
        return (AppTheme.warningAmberSurface, AppTheme.warningAmberMid, AppTheme.warningAmberLight);
      case StatusKind.danger:
        return (AppTheme.dangerSurface, AppTheme.dangerRedStrong, AppTheme.dangerRedLight);
      case StatusKind.primary:
        return (AppTheme.toscaSurface, AppTheme.primaryToskaHover, AppTheme.jadeTosca);
    }
  }
}

/// Chip khusus untuk nilai di Settings (ganti SettingsValueChip).
class SettingsValueChip extends StatelessWidget {
  final String label;
  final StatusKind kind;
  final IconData? icon;

  const SettingsValueChip({
    super.key,
    required this.label,
    this.kind = StatusKind.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: label,
      kind: kind,
      icon: icon,
      fontSize: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    );
  }
}