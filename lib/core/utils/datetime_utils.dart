/// Utilitas konversi dan formatting tanggal terpusat.
///
/// Memastikan seluruh waktu dari server/database UTC (dengan atau tanpa Z)
/// selalu terkonversi secara realtime dan akurat ke waktu lokal perangkat pengguna
/// (WIB, WITA, WIT, atau zona waktu sistem tempat perangkat berada).

library;

bool _hasTimezoneMarker(String str) {
  return str.endsWith('Z') ||
      str.contains('+') ||
      RegExp(r'-\d\d:\d\d$').hasMatch(str);
}

DateTime parseToDeviceLocal(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) return raw.toLocal();
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  DateTime? dt;
  if (!_hasTimezoneMarker(str)) {
    dt = DateTime.tryParse('${str.replaceAll(' ', 'T')}Z');
  }
  dt ??= DateTime.tryParse(str);
  return (dt ?? DateTime.now()).toLocal();
}

/// Parsing timestamp yang disimpan sebagai cache lokal.
///
/// String tanpa penanda zona waktu dianggap waktu lokal perangkat (hasil
/// `DateTime.toIso8601String()`), bukan UTC. Ini mencegah pergeseran hari
/// akibat konversi ganda saat data dibaca kembali.
DateTime parseStoredLocal(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  final dt = DateTime.tryParse(str.replaceAll(' ', 'T'));
  if (dt == null) return DateTime.now();
  return _hasTimezoneMarker(str) ? dt.toLocal() : dt;
}

/// Normalisasi timestamp penyimpanan lokal ke ISO-8601 UTC (berakhiran `Z`)
/// agar round-trip tulis-baca menghasilkan waktu lokal yang sama.
String toStorageUtcIso(dynamic raw) {
  return parseStoredLocal(raw).toUtc().toIso8601String();
}
