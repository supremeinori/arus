import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push/notification_service.dart';

/// Tombol sementara untuk menguji notifikasi sistem Android
/// (heads-up di atas layar + suara).
///
/// Widget ini sengaja terisolasi di satu file: menghapus pemanggilannya di
/// halaman langsung menghilangkan tombol tanpa menyentuh sistem notifikasi
/// push. Notifikasi yang ditampilkan memakai [NotificationService] yang sama
/// dengan push FCM, jadi hasil uji sama dengan notifikasi push sungguhan.
class TestPushNotificationButton extends ConsumerWidget {
  const TestPushNotificationButton({super.key});

  static const String testTitle = 'Test Push Notification';
  static const String testBody =
      'Notifikasi uji ARUS. Seharusnya muncul heads-up di bagian atas layar.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          icon: const Icon(Icons.notifications_active_outlined, size: 18),
          label: const Text(
            testTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onPressed: () => _sendTestNotification(context, ref),
        ),
      ),
    );
  }

  Future<void> _sendTestNotification(BuildContext context, WidgetRef ref) async {
    final shown = await ref.read(notificationServiceProvider).show(
          title: testTitle,
          body: testBody,
        );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? 'Notifikasi uji dikirim. Cek heads-up di bagian atas layar.'
              : 'Notifikasi tidak bisa ditampilkan. Aktifkan notifikasi ARUS di pengaturan sistem.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
