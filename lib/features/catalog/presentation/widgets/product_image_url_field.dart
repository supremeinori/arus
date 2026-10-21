import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Normalisasi URL gambar produk.
///
/// Mengembalikan URL yang bisa dimuat oleh `Image.network`, atau `null` kalau
/// inputnya kosong / bukan URL http(s) yang wajar.
///
/// Aturan:
/// - String kosong (setelah trim) = tidak ada gambar (field opsional).
/// - Hanya skema `http` dan `https` yang diterima; skema lain (mis. `file:`,
///   `javascript:`) ditolak karena tidak bisa dimuat oleh Flutter.
/// - Host wajib ada supaya `https://` tanpa domain tidak lolos.
String? normalizeImageUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if (uri == null) return null;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty) return null;

  return value;
}

/// Validator form untuk field URL gambar produk.
///
/// Field opsional: string kosong tidak menghasilkan error. Isi yang bukan
/// URL http(s) yang wajar ditolak.
String? validateImageUrlField(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null; // opsional
  if (normalizeImageUrl(text) == null) {
    return 'URL gambar tidak valid (harus diawali http:// atau https://)';
  }
  return null;
}

/// Input URL gambar produk + preview langsung.
///
/// Sifat:
/// - **Opsional**: URL kosong berarti produk tanpa gambar.
/// - **Preview live**: gambar dimuat ulang saat URL berubah, dengan jeda
///   singkat supaya tidak setiap ketikan memicu request baru.
/// - **URL tidak valid** ditolak validator form dan preview menampilkan
///   penanda, tanpa pernah memanggil jaringan.
/// - **Gambar gagal dimuat** (404, offline, host mati) menampilkan pesan
///   "Gagal memuat", bukan crash dan bukan kotak berukuran nol.
/// - **Tombol hapus** mengosongkan URL; tombolnya selalu ada di widget tree
///   (dinonaktifkan saat URL kosong) supaya layout tidak bergeser.
class ProductImageUrlField extends StatelessWidget {
  const ProductImageUrlField({
    super.key,
    required this.controller,
    this.labelText = 'URL Gambar Menu (opsional)',
    this.hintText = 'https://images.unsplash.com/...',
    this.previewSize = 72,
  });

  /// Controller yang dimiliki layar induk, supaya nilai URL bisa dibaca saat
  /// menyimpan dan diisi ulang saat mode edit.
  final TextEditingController controller;

  final String labelText;
  final String hintText;

  /// Ukuran kotak preview (lebar = tinggi).
  final double previewSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              labelText: labelText,
              hintText: hintText,
              prefixIcon: const Icon(
                Icons.image_outlined,
                color: AppTheme.jadeTosca,
                size: 20,
              ),
              // Tombol hapus selalu ada di widget tree; dinonaktifkan saat
              // URL kosong, bukan dihapus.
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return IconButton(
                    tooltip: 'Kosongkan URL gambar',
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.textMutedDark,
                    onPressed: hasText ? controller.clear : null,
                  );
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.darkCardBorder,
                  width: 1.0,
                ),
              ),
            ),
            validator: validateImageUrlField,
          ),
        ),
        const SizedBox(width: 12),
        ProductImagePreview(
          controller: controller,
          size: previewSize,
        ),
      ],
    );
  }
}

/// Kotak preview gambar produk.
///
/// Ukuran selalu tetap (kotak + isi), tidak pernah `SizedBox.shrink()`, supaya
/// aman untuk hit-test mouse di desktop dan tidak menghasilkan kotak
/// berukuran nol saat gambar gagal dimuat.
class ProductImagePreview extends StatefulWidget {
  const ProductImagePreview({
    super.key,
    required this.controller,
    this.size = 72,
  });

  final TextEditingController controller;
  final double size;

  @override
  State<ProductImagePreview> createState() => _ProductImagePreviewState();
}

class _ProductImagePreviewState extends State<ProductImagePreview> {
  /// Jeda sebelum request gambar berikutnya dibuat.
  static const _debounce = Duration(milliseconds: 400);

  Timer? _debounceTimer;

  /// Teks URL terakhir yang sudah diproses (mentah, tanpa trim).
  String _raw = '';

  /// URL yang sedang dimuat (setelah jeda). `null` = belum ada yang dimuat.
  String? _activeUrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    // Nilai awal (mode edit) langsung dipakai, tanpa jeda.
    _raw = widget.controller.text.trim();
    _activeUrl = normalizeImageUrl(_raw);
  }

  @override
  void didUpdateWidget(covariant ProductImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    // Timer dibatalkan supaya tidak ada timer menggantung setelah widget
    // dibuang (bisa memicu assertion pada flutter_test).
    _debounceTimer?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    // Controller bisa diubah dari luar (mis. prefill mode edit) saat sedang
    // build. Penundaan ke frame berikutnya mencegah pemanggilan setState
    // saat build.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyUrl();
      });
      return;
    }
    _applyUrl();
  }

  void _applyUrl() {
    final raw = widget.controller.text.trim();
    final url = normalizeImageUrl(raw);

    if (raw == _raw && url == _activeUrl) return;

    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (url == null) {
      // URL kosong / tidak valid: tidak ada request ke jaringan, preview
      // langsung menandai kondisi tersebut.
      setState(() {
        _raw = raw;
        _activeUrl = null;
      });
      return;
    }

    setState(() => _raw = raw);

    if (url == _activeUrl) return;

    // Jeda dulu: satu request per jeda, bukan satu per ketikan.
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      if (!mounted) return;
      setState(() => _activeUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final current = normalizeImageUrl(_raw);

    Widget content;
    if (_raw.isEmpty) {
      content = _placeholder(
        Icons.image_outlined,
        'Belum ada gambar',
        AppTheme.textMutedDark,
        size,
      );
    } else if (current == null) {
      content = _placeholder(
        Icons.link_off,
        'URL tidak valid',
        AppTheme.dangerRed,
        size,
      );
    } else if (_activeUrl != current) {
      content = _placeholder(
        Icons.hourglass_empty,
        'Memuat...',
        AppTheme.textMutedDark,
        size,
      );
    } else {
      content = Image.network(
        current,
        key: ValueKey(current),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          Icons.broken_image_outlined,
          'Gagal memuat',
          AppTheme.dangerRed,
          size,
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder(
            Icons.downloading,
            'Memuat...',
            AppTheme.textMutedDark,
            size,
          );
        },
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          color: AppTheme.darkCardSurfaceElevated,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  Widget _placeholder(IconData icon, String label, Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 9, color: color, height: 1.1),
          ),
        ],
      ),
    );
  }
}
