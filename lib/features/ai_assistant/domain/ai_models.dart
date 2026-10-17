class AiMessageModel {
  final String id;
  final String conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final List<dynamic> factsUsed;
  final String? suggestion;
  final String? voiceSummary;
  final String? audioBase64;
  final DateTime createdAt;

  const AiMessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.factsUsed = const [],
    this.suggestion,
    this.voiceSummary,
    this.audioBase64,
    required this.createdAt,
  });

  factory AiMessageModel.fromJson(Map<String, dynamic> json) {
    final structured = json['structured'] as Map<String, dynamic>?;
    return AiMessageModel(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      factsUsed: json['facts_used'] as List<dynamic>? ?? [],
      suggestion: structured?['suggestion'] as String?,
      voiceSummary: (json['voice_summary'] as String?) ?? (structured?['voice_summary'] as String?),
      audioBase64: (json['audio_base64'] as String?) ?? (structured?['audio_base64'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'facts_used': factsUsed,
      'suggestion': suggestion,
      'voice_summary': voiceSummary,
      'audio_base64': audioBase64,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => role == 'user';
}
