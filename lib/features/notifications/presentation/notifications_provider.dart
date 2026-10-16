import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_models.dart';

final notificationsListProvider = FutureProvider.autoDispose<NotificationsResponse>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getNotifications();
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifsAsync = ref.watch(notificationsListProvider);
  return notifsAsync.valueOrNull?.unreadCount ?? 0;
});

class NotificationActionNotifier extends StateNotifier<bool> {
  final NotificationsRepository _repo;
  final Ref _ref;

  NotificationActionNotifier(this._repo, this._ref) : super(false);

  Future<void> markAsRead(String id) async {
    state = true;
    try {
      await _repo.markAsRead(id);
      _ref.invalidate(notificationsListProvider);
    } finally {
      state = false;
    }
  }

  Future<void> markAllAsRead() async {
    state = true;
    try {
      await _repo.markAllAsRead();
      _ref.invalidate(notificationsListProvider);
    } finally {
      state = false;
    }
  }

  Future<int> evaluateNotifications() async {
    state = true;
    try {
      final count = await _repo.evaluateNotifications();
      _ref.invalidate(notificationsListProvider);
      return count;
    } finally {
      state = false;
    }
  }
}

final notificationActionProvider =
    StateNotifierProvider<NotificationActionNotifier, bool>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationActionNotifier(repo, ref);
});
