import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arus/app.dart';
import 'package:arus/core/l10n/strings_id.dart';
import 'package:arus/core/storage/prefs_store.dart';
import 'package:arus/features/splash/data/health_repository.dart';

class FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> checkHealth() async {
    return const HealthStatus(
      status: 'ok',
      db: 'connected',
      time: '2026-10-06T12:00:00Z',
      version: '1.0.0',
    );
  }
}

void main() {
  testWidgets('Splash screen menampilkan identitas ARUS dan status online', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          healthRepositoryProvider.overrideWithValue(FakeHealthRepository()),
        ],
        child: const ArusApp(),
      ),
    );

    // Initial render
    expect(find.text(StringsId.appName), findsOneWidget);
    expect(find.text(StringsId.appTagline), findsOneWidget);

    // Selesaikan timer delayed splash screen
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.text(StringsId.serverOnline), findsOneWidget);
    expect(find.textContaining('Status: OK'), findsOneWidget);
  });
}
