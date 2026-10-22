import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Id channel notifikasi ARUS.
///
/// Channel dibuat dengan importance tinggi supaya notifikasi muncul sebagai
/// heads-up di bagian atas layar dan berbunyi. Id yang sama dipakai FCM lewat
/// meta-data `com.google.firebase.messaging.default_notification_channel_id`
/// di AndroidManifest.xml, sehingga notifikasi yang ditampilkan sistem saat
/// aplikasi berada di background/ditutup juga memakai channel ini.
const String kArusNotificationChannelId = 'arus_push_high';

/// Nama channel yang tampil di pengaturan notifikasi Android.
const String kArusNotificationChannelName = 'Notifikasi ARUS';

/// Deskripsi channel.
const String kArusNotificationChannelDescription =
    'Notifikasi penting ARUS (heads-up + suara)';

/// Versi definisi channel. Naikkan kalau importance/sound/nama channel
/// berubah — importance dan sound channel tidak bisa diubah setelah channel
/// dibuat, jadi channel versi lama dibuang lalu dibuat ulang dengan definisi
/// baru.
const int _channelDefinitionVersion = 1;

const String _channelVersionKey = 'notif_channel_definition_version';

/// Layanan notifikasi sistem Android (heads-up + suara).
///
/// Satu-satunya sumber tampilan notifikasi di aplikasi: dipakai push FCM
/// (foreground/background) maupun tombol uji, sehingga tidak ada dua sistem
/// notifikasi yang berjalan bersamaan.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  int _sequence = 0;

  /// Instance yang dipakai runtime aplikasi.
  static final NotificationService instance = NotificationService();

  /// Inisialisasi plugin dan buat channel dengan importance tinggi.
  ///
  /// Aman dipanggil berulang dan aman dipanggil saat plugin tidak tersedia
  /// (mis. pada unit test) — error ditelan dan dicatat ke log.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _createChannel();
      _initialized = true;
    } catch (err) {
      debugPrint('[Notif] Inisialisasi notifikasi gagal: $err');
    }
  }

  /// Buat (atau perbaiki) channel notifikasi.
  ///
  /// Channel harus ada sebelum pesan FCM pertama masuk: FCM memakai channel
  /// default dari manifest hanya kalau channel tersebut benar-benar ada di
  /// sistem. Kalau belum ada, FCM membuat fallback channel dengan importance
  /// rendah sehingga notifikasi tidak muncul sebagai heads-up.
  Future<void> _createChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final prefs = await SharedPreferences.getInstance();
    final installedVersion = prefs.getInt(_channelVersionKey) ?? 0;

    // Importance dan sound channel tidak bisa diubah setelah channel dibuat,
    // jadi channel versi lama dibuang lalu dibuat ulang dengan definisi baru.
    if (installedVersion < _channelDefinitionVersion) {
      await android.deleteNotificationChannel(
        channelId: kArusNotificationChannelId,
      );
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        kArusNotificationChannelId,
        kArusNotificationChannelName,
        description: kArusNotificationChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    if (installedVersion < _channelDefinitionVersion) {
      await prefs.setInt(_channelVersionKey, _channelDefinitionVersion);
    }
  }

  /// Status notifikasi sistem (false bila user mematikan notifikasi aplikasi
  /// atau permission Android 13+ belum diberikan).
  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.areNotificationsEnabled() ?? false;
    } catch (err) {
      debugPrint('[Notif] Gagal cek status notifikasi: $err');
      return false;
    }
  }

  /// Minta permission notifikasi (Android 13+ / POST_NOTIFICATIONS).
  ///
  /// Hanya dijalankan saat aplikasi aktif: dialog permission butuh Activity
  /// yang terlampir, sedangkan isolate background tidak punya Activity.
  Future<bool> requestPermission() async {
    try {
      if (!_canShowPermissionDialog) return false;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } catch (err) {
      debugPrint('[Notif] Gagal meminta permission notifikasi: $err');
      return false;
    }
  }

  /// Apakah dialog permission boleh ditampilkan (app harus resumed).
  bool get _canShowPermissionDialog {
    try {
      return WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    } catch (_) {
      // Binding belum diinisialisasi (mis. isolate background).
      return false;
    }
  }

  /// Tampilkan notifikasi sistem (heads-up + suara).
  ///
  /// Mengembalikan false bila notifikasi tidak bisa ditampilkan, mis. karena
  /// permission Android 13+ ditolak.
  ///
  /// [requestPermissionIfMissing] diisi false pada background isolate: di sana
  /// tidak ada Activity sehingga dialog permission tidak bisa ditampilkan.
  Future<bool> show({
    required String title,
    required String body,
    String? payload,
    bool requestPermissionIfMissing = true,
  }) async {
    await initialize();

    if (!await areNotificationsEnabled()) {
      if (!requestPermissionIfMissing) return false;
      if (!await requestPermission()) return false;
      // Notifikasi bisa saja masih dimatikan user di pengaturan sistem.
      if (!await areNotificationsEnabled()) return false;
    }

    try {
      _sequence++;
      await _plugin.show(
        id: _sequence,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            kArusNotificationChannelId,
            kArusNotificationChannelName,
            channelDescription: kArusNotificationChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        payload: payload,
      );
      return true;
    } catch (err) {
      debugPrint('[Notif] Gagal menampilkan notifikasi: $err');
      return false;
    }
  }
}

/// Provider notifikasi sistem — dipakai widget uji dan push service.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
