import 'package:flutter/material.dart';
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

class FakeAiRepository implements AiRepository {
  @override
  Future<PriceRecommendation> recommendPrice({
    required String menuName,
    required int totalCogsIdr,
    required List<Map<String, dynamic>> recipes,
  }) async {
    return PriceRecommendation(
      recommendedPrice: (totalCogsIdr * 1.5).round(),
      marginPercentage: 50,
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
      id: 'msg-ai-1',
      conversationId: 'conv-123',
      role: 'assistant',
      content: 'Penjualan hari ini mencapai Rp 1.500.000 dengan margin stabil 35%.',
      factsUsed: [
        {'type': 'sales_summary', 'total_revenue': 1500000}
      ],
      suggestion: 'Tingkatkan stok espresso blend',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<String> getTtsAudio(String text) async {
    return 'fake_audio_base64_data';
  }

  @override
  Future<List<AiMessageModel>> getConversationMessages(String conversationId) async {
    return [
      AiMessageModel(
        id: 'msg-ai-history-1',
        conversationId: conversationId,
        role: 'assistant',
        content: 'Riwayat percakapan tersimpan dari test.',
        createdAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  group('AI Assistant Flow Widget Tests (Milestone 9)', () {
    testWidgets('AiHomeScreen menampilkan state awal dan quick prompt buttons', (tester) async {
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
            aiRepositoryProvider.overrideWithValue(FakeAiRepository()),
          ],
          child: const MaterialApp(
            home: AiHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Asisten AI Bisnis'), findsOneWidget);
      expect(find.text('ARUS AI Decision Support'), findsOneWidget);
      expect(find.text('Bagaimana ringkasan penjualan semua cabang kemarin?'), findsOneWidget);
      expect(find.text('Bandingkan performa antarcabang saat ini'), findsOneWidget);
    });

    testWidgets('AiHomeScreen mengirim pesan prompt dan menampilkan respon asisten berbasis fakta grounded', (tester) async {
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
            aiRepositoryProvider.overrideWithValue(FakeAiRepository()),
          ],
          child: const MaterialApp(
            home: AiHomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Klik salah satu prompt cepat (Owner version)
      final promptBtn = find.text('Bagaimana ringkasan penjualan semua cabang kemarin?');
      expect(promptBtn, findsOneWidget);
      await tester.tap(promptBtn);

      await tester.pumpAndSettle();

      // Memastikan pesan user dan pesan assistant muncul
      expect(find.text('Bagaimana ringkasan penjualan semua cabang kemarin?'), findsOneWidget);
      expect(find.textContaining('Penjualan hari ini mencapai Rp 1.500.000'), findsOneWidget);
      expect(find.textContaining('Grounded Fact: 1 fakta database'), findsOneWidget);
      expect(find.textContaining('Tingkatkan stok espresso blend'), findsOneWidget);
    });
  });
}
