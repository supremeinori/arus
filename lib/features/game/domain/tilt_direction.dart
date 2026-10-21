/// Logika kontrol gyroscope (hold-to-answer) untuk mini game "Guess the Menu".
///
/// Modul ini murni Dart (tanpa Flutter) agar bisa diuji unit tanpa widget test.
///
/// Sumber data sudut kemiringan berasal dari [GyroscopeReading] yang sudah
/// dihitung di `sensor_provider.dart` dari vektor gravitasi akselerometer:
///   - `pitch` : 0° saat HP dipegang tegak portrait.
///                positif = ujung atas HP condong menjauh pengguna (miring ATAS)
///                negatif = ujung atas HP condong ke pengguna (miring BAWAH)
///   - `roll`  : 0° saat HP dipegang tegak portrait.
///                positif = tepi kanan HP turun (miring KANAN)
///                negatif = tepi kiri HP turun (miring KIRI)
library;

/// Sudut (derajat) minimum pada satu sumbu untuk memulai tahan jawaban.
const double kTiltEnterThreshold = 30.0;

/// Toleransi (derajat). Tahan jawaban tetap berjalan selama sudut pada arah
/// aktif turun ke `kTiltEnterThreshold - kTiltExitTolerance` (= 20°), sehingga
/// gerakan kecil/getaran tangan tidak membatalkan progres secaraotomatis.
const double kTiltExitTolerance = 10.0;

/// Sudut (derajat) maksimum yang masih dianggap kemiringan portrait.
/// Di atas nilai ini HP dianggap miring/datar sehingga sumbu arah tidak
/// lagi ambigu (mencegah jawaban otomatis saat HP rebah atau landscape).
const double kTiltMaxAngle = 65.0;

/// Selisih sudut (derajat) minimum antar dua sumbu agar arah tidak ambigu.
const double kTiltSwitchDelta = 15.0;

/// Durasi tahan jawaban sebelum jawaban terkunci.
const Duration kTiltHoldDuration = Duration(seconds: 3);

/// Empat arah kemiringan yang dipakai menjawab soal.
enum TiltDirection {
  /// Miring ke ATAS -> jawaban A.
  up,

  /// Miring ke KANAN -> jawaban B.
  right,

  /// Miring ke KIRI -> jawaban C.
  left,

  /// Miring ke BAWAH -> jawaban D.
  down;

  /// Indeks pilihan jawaban pada daftar opsi soal (0 = A ... 3 = D).
  int get optionIndex => index;

  /// Huruf jawaban yang ditampilkan (A/B/C/D).
  String get letter => String.fromCharCode(65 + index);

  /// Nama arah dalam bahasa Indonesia.
  String get label => switch (this) {
        TiltDirection.up => 'Atas',
        TiltDirection.right => 'Kanan',
        TiltDirection.left => 'Kiri',
        TiltDirection.down => 'Bawah',
      };
}

/// Sudut kemiringan (derajat) pada satu arah tertentu.
double tiltAngleFor(
  TiltDirection direction, {
  required double pitch,
  required double roll,
}) {
  return switch (direction) {
    TiltDirection.up => pitch,
    TiltDirection.down => -pitch,
    TiltDirection.right => roll,
    TiltDirection.left => -roll,
  };
}

/// Deteksi arah kemiringan dari sudut pitch/roll.
///
/// Mengembalikan `null` bila HP berada pada posisi netral, tidak portret
/// (landatar/datar), atau arahnya ambigu. Saat [activeDirection] diisi, arah
/// tersebut mendapat toleransi (toleransi keluar) sehingga tahan jawaban tidak
/// terputus hanya karena sudutnya turun sedikit.
TiltDirection? detectTiltDirection({
  required double pitch,
  required double roll,
  TiltDirection? activeDirection,
}) {
  // HP harus dalam rentang portrait, jika tidak sumbu arah tidak ambigu.
  if (pitch.abs() > kTiltMaxAngle || roll.abs() > kTiltMaxAngle) {
    return null;
  }

  final candidates = <TiltDirection, double>{};
  void addCandidate(TiltDirection direction, double angle) {
    if (angle >= kTiltEnterThreshold) {
      candidates[direction] = angle;
    }
  }

  addCandidate(TiltDirection.up, pitch);
  addCandidate(TiltDirection.down, -pitch);
  addCandidate(TiltDirection.right, roll);
  addCandidate(TiltDirection.left, -roll);

  // Tidak ada sumbu yang cukup miring: arah aktif masih boleh dilanjutkan
  // selama sudutnya berada di dalam toleransi.
  if (candidates.isEmpty) {
    if (activeDirection != null) {
      final activeAngle = tiltAngleFor(
        activeDirection,
        pitch: pitch,
        roll: roll,
      );
      if (activeAngle >= kTiltEnterThreshold - kTiltExitTolerance) {
        return activeDirection;
      }
    }
    return null;
  }

  // Arah aktif tetap dominan selama kandidat lain tidak jauh lebih kuat.
  if (activeDirection != null && candidates.containsKey(activeDirection)) {
    final activeAngle = candidates[activeDirection]!;
    var strongestOther = 0.0;
    for (final entry in candidates.entries) {
      if (entry.key == activeDirection) continue;
      if (entry.value > strongestOther) strongestOther = entry.value;
    }
    if (activeAngle - strongestOther >= kTiltSwitchDelta) {
      return activeDirection;
    }
    return null; // Ambigu: pengguna memiringkan HP ke dua arah sekaligus.
  }

  // Tanpa arah aktif: ambil sumbu terkuat, atau null bila nyaris sama.
  final sorted = candidates.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length >= 2 && sorted[0].value - sorted[1].value < kTiltSwitchDelta) {
    return null; // Ambigu.
  }
  return sorted.first.key;
}

/// State machine tahan jawaban.
///
/// Siklus hidup:
///   - arah baru        -> progres direset ke 0 dan timer dimulai
///   - arah sama        -> progres bertambah, terkunci setelah [holdDuration]
///   - arah berubah     -> progres direset ke 0 mengikuti arah terbaru
///   - netral/tidak ada -> tahan dibatalkan (progres kembali ke 0)
///   - terkunci         -> semua sampel diabaikan sampai [reset] dipanggil
class TiltHoldTracker {
  TiltHoldTracker({this.holdDuration = kTiltHoldDuration});

  /// Durasi tahan yang dibutuhkan untuk mengunci jawaban.
  final Duration holdDuration;

  TiltDirection? _direction;
  DateTime? _startedAt;
  bool _locked = false;
  TiltDirection? _lockedDirection;

  /// Arah yang sedang ditahan pengguna (null = belum ada arah aktif).
  TiltDirection? get direction => _direction;

  /// True ketika jawaban sudah terkunci.
  bool get isLocked => _locked;

  /// Arah yang mengunci jawaban.
  TiltDirection? get lockedDirection => _lockedDirection;

  /// Waktu mulai menahan arah aktif.
  DateTime? get startedAt => _startedAt;

  /// Progres tahan (0.0 - 1.0) pada waktu [now].
  double progressAt(DateTime now) {
    if (_locked) return 1.0;
    final start = _startedAt;
    if (start == null) return 0.0;
    final elapsed = now.difference(start).inMilliseconds;
    if (elapsed <= 0) return 0.0;
    return (elapsed / holdDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Sisa waktu tahan pada waktu [now].
  Duration remainingAt(DateTime now) {
    if (_locked) return Duration.zero;
    final start = _startedAt;
    if (start == null) return holdDuration;
    final elapsed = now.difference(start);
    final left = holdDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Masukkan sampel arah hasil deteksi.
  ///
  /// Mengembalikan `true` bila ada perubahan status yang perlu ditampilkan
  /// (arah berubah atau jawaban terkunci).
  bool update({required TiltDirection? detected, required DateTime now}) {
    if (_locked) return false;

    // Netral / tidak ada arah valid -> batalkan tahan.
    if (detected == null) {
      if (_direction == null) return false;
      _direction = null;
      _startedAt = null;
      return true;
    }

    // Arah berbeda -> reset progres, mulai hitung ulang arah terbaru.
    if (detected != _direction) {
      _direction = detected;
      _startedAt = now;
      return true;
    }

    // Arah sama -> cek apakah tahan sudah cukup lama.
    final start = _startedAt;
    if (start != null && now.difference(start) >= holdDuration) {
      _locked = true;
      _lockedDirection = detected;
      return true;
    }
    return false;
  }

  /// Reset seluruh status tracker (ganti soal / selesai / keluar).
  void reset() {
    _direction = null;
    _startedAt = null;
    _locked = false;
    _lockedDirection = null;
  }
}
