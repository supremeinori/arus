import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/push/notification_service.dart';
import 'core/storage/prefs_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  // Channel notifikasi harus ada sebelum pesan FCM pertama masuk: FCM memakai
  // channel default dari manifest hanya kalau channel tersebut sudah ada di
  // sistem, kalau tidak FCM memakai fallback channel tanpa heads-up/suara.
  await NotificationService.instance.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ArusApp(),
    ),
  );
}
