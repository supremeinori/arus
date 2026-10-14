import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/storage/prefs_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib sebelum DateFormat memakai locale 'id_ID' (dipakai di Beranda dan Analitik).
  await initializeDateFormatting('id_ID');
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const ArusApp(),
    ),
  );
}
