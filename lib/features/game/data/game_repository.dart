import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GameRepository(apiClient);
});

class GameQuestionOption {
  final String key;
  final String label;
  final String value;

  GameQuestionOption({
    required this.key,
    required this.label,
    required this.value,
  });

  factory GameQuestionOption.fromJson(Map<String, dynamic> json) {
    return GameQuestionOption(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }
}

class GameQuestionModel {
  final int questionNo;
  final String productId;
  final String imageUrl;
  final String categoryName;
  final String promptTitle;
  final List<GameQuestionOption> options;
  final String correctOptionKey;

  GameQuestionModel({
    required this.questionNo,
    required this.productId,
    required this.imageUrl,
    required this.categoryName,
    required this.promptTitle,
    required this.options,
    required this.correctOptionKey,
  });

  factory GameQuestionModel.fromJson(Map<String, dynamic> json) {
    return GameQuestionModel(
      questionNo: json['question_no'] as int? ?? 1,
      productId: json['product_id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      promptTitle: json['prompt_title'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => GameQuestionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      correctOptionKey: json['correct_option_key'] as String? ?? '',
    );
  }
}

class GameSessionRecord {
  final String id;
  final String mode;
  final int score;
  final int correctCount;
  final int totalQuestions;
  final int durationSec;
  final DateTime playedAt;

  GameSessionRecord({
    required this.id,
    required this.mode,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.durationSec,
    required this.playedAt,
  });

  factory GameSessionRecord.fromJson(Map<String, dynamic> json) {
    return GameSessionRecord(
      id: json['id'] as String? ?? '',
      mode: json['mode'] as String? ?? 'guess_name',
      score: json['score'] as int? ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 5,
      durationSec: json['duration_sec'] as int? ?? 0,
      playedAt: DateTime.tryParse(json['played_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class UserGameStats {
  final int bestGuessName;
  final int bestGuessPrice;
  final int totalGamesPlayed;
  final List<GameSessionRecord> recentSessions;

  UserGameStats({
    required this.bestGuessName,
    required this.bestGuessPrice,
    required this.totalGamesPlayed,
    required this.recentSessions,
  });

  factory UserGameStats.fromJson(Map<String, dynamic> json) {
    final highScores = json['high_scores'] as Map<String, dynamic>? ?? {};
    final recents = (json['recent_sessions'] as List<dynamic>? ?? [])
        .map((e) => GameSessionRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    return UserGameStats(
      bestGuessName: highScores['guess_name'] as int? ?? 0,
      bestGuessPrice: highScores['guess_price'] as int? ?? 0,
      totalGamesPlayed: json['total_games_played'] as int? ?? 0,
      recentSessions: recents,
    );
  }
}

class GameRepository {
  final ApiClient _apiClient;

  GameRepository(this._apiClient);

  Future<List<GameQuestionModel>> fetchQuestions({required String mode, int limit = 5}) async {
    final response = await _apiClient.get(
      '/game/questions',
      queryParameters: {'mode': mode, 'limit': limit},
    );

    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['questions'] as List<dynamic>? ?? [];

    return list.map((e) => GameQuestionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> submitSession({
    required String mode,
    required int score,
    required int correctCount,
    required int totalQuestions,
    required int durationSec,
  }) async {
    final response = await _apiClient.post(
      '/game/sessions',
      data: {
        'mode': mode,
        'score': score,
        'correct_count': correctCount,
        'total_questions': totalQuestions,
        'duration_sec': durationSec,
      },
    );

    return response.data['data'] as Map<String, dynamic>? ?? {};
  }

  Future<UserGameStats> fetchUserStats() async {
    final response = await _apiClient.get('/game/sessions/me');
    final data = response.data['data'] as Map<String, dynamic>;
    return UserGameStats.fromJson(data);
  }
}
