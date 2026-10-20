import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/ai_assistant/data/ai_repository.dart';
import 'package:arus/features/ai_assistant/domain/ai_models.dart';
import 'package:arus/features/ai_assistant/domain/voice_models.dart';
import 'package:arus/features/ai_assistant/presentation/ai_home_screen.dart';

class MockVoiceAiRepository implements AiRepository {
  @override
  Future<PriceRecommendation> recommendPrice({
    required String menuName,
    required int totalCogsIdr,
    required List<Map<String, dynamic>> recipes,
  }) async {
    return PriceRecommendation(
      recommendedPrice: 25000,
      marginPercentage: 40,
      reasoning: 'Rekomendasi harga test.',
    );
  }

  @override
  Future<AiMessageModel> sendMessage({
    String? conversationId,
    required String message,
    String? outletId,
    String? screenContext,
  }) async {
    return AiMessageModel(
      id: 'voice-msg-1',
      conversationId: 'conv-voice-123',
      role: 'assistant',
      content: 'Laporan hari ini menunjukkan performa toko sangat optimal.',
      voiceSummary: 'Performa toko sangat optimal dengan penjualan stabil.',
      audioBase64: 'fake_mp3_base64_data',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<String> getTtsAudio(String text) async {
    return 'fake_tts_base64_data';
  }

  @override
  Future<List<AiMessageModel>> getConversationMessages(String conversationId) async {
    return [
      AiMessageModel(
        id: 'voice-msg-history-1',
        conversationId: conversationId,
        role: 'assistant',
        content: 'Riwayat percakapan tersimpan dari test.',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  group('ARUS Voice & STT Flow Widget Tests (Specification Verification)', () {
    test('AiMessageModel mendukung voiceSummary dan audioBase64', () {
      final msg = AiMessageModel(
        id: 'msg-1',
        conversationId: 'c1',
        role: 'assistant',
        content: 'Konten lengkap laporan',
        voiceSummary: 'Ringkasan suara',
        audioBase64: 'base64audio',
        createdAt: DateTime.now(),
      );

      expect(msg.voiceSummary, equals('Ringkasan suara'));
      expect(msg.audioBase64, equals('base64audio'));

      final json = msg.toJson();
      expect(json['voice_summary'], equals('Ringkasan suara'));
      expect(json['audio_base64'], equals('base64audio'));

      final fromJson = AiMessageModel.fromJson(json);
      expect(fromJson.voiceSummary, equals('Ringkasan suara'));
      expect(fromJson.audioBase64, equals('base64audio'));
    });

    test('VoiceSessionState mendefinisikan 4 status sesi', () {
      expect(VoiceSessionState.values.length, equals(4));
      expect(VoiceSessionState.idle.name, equals('idle'));
      expect(VoiceSessionState.listening.name, equals('listening'));
      expect(VoiceSessionState.processingFiller.name, equals('processingFiller'));
      expect(VoiceSessionState.speakingResult.name, equals('speakingResult'));
    });

    testWidgets('Dynamic Input Bar: icon aksi berubah antara Voice Mode dan Kirim Pesan', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(MockVoiceAiRepository()),
          ],
          child: const MaterialApp(
            home: AiHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Saat input teks kosong:
      // Harus ada Mic STT dictation icon dan button mode suara (graphic_eq_rounded)
      final micDictation = find.byIcon(Icons.mic_none_rounded);
      expect(micDictation, findsOneWidget);

      final voiceModeBtn = find.byIcon(Icons.graphic_eq_rounded);
      expect(voiceModeBtn, findsOneWidget);

      // Ketik teks ke dalam TextField
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Halo ARUS AI');
      await tester.pump();

      // Sekarang tombol aksi berubah menjadi tombol kirim (arrow_upward_rounded)
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);

      // Kosongkan kembali teks
      await tester.enterText(textField, '');
      await tester.pump();

      // Tombol kembali ke mode suara (graphic_eq_rounded)
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    });

    testWidgets('Transisi ke ARUS Voice Mode dan kembali ke Text Mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(MockVoiceAiRepository()),
          ],
          child: const MaterialApp(
            home: AiHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Klik tombol masuk ARUS Voice Mode (graphic_eq_rounded)
      final voiceModeBtn = find.byIcon(Icons.graphic_eq_rounded);
      await tester.tap(voiceModeBtn);
      await tester.pumpAndSettle();

      // Verifikasi masuk ke layar ARUS Voice Mode
      expect(find.text('ARUS Voice Mode'), findsOneWidget);
      expect(find.text('Siap Berbicara'), findsOneWidget);
      expect(find.textContaining('Tahan tombol di bawah untuk berbicara'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Klik close untuk kembali ke percakapan teks
      final backToChatBtn = find.byIcon(Icons.close_rounded);
      await tester.tap(backToChatBtn);
      await tester.pumpAndSettle();

      // Verifikasi kembali ke normal chat mode
      expect(find.text('Asisten AI Bisnis'), findsOneWidget);
      expect(find.text('ARUS Voice Mode'), findsNothing);
    });
  });
}
