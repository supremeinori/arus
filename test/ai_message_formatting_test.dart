import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arus/features/ai_assistant/data/ai_repository.dart';
import 'package:arus/features/ai_assistant/domain/ai_models.dart';
import 'package:arus/features/ai_assistant/presentation/ai_home_screen.dart';
import 'package:arus/features/auth/domain/user_model.dart';
import 'package:arus/features/auth/presentation/auth_provider.dart';
import 'package:arus/features/auth/presentation/auth_state.dart';
import 'package:arus/features/auth/data/auth_repository.dart';
import 'package:arus/core/storage/secure_store.dart';

const ownerUser = UserModel(
  id: 'u-owner-1',
  name: 'Rina Owner',
  email: 'owner@arus.demo',
  role: UserRole.owner,
);

class FormattingFakeAiRepository implements AiRepository {
  @override
  Future<PriceRecommendation> recommendPrice({
    required String menuName,
    required int totalCogsIdr,
    required List<Map<String, dynamic>> recipes,
  }) async {
    return const PriceRecommendation(
      recommendedPrice: 20000,
      marginPercentage: 50,
      reasoning: 'Rekomendasi.',
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
      id: 'msg-test-formatting-1',
      conversationId: 'conv-fmt-1',
      role: 'assistant',
      content:
          'Berikut adalah laporan:\n\n'
          '* **Total Omset:** **Rp 2.500.000**\n'
          '* **Transaksi Selesai:** 45 transaksi\n'
          'Saran: Tingkatkan promosi bundling.\n\n'
          '[VOICE_SUMMARY]: Omset hari ini 2,5 juta rupiah.',
      factsUsed: const ['demo_db'],
      suggestion: 'Tawarkan menu bundling',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<String> getTtsAudio(String text) async => '';

  @override
  Future<List<AiMessageModel>> getConversationMessages(String conversationId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Message Markdown Formatting & Copy Functionality Tests', () {
    testWidgets('Respon LLM menghilangkan bintang mentah, menampilkan bold, dan tombol salin berfungsi', (tester) async {
      final log = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier(
                ref.watch(authRepositoryProvider),
                ref.watch(secureStoreProvider),
              );
              notifier.state = AuthState.authenticated(ownerUser);
              return notifier;
            }),
            aiRepositoryProvider.overrideWithValue(FormattingFakeAiRepository()),
          ],
          child: const MaterialApp(
            home: AiHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Klik quick prompt untuk mentrigger pesan (Owner version)
      final promptBtn = find.text('Bagaimana ringkasan penjualan semua cabang kemarin?');
      expect(promptBtn, findsOneWidget);
      await tester.tap(promptBtn);

      await tester.pumpAndSettle();

      // Verifikasi pesan asisten muncul dan berisi teks yang diharapkan
      expect(find.textContaining('Total Omset:'), findsOneWidget);
      expect(find.textContaining('Rp 2.500.000'), findsOneWidget);

      // Verifikasi [VOICE_SUMMARY] tidak bocor ke teks tampilan layar
      expect(find.textContaining('[VOICE_SUMMARY]'), findsNothing);

      // Verifikasi tombol Salin (Copy) hadir pada bubble AI
      final copyBtn = find.text('Salin');
      expect(copyBtn, findsOneWidget);

      // Klik tombol Salin
      await tester.tap(copyBtn);
      await tester.pump();

      // Verifikasi status tombol berubah menjadi 'Tersalin'
      expect(find.text('Tersalin'), findsOneWidget);

      // Verifikasi Clipboard menerima teks bersih tanpa hama asteris dan tanpa VOICE_SUMMARY
      final clipboardCalls = log.where((call) => call.method == 'Clipboard.setData').toList();
      expect(clipboardCalls.isNotEmpty, isTrue);

      final clipboardData = clipboardCalls.last.arguments as Map<dynamic, dynamic>;
      final copiedText = clipboardData['text'] as String;

      // Pastikan hasil copy bersih dari asteris mentah
      expect(copiedText.contains('**'), isFalse);
      expect(copiedText.contains('[VOICE_SUMMARY]'), isFalse);
      expect(copiedText.contains('Total Omset: Rp 2.500.000'), isTrue);
      expect(copiedText.contains('Transaksi Selesai: 45 transaksi'), isTrue);

      // Tunggu timer reset selesai
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
