class AiMessageModel {
  final String id;
  final String conversationId;
  final String role; // 'user' | 'assistant'
  final String content;
  final List<dynamic> factsUsed;
  final String? suggestion;
  final DateTime createdAt;

  const AiMessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.factsUsed = const [],
    this.suggestion,
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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  bool get isUser => role == 'user';
}
