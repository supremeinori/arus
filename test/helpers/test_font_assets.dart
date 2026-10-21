/// Helper pengujian: menjalankan `google_fonts` tanpa jaringan.
///
/// `google_fonts` mengunduh file font (Inter) saat widget dirender. Pada
/// environment test semua request HTTP diblokir (status 400) sehingga
/// `google_fonts` melempar exception yang menggagalkan test.
///
/// Helper ini menyajikan varian font sebagai *asset tiruan* lewat channel
/// `flutter/assets` (`AssetManifest.bin` + file `.ttf`), dengan file font
/// diambil dari Flutter SDK. Tidak ada asset baru di aplikasi, tidak ada
/// akses jaringan, dan asset asli aplikasi tetap dapat dimuat.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Varian font yang dibutuhkan `google_fonts` untuk family "Inter".
const List<String> kTestFontVariants = <String>[
  'Inter-Thin',
  'Inter-ExtraLight',
  'Inter-Light',
  'Inter-Regular',
  'Inter-Medium',
  'Inter-SemiBold',
  'Inter-Bold',
  'Inter-ExtraBold',
  'Inter-Black',
];

/// Aktifkan font tiruan untuk seluruh test pada isolate berjalan.
///
/// Panggil sekali di dalam test (biasanya di `setUp`) sebelum widget yang
/// memakai `GoogleFonts` dirender.
void enableGoogleFontsInTests() {
  final fontBytes = _readSdkFontBytes();
  if (fontBytes == null) {
    throw StateError(
      'File font Flutter SDK tidak ditemukan. Pastikan Flutter SDK terpasang '
      'lengkap (bin/cache/artifacts/material_fonts).',
    );
  }

  final assetsDir = _unitTestAssetsDir();
  final manifest = <Object?, Object?>{};

  // 1) Asset asli aplikasi (dari build/unit_test_assets) tetap bisa dimuat.
  if (assetsDir != null) {
    final manifestFile = File(p.join(assetsDir, 'AssetManifest.bin'));
    if (manifestFile.existsSync()) {
      final decoded = const StandardMessageCodec().decodeMessage(
        manifestFile.readAsBytesSync().buffer.asByteData(),
      );
      if (decoded is Map<Object?, Object?>) manifest.addAll(decoded);
    }
  }

  // 2) Varian font Inter sebagai asset tiruan.
  for (final variant in kTestFontVariants) {
    final key = '$variant.ttf';
    manifest[key] = <Object?>[
      <Object?, Object?>{'asset': key, 'dpr': 1.0},
    ];
  }
  final encodedManifest = const StandardMessageCodec().encodeMessage(manifest);

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(
      message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
    );

    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(encodedManifest!);
    }
    if (kTestFontVariants.contains(_stripTtfExtension(key))) {
      return SynchronousFuture<ByteData>(fontBytes);
    }
    if (assetsDir != null) {
      final file = File(p.join(assetsDir, key));
      if (file.existsSync()) {
        return SynchronousFuture<ByteData>(
          ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync())),
        );
      }
    }
    return null;
  });
}

String _stripTtfExtension(String key) {
  return key.endsWith('.ttf')
      ? key.substring(0, key.length - 4)
      : key;
}

/// Direktori asset bundle yang dibuat `flutter test` (bila tersedia).
String? _unitTestAssetsDir() {
  final dir = p.join(Directory.current.path, 'build', 'unit_test_assets');
  return Directory(dir).existsSync() ? dir : null;
}

/// Baca bytes file font dari Flutter SDK (Roboto / Material Icons).
ByteData? _readSdkFontBytes() {
  final roots = <String>[];

  final envRoot = Platform.environment['FLUTTER_ROOT'];
  if (envRoot != null && envRoot.isNotEmpty) roots.add(envRoot);

  // Cadangan: hitung FLUTTER_ROOT dari lokasi flutter_tester.exe.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  roots.add(dir.path);

  const fileNames = <String>[
    'roboto-regular.ttf',
    'Roboto-Regular.ttf',
    'materialicons-regular.otf',
    'MaterialIcons-Regular.otf',
  ];

  for (final root in roots) {
    for (final name in fileNames) {
      final file = File(
        p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts', name),
      );
      if (file.existsSync()) {
        return ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()));
      }
    }
  }
  return null;
}
