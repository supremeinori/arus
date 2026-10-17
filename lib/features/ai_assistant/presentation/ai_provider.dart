import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ai_repository.dart';
import '../domain/ai_models.dart';

class AiChatState {
  final List<AiMessageModel> messages;
  final String? conversationId;
  final bool isLoading;
  final String? errorMessage;

  const AiChatState({
    this.messages = const [],
    this.conversationId,
    this.isLoading = false,
    this.errorMessage,
  });

  AiChatState copyWith({
    List<AiMessageModel>? messages,
    String? conversationId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AiChatNotifier extends StateNotifier<AiChatState> {
  final AiRepository _repository;

  AiChatNotifier(this._repository) : super(const AiChatState());

  Future<AiMessageModel?> sendMessage(String text, {String? outletId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final userMsg = AiMessageModel(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: state.conversationId ?? '',
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      errorMessage: null,
    );

    try {
      final aiMsg = await _repository.sendMessage(
        conversationId: state.conversationId,
        message: trimmed,
        outletId: outletId,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        conversationId: aiMsg.conversationId.isNotEmpty ? aiMsg.conversationId : state.conversationId,
        isLoading: false,
      );
      return aiMsg;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mendapatkan respon AI: $e',
      );
      return null;
    }
  }

  void startNewChat() {
    state = const AiChatState();
  }
}

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((ref) {
  final repo = ref.watch(aiRepositoryProvider);
  return AiChatNotifier(repo);
});

/// Handoff prompt dari MenuCreate → AI Chat (auto-fill & auto-submit).
final aiPendingPromptProvider = StateProvider<String?>((ref) => null);
