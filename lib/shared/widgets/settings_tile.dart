import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Kartu kontainer untuk sekumpulan baris pengaturan.
class SettingsSectionCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsSectionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.darkCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
      ),
      child: Column(children: children),
    );
  }
}

/// Label kecil huruf kapital di atas kartu pengaturan.
class SettingsSectionLabel extends StatelessWidget {
  final String text;

  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppTheme.textMutedDark,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Garis pemisah antar baris di dalam [SettingsSectionCard].
class SettingsTileDivider extends StatelessWidget {
  const SettingsTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppTheme.darkCardBorder,
    );
  }
}

/// Baris pengaturan yang bisa ditekan: ikon toska, judul, dan aksi di kanan.
///
/// Kalau [trailing] kosong baris menampilkan chevron. [subtitle] dipakai saat
/// judul saja belum cukup menjelaskan isi layar tujuannya.
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.jadeTosca),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.textMutedDark,
              ),
            ),
      trailing:
          trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppTheme.textMutedDark,
          ),
      onTap: onTap,
    );
  }
}

/// Chip nilai pengaturan aktif, mis. "IDR" untuk kurs, "WIB" untuk waktu.
class SettingsValueChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const SettingsValueChip({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.darkCardSurfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: AppTheme.jadeTosca),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.jadeTosca,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppTheme.textMutedDark,
        ),
      ],
    );
  }
}
