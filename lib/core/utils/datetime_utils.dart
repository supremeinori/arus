/// Utilitas konversi dan formatting tanggal terpusat.
///
/// Memastikan seluruh waktu dari server/database UTC (dengan atau tanpa Z)
/// selalu terkonversi secara realtime dan akurat ke waktu lokal perangkat pengguna
/// (WIB, WITA, WIT, atau zona waktu sistem tempat perangkat berada).

DateTime parseToDeviceLocal(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) return raw.toLocal();
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  DateTime? dt;
  if (!str.endsWith('Z') &&
      !str.contains('+') &&
      !RegExp(r'-\d\d:\d\d$').hasMatch(str)) {
    dt = DateTime.tryParse('${str.replaceAll(' ', 'T')}Z');
  }
  dt ??= DateTime.tryParse(str);
  return (dt ?? DateTime.now()).toLocal();
}
