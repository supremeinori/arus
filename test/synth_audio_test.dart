import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/game/data/synth_audio_service.dart';
import 'package:arus/features/game/domain/tilt_direction.dart';

void main() {
  group('Procedural Synth Wave Generator Tests', () {
    test('SynthWaveGenerator menghasilkan WAV header RIFF 16-bit PCM yang valid untuk SFX Benar', () {
      final wavBytes = SynthWaveGenerator.buildCorrectSound();

      expect(wavBytes.length, greaterThan(44));
      // Verifikasi RIFF Header
      final header = String.fromCharCodes(wavBytes.sublist(0, 4));
      expect(header, 'RIFF');
      final format = String.fromCharCodes(wavBytes.sublist(8, 12));
      expect(format, 'WAVE');
      final subchunk1 = String.fromCharCodes(wavBytes.sublist(12, 16));
      expect(subchunk1, 'fmt ');

      final byteData = ByteData.sublistView(wavBytes);
      final audioFormat = byteData.getUint16(20, Endian.little);
      expect(audioFormat, 1); // 1 = PCM
      final numChannels = byteData.getUint16(22, Endian.little);
      expect(numChannels, 1); // 1 = Mono
      final sampleRate = byteData.getUint32(24, Endian.little);
      expect(sampleRate, 22050);
      final bitsPerSample = byteData.getUint16(34, Endian.little);
      expect(bitsPerSample, 16); // 16-bit
    });

    test('SynthWaveGenerator menghasilkan format WAV valid untuk SFX Salah, Combo, dan Game Over', () {
      final wrongWav = SynthWaveGenerator.buildWrongSound();
      expect(String.fromCharCodes(wrongWav.sublist(0, 4)), 'RIFF');
      expect(wrongWav.length, greaterThan(1000));

      final combo1 = SynthWaveGenerator.buildComboSound(1);
      final combo5 = SynthWaveGenerator.buildComboSound(5);
      expect(String.fromCharCodes(combo1.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(combo5.sublist(0, 4)), 'RIFF');

      final gameOver = SynthWaveGenerator.buildGameOverSound();
      expect(String.fromCharCodes(gameOver.sublist(0, 4)), 'RIFF');
    });
  });

  group('2-Way Instant Gyroscope Tilt & Debounce Tests', () {
    test('detect2WayTilt memetakan roll negatif ke Kiri dan roll positif ke Kanan', () {
      // Netral (sudut kecil)
      expect(detect2WayTilt(roll: 0), isNull);
      expect(detect2WayTilt(roll: 10), isNull);
      expect(detect2WayTilt(roll: -10), isNull);

      // Miring KIRI (roll <= -22)
      expect(detect2WayTilt(roll: -25), Tilt2WayDirection.left);
      expect(detect2WayTilt(roll: -45), Tilt2WayDirection.left);

      // Miring KANAN (roll >= 22)
      expect(detect2WayTilt(roll: 25), Tilt2WayDirection.right);
      expect(detect2WayTilt(roll: 45), Tilt2WayDirection.right);
    });

    test('TiltInstantTrigger memicu respon instan sekali dan mendebounce trigger berulang', () {
      final trigger = TiltInstantTrigger(threshold: 20.0);

      expect(trigger.isTriggered, isFalse);
      expect(trigger.lastTriggeredDirection, isNull);

      // Posisi netral -> belum ada trigger
      expect(trigger.update(roll: 5), isNull);
      expect(trigger.isTriggered, isFalse);

      // Miring Kiri pertama kali -> picu instan!
      final firstTrigger = trigger.update(roll: -25);
      expect(firstTrigger, Tilt2WayDirection.left);
      expect(trigger.isTriggered, isTrue);
      expect(trigger.lastTriggeredDirection, Tilt2WayDirection.left);

      // Sampel berikutnya (meskipun masih miring atau berubah) diabaikan (debounce)
      expect(trigger.update(roll: -30), isNull);
      expect(trigger.update(roll: 35), isNull);
      expect(trigger.lastTriggeredDirection, Tilt2WayDirection.left);

      // Reset untuk soal baru -> siap mendeteksi trigger baru
      trigger.reset();
      expect(trigger.isTriggered, isFalse);
      expect(trigger.lastTriggeredDirection, isNull);

      // Miring Kanan pada soal baru -> picu instan Kanan
      final nextTrigger = trigger.update(roll: 30);
      expect(nextTrigger, Tilt2WayDirection.right);
      expect(trigger.isTriggered, isTrue);
    });
  });
}
