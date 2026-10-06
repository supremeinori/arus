class NotificationModel {
  final String id;
  final String userId;
  final String type; // low_stock, sales_change, target_achieved, periodic_summary, system
  final String priority; // low, normal, high
  final String title;
  final String body;
  final Map<String, dynamic>? payload;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    this.payload,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      priority: json['priority'] as String? ?? 'normal',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class NotificationsResponse {
  final int unreadCount;
  final List<NotificationModel> notifications;

  const NotificationsResponse({
    this.unreadCount = 0,
    this.notifications = const [],
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['notifications'] as List<dynamic>? ?? [];
    return NotificationsResponse(
      unreadCount: json['unread_count'] as int? ?? 0,
      notifications: rawList
          .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
