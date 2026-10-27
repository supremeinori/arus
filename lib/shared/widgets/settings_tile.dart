import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Kartu kontainer untuk sekumpulan baris pengaturan.
class SettingsSectionCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsSectionCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shadowColor: AppTheme.shadowSoft,
      color: AppTheme.lightCardSurface,
      // clipBehavior menjaga riak tekan tetap di dalam sudut kartu supaya tepi
      // bulatnya tidak tertimpa kotak saat baris ditekan.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(
          color: AppTheme.lightCardBorder,
          width: AppTheme.hairline,
        ),
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
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
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
      color: AppTheme.lightCardBorder,
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
