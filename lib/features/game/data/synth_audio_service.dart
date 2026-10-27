import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Layanan sintesis audio prosedural murni dengan vibe synthesizer 80s/retro.
///
/// Menghasilkan byte format RIFF WAV 16-bit PCM secara in-memory tanpa
/// memerlukan aset suara eksternal atau koneksi internet.
class SynthAudioService {
  SynthAudioService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool _isMuted = false;

  /// Status apakah suara di-mute
  bool get isMuted => _isMuted;
  set isMuted(bool val) => _isMuted = val;

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  // Pre-cached WAV sound bytes untuk performa instan tanpa latensi
  Uint8List? _correctWav;
  Uint8List? _wrongWav;
  final Map<int, Uint8List> _comboWavs = {};
  Uint8List? _gameOverWav;

  /// Memutar sound effect jawaban benar (Arpeggio nada synth cerah C5-E5-G5-C6)
  Future<void> playCorrect() async {
    if (_isMuted) return;
    try {
      _correctWav ??= SynthWaveGenerator.buildCorrectSound();
      await _player.stop();
      await _player.play(BytesSource(_correctWav!));
    } catch (e) {
      debugPrint('[SynthAudio] Gagal memutar nada benar: $e');
    }
  }

  /// Memutar sound effect jawaban salah (Retro dissonant buzz drop)
  Future<void> playWrong() async {
    if (_isMuted) return;
    try {
      _wrongWav ??= SynthWaveGenerator.buildWrongSound();
      await _player.stop();
      await _player.play(BytesSource(_wrongWav!));
    } catch (e) {
      debugPrint('[SynthAudio] Gagal memutar nada salah: $e');
    }
  }

  /// Memutar sound effect combo beruntun (Futuristic laser power-up sweep,
  /// dengan frekuensi semakin tinggi seiring naiknya level combo)
  Future<void> playCombo(int comboCount) async {
    if (_isMuted) return;
    try {
      final clamped = comboCount.clamp(1, 10);
      _comboWavs[clamped] ??= SynthWaveGenerator.buildComboSound(clamped);
      await _player.stop();
      await _player.play(BytesSource(_comboWavs[clamped]!));
    } catch (e) {
      debugPrint('[SynthAudio] Gagal memutar nada combo: $e');
    }
  }

  /// Memutar sound effect selesai permainan (Retro synth victory jingle)
  Future<void> playGameOver() async {
    if (_isMuted) return;
    try {
      _gameOverWav ??= SynthWaveGenerator.buildGameOverSound();
      await _player.stop();
      await _player.play(BytesSource(_gameOverWav!));
    } catch (e) {
      debugPrint('[SynthAudio] Gagal memutar nada game over: $e');
    }
  }

  void dispose() {
    try {
      _player.stop();
      _player.dispose();
    } catch (_) {}
  }
}

/// Mesin pembangun gelombang audio WAV (RIFF header + 16-bit PCM Mono)
class SynthWaveGenerator {
  static const int sampleRate = 22050; // 22.05 kHz audio

  /// Generator gelombang dasar
  static double _sine(double phase) => math.sin(phase);
  static double _sawtooth(double phase) =>
      2.0 * (phase / (2 * math.pi) - (phase / (2 * math.pi) + 0.5).floor());
  static double _square(double phase) => math.sin(phase) >= 0 ? 0.7 : -0.7;

  /// SFX 1: Jawaban Benar (Arpeggio 4-nada synth cerah: C5 -> E5 -> G5 -> C6)
  static Uint8List buildCorrectSound() {
    final notes = [
      (523.25, 0.06), // C5
      (659.25, 0.06), // E5
      (783.99, 0.07), // G5
      (1046.50, 0.16), // C6
    ];

    final samples = <double>[];
    for (final (freq, dur) in notes) {
      final count = (sampleRate * dur).round();
      for (int i = 0; i < count; i++) {
        final t = i / sampleRate;
        final progress = i / count;
        // Envelope: attack cepat, decay lembut
        final env = (1.0 - progress) * (1.0 - math.exp(-i / 100));
        // Gabungan gelombang sine + harmonik triangle untuk timbre synth hangat
        final phase = 2 * math.pi * freq * t;
        final wave = 0.7 * _sine(phase) + 0.3 * _sine(phase * 2);
        samples.add(wave * env * 0.75);
      }
    }
    return _encodeWav(samples);
  }

  /// SFX 2: Jawaban Salah (Dissonant saw-wave retro buzz drop)
  static Uint8List buildWrongSound() {
    const dur = 0.30; // 300 ms
    final count = (sampleRate * dur).round();
    final samples = <double>[];

    for (int i = 0; i < count; i++) {
      final t = i / sampleRate;
      final progress = i / count;
      // Frekuensi turun drastis dari 200 Hz ke 65 Hz
      final freq = 200.0 - (135.0 * progress);
      // Tremolo/buzz cepat 35 Hz
      final buzz = 0.5 + 0.5 * math.sin(2 * math.pi * 35 * t);
      final phase = 2 * math.pi * freq * t;
      final wave = 0.6 * _sawtooth(phase) + 0.4 * _square(phase);
      final env = (1.0 - progress * 0.9);
      samples.add(wave * env * buzz * 0.65);
    }
    return _encodeWav(samples);
  }

  /// SFX 3: Combo (Futuristic laser power-up sweep, frekuensi naik seiring combo)
  static Uint8List buildComboSound(int comboCount) {
    const dur = 0.22;
    final count = (sampleRate * dur).round();
    final samples = <double>[];

    // Base pitch naik seiring combo (combo 1 = 600 Hz, combo 5+ = 1200+ Hz)
    final baseFreq = 500.0 + (comboCount * 140.0);
    final targetFreq = baseFreq * 1.7;

    for (int i = 0; i < count; i++) {
      final progress = i / count;
      // Pitch slide melengkung ke atas
      final currentFreq = baseFreq + (targetFreq - baseFreq) * math.pow(progress, 0.7);
      final t = i / sampleRate;
      final phase = 2 * math.pi * currentFreq * t;
      final wave = 0.75 * _sine(phase) + 0.25 * _sawtooth(phase * 1.5);
      final env = math.sin(progress * math.pi) * 0.8;
      samples.add(wave * env);
    }
    return _encodeWav(samples);
  }

  /// SFX 4: Game Over (Retro Synth Victory Fanfare)
  static Uint8List buildGameOverSound() {
    final notes = [
      (440.0, 0.08), // A4
      (554.37, 0.08), // C#5
      (659.25, 0.08), // E5
      (880.0, 0.28), // A5
    ];

    final samples = <double>[];
    for (final (freq, dur) in notes) {
      final count = (sampleRate * dur).round();
      for (int i = 0; i < count; i++) {
        final t = i / sampleRate;
        final progress = i / count;
        // Vibrato lembut di ujung nada
        final vibrato = math.sin(2 * math.pi * 6.0 * t) * (progress * 8.0);
        final phase = 2 * math.pi * (freq + vibrato) * t;
        final env = math.exp(-progress * 2.5);
        final wave = 0.8 * _sine(phase) + 0.2 * _square(phase);
        samples.add(wave * env * 0.75);
      }
    }
    return _encodeWav(samples);
  }

  /// Membungkus array sampel amplitudo (-1.0 s/d 1.0) menjadi file WAV 16-bit PCM Little Endian
  static Uint8List _encodeWav(List<double> samples) {
    final numSamples = samples.length;
    final subChunk2Size = numSamples * 2; // 16-bit mono = 2 bytes per sample
    final chunkSize = 36 + subChunk2Size;

    final byteData = ByteData(44 + subChunk2Size);

    // RIFF Header
    _writeString(byteData, 0, 'RIFF');
    byteData.setUint32(4, chunkSize, Endian.little);
    _writeString(byteData, 8, 'WAVE');

    // fmt subchunk
    _writeString(byteData, 12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    byteData.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    byteData.setUint32(24, sampleRate, Endian.little); // SampleRate
    byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate (SampleRate * 1 * 2)
    byteData.setUint16(32, 2, Endian.little); // BlockAlign (1 * 2)
    byteData.setUint16(34, 16, Endian.little); // BitsPerSample (16 bits)

    // data subchunk
    _writeString(byteData, 36, 'data');
    byteData.setUint32(40, subChunk2Size, Endian.little);

    // Write 16-bit PCM samples
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final s = samples[i].clamp(-1.0, 1.0);
      final pcm16 = (s * 32767.0).round().clamp(-32768, 32767);
      byteData.setInt16(offset, pcm16, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static void _writeString(ByteData byteData, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      byteData.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
