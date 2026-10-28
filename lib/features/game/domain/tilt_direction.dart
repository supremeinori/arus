/// Logika kontrol gyroscope untuk mini game "Guess the Menu".
///
/// Modul ini murni Dart (tanpa Flutter) agar bisa diuji unit tanpa widget test.
///
/// Sumber data sudut kemiringan berasal dari [GyroscopeReading] yang sudah
/// dihitung di `sensor_provider.dart` dari vektor gravitasi akselerometer:
///   - `roll`  : 0° saat HP dipegang tegak portrait.
///                positif = tepi kanan HP turun (miring KANAN)
///                negatif = tepi kiri HP turun (miring KIRI)
///   - `pitch` : 0° saat HP dipegang tegak portrait.
library;

// ============================================================
// KONTROL 2-ARAH (MIRING KIRI & MIRING KANAN) — INSTAN & DEBOUNCE
// ============================================================

/// Sudut kemiringan roll minimum untuk memicu pemilihan jawaban instan.
const double kTilt2WayThreshold = 22.0;

/// Ambang sudut roll untuk dianggap telah kembali ke posisi netral.
const double kTilt2WayNeutralThreshold = 10.0;

/// Dua arah kemiringan untuk menjawab kuis 2 pilihan: Kiri & Kanan.
enum Tilt2WayDirection {
  /// Miring ke KIRI -> Opsi Kiri (0 / A)
  left,

  /// Miring ke KANAN -> Opsi Kanan (1 / B)
  right;

  /// Indeks pilihan jawaban (0 = Kiri, 1 = Kanan).
  int get optionIndex => index;

  /// Huruf jawaban yang ditampilkan (A atau B).
  String get letter => index == 0 ? 'A' : 'B';

  /// Nama arah dalam bahasa Indonesia.
  String get label => index == 0 ? 'Kiri' : 'Kanan';
}

/// Deteksi arah kemiringan 2-arah berdasarkan sudut [roll].
///
/// Roll negatif = miring kiri (tepi kiri HP turun).
/// Roll positif = miring kanan (tepi kanan HP turun).
/// Mengembalikan null bila sudut berada di bawah [threshold] (posisi netral).
Tilt2WayDirection? detect2WayTilt({
  required double roll,
  double threshold = kTilt2WayThreshold,
}) {
  if (roll <= -threshold) {
    return Tilt2WayDirection.left;
  } else if (roll >= threshold) {
    return Tilt2WayDirection.right;
  }
  return null;
}

/// Mesin status pemicu instan kemiringan dengan proteksi debounce.
///
/// Memilih jawaban **seketika** (tanpa delay tahan 3 detik) begitu sudut
/// melewati ambang batas. Sekali terpicu pada suatu soal, sensor terkunci
/// agar tidak memicu jawaban beruntun/ganda (debounce).
class TiltInstantTrigger {
  TiltInstantTrigger({this.threshold = kTilt2WayThreshold});

  final double threshold;
  bool _isTriggered = false;
  Tilt2WayDirection? _lastTriggeredDirection;

  /// Apakah jawaban sudah terkunci via input kemiringan pada soal aktif.
  bool get isTriggered => _isTriggered;

  /// Arah yang memicu jawaban terakhir.
  Tilt2WayDirection? get lastTriggeredDirection => _lastTriggeredDirection;

  /// Memasukkan sudut [roll] saat ini.
  ///
  /// Mengembalikan [Tilt2WayDirection] seketika pada frame pertama saat
  /// kemiringan terdeteksi. Setelah itu mengembalikan `null` sampai [reset] dipanggil.
  Tilt2WayDirection? update({required double roll}) {
    if (_isTriggered) return null;

    final detected = detect2WayTilt(roll: roll, threshold: threshold);
    if (detected != null) {
      _isTriggered = true;
      _lastTriggeredDirection = detected;
      return detected;
    }
    return null;
  }

  /// Reset status penguncian (dipanggil saat ganti soal baru atau selesai).
  void reset() {
    _isTriggered = false;
    _lastTriggeredDirection = null;
  }
}

// ============================================================
// LEGACY / 4-ARAH SUPPORT (UNTUK KOMPATIBILITAS SEJARAH & TEST LAMA)
// ============================================================

/// Sudut (derajat) minimum pada satu sumbu untuk memulai tahan jawaban.
const double kTiltEnterThreshold = 30.0;
const double kTiltExitTolerance = 10.0;
const double kTiltMaxAngle = 65.0;
const double kTiltSwitchDelta = 15.0;
const Duration kTiltHoldDuration = Duration(seconds: 3);

/// Empat arah kemiringan legacy (A/B/C/D).
enum TiltDirection {
  up,
  right,
  left,
  down;

  int get optionIndex => index;
  String get letter => String.fromCharCode(65 + index);
  String get label => switch (this) {
        TiltDirection.up => 'Atas',
        TiltDirection.right => 'Kanan',
        TiltDirection.left => 'Kiri',
        TiltDirection.down => 'Bawah',
      };
}

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

TiltDirection? detectTiltDirection({
  required double pitch,
  required double roll,
  TiltDirection? activeDirection,
}) {
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
    return null;
  }

  final sorted = candidates.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length >= 2 && sorted[0].value - sorted[1].value < kTiltSwitchDelta) {
    return null;
  }
  return sorted.first.key;
}

class TiltHoldTracker {
  TiltHoldTracker({this.holdDuration = kTiltHoldDuration});

  final Duration holdDuration;
  TiltDirection? _direction;
  DateTime? _startedAt;
  bool _locked = false;
  TiltDirection? _lockedDirection;

  TiltDirection? get direction => _direction;
  bool get isLocked => _locked;
  TiltDirection? get lockedDirection => _lockedDirection;
  DateTime? get startedAt => _startedAt;

  double progressAt(DateTime now) {
    if (_locked) return 1.0;
    final start = _startedAt;
    if (start == null) return 0.0;
    final elapsed = now.difference(start).inMilliseconds;
    if (elapsed <= 0) return 0.0;
    return (elapsed / holdDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration remainingAt(DateTime now) {
    if (_locked) return Duration.zero;
    final start = _startedAt;
    if (start == null) return holdDuration;
    final elapsed = now.difference(start);
    final left = holdDuration - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool update({required TiltDirection? detected, required DateTime now}) {
    if (_locked) return false;

    if (detected == null) {
      if (_direction == null) return false;
      _direction = null;
      _startedAt = null;
      return true;
    }

    if (detected != _direction) {
      _direction = detected;
      _startedAt = now;
      return true;
    }

    final start = _startedAt;
    if (start != null && now.difference(start) >= holdDuration) {
      _locked = true;
      _lockedDirection = detected;
      return true;
    }
    return false;
  }

  void reset() {
    _direction = null;
    _startedAt = null;
    _locked = false;
    _lockedDirection = null;
  }
}
