import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Thumbnail menu yang SELALU punya size pasti (gambar atau placeholder)
/// untuk mencegah hit-test crash dan RenderBox unbounded height.
class PosMenuThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const PosMenuThumbnail({
    super.key,
    this.imageUrl,
    this.width = 36,
    this.height = 36,
    this.borderRadius,
  });

  /// Hanya http(s) dengan host yang dianggap URL gambar jaringan valid.
  static bool isNetworkUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(6);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: isNetworkUrl(imageUrl)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _placeholder(Icons.image_not_supported_outlined),
              )
            : _placeholder(Icons.fastfood_outlined),
      ),
    );
  }

  Widget _placeholder(IconData icon) {
    return Container(
      color: AppTheme.lightCardSurfaceElevated,
      alignment: Alignment.center,
      child: Icon(icon, size: (height != null && height! > 50) ? 32 : 20, color: AppTheme.borderStrong),
    );
  }
}
