import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Kerangka daftar untuk keadaan memuat.
///
/// Dipakai saat data masih diambil supaya layar sudah punya bentuk, bukan hanya
/// satu spinner di tengah ruang kosong. Bentuknya mengikuti kartu isi daftar:
/// satu blok utama pendek dan satu blok panjang di bawahnya.
///
/// Denyutnya satu saja untuk seluruh daftar, bukan satu per baris, dan dimatikan
/// kalau pengguna meminta animasi dikurangi lewat pengaturan aksesibilitas.
class SkeletonList extends StatefulWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _denyut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _denyut = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Kalau pengguna menyalakan "kurangi gerakan", kerangka tampil diam.
    final kurangiGerak = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Padding(
      padding: widget.padding,
      child: FadeTransition(
        opacity: kurangiGerak
            ? const AlwaysStoppedAnimation<double>(0.85)
            : _denyut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(widget.itemCount, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i == widget.itemCount - 1 ? 0 : 12),
              child: const _KerangkaKartu(),
            );
          }),
        ),
      ),
    );
  }
}

class _KerangkaKartu extends StatelessWidget {
  const _KerangkaKartu();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
              color: AppTheme.lightCardBorder, // Slate-300, sama dengan kartu asli
              width: AppTheme.hairline,
            ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _KerangkaBlok(width: 44, height: 44, radius: AppTheme.radiusMd),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _KerangkaBlok(width: 140, height: 12),
                SizedBox(height: 10),
                _KerangkaBlok(width: double.infinity, height: 10),
                SizedBox(height: 8),
                _KerangkaBlok(width: 90, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KerangkaBlok extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _KerangkaBlok({
    required this.width,
    required this.height,
    this.radius = AppTheme.radiusXs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.lightCardSurfaceElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
