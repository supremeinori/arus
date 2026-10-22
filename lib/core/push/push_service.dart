import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_assistant/presentation/ai_provider.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/notifications/presentation/notifications_provider.dart';
import '../network/api_client.dart';
import '../routing/app_router.dart';
import 'notification_service.dart';

/// Handler background (app di background / terminated).
///
/// Notifikasi dengan payload `notification` sudah ditampilkan oleh sistem
/// Android lewat channel importance tinggi, jadi handler ini tidak
/// menampilkan notifikasi kedua. Hanya pesan data-only yang ditampilkan
/// manual lewat [NotificationService].
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');

  // Payload `notification` sudah ditampilkan sistem (channel high importance).
  if (message.notification != null) return;

  final title = message.data['title'] ?? 'ARUS';
  final body = message.data['body'] ?? message.data['message'] ?? '';
  if (body.isEmpty) return;

  await NotificationService.instance.show(
    title: title,
    body: body,
    requestPermissionIfMissing: false,
  );
}

/// Opsi Firebase dari --dart-define (dipakai bila google-services.json belum ada).
FirebaseOptions? _optionsFromEnvironment() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  if (apiKey.isEmpty ||
      appId.isEmpty ||
      projectId.isEmpty ||
      senderId.isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}

/// Layanan push notifikasi (FCM).
///
/// Aman ketika kredensial Firebase belum tersedia: [initialize] tidak melempar
/// error, [isEnabled] bernilai false, dan aplikasi tetap berjalan normal.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  Future<void> initialize() async {
    try {
      final options = _optionsFromEnvironment();
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      _enabled = true;
    } catch (err) {
      _enabled = false;
      debugPrint('[Push] Firebase belum dikonfigurasi, push nonaktif: $err');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (err) {
      debugPrint('[Push] Permission request gagal: $err');
    }

    // Registration token FCM (bukan FID). Backend firebase-admin v13 memakai
    // field `tokens` pada sendEachForMulticast, jadi token klasik dipakai.
    // ignore: deprecated_member_use
    messaging.onTokenRefresh.listen((token) {
      unawaited(registerDeviceToken());
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _handleOpenedMessage(initial);
      }
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await registerDeviceToken();
      }
    } catch (err) {
      debugPrint('[Push] Gagal ambil token: $err');
    }
  }

  /// Mendaftarkan token perangkat ke backend.
  /// Hanya berhasil bila user sudah login (butuh access token).
  Future<void> registerDeviceToken() async {
    if (!_enabled) return;

    final authState = _ref.read(authProvider);
    if (!authState.isAuthenticated) return;

    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final client = _ref.read(apiClientProvider);
      await client.post<Map<String, dynamic>>(
        '/notifications/device-token',
        data: {'token': token, 'platform': 'android'},
      );
    } catch (err) {
      debugPrint('[Push] Registrasi device token gagal: $err');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Push] Foreground message: ${message.messageId}');
    _invalidateInbox();

    // FCM tidak menampilkan notifikasi saat aplikasi di foreground, jadi
    // notifikasi sistem (heads-up + suara) dibuat manual di sini.
    unawaited(_showSystemNotification(message));
  }

  Future<void> _showSystemNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'] ?? '';
    if (title == null || title.isEmpty) return;

    final shown = await NotificationService.instance.show(
      title: title,
      body: body,
    );
    if (shown) return;

    // Notifikasi sistem tidak bisa ditampilkan (mis. permission ditolak),
    // pakai banner in-app sebagai cadangan.
    _showForegroundBanner(title, body);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'ai_result') {
      final chatLogId = data['chat_log_id'];
      if (chatLogId != null && chatLogId.isNotEmpty) {
        _ref.read(aiPendingConversationProvider.notifier).state = chatLogId;
      }
      _ref.read(routerProvider).go('/ai');
      return;
    }

    if (type == 'low_stock') {
      _ref.read(routerProvider).go('/inventory');
      return;
    }

    _ref.read(routerProvider).go('/notifications');
  }

  void _invalidateInbox() {
    try {
      _ref.invalidate(notificationsListProvider);
    } catch (_) {}
  }

  void _showForegroundBanner(String title, String body) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title — $body')));
    } catch (_) {
      // Tidak ada ScaffoldMessenger aktif, abaikan.
    }
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(ref);

  // Daftarkan ulang token setiap kali user masuk.
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (next.isAuthenticated && previous?.isAuthenticated != true) {
      unawaited(service.registerDeviceToken());
    }
  });

  unawaited(service.initialize());

  return service;
});
