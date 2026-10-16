import 'package:flutter/material.dart';

/// Thumbnail menu 36x36 yang SELALU punya size (gambar atau placeholder).
///
/// Koreksi: teori lama ("SizedBox.shrink 0x0 memicu hit-test crash") SALAH —
/// box 0x0 tetap punya size (hasSize=true). Error "with no size" berarti
/// size==null (belum pernah layout), bukan 0x0. Widget ini dipertahankan
/// murni sebagai hygiene layout (mencegah Image.network takterbatas dari
/// path relatif seeder '/images/...'), BUKAN sebagai fix crash tersebut.
class PosMenuThumbnail extends StatelessWidget {
  final String? imageUrl;

  const PosMenuThumbnail({super.key, this.imageUrl});

  /// Hanya http(s) dengan host yang dianggap URL gambar jaringan valid.
  /// Path relatif seeder ('/images/...') dan string kosong -> placeholder.
  static bool isNetworkUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
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
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
    );
  }
}
