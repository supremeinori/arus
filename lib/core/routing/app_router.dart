import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_assistant/presentation/ai_home_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/catalog/presentation/menu_create_screen.dart';
import '../../features/catalog/presentation/product_detail_screen.dart';
import '../../features/catalog/presentation/product_form_screen.dart';
import '../../features/catalog/presentation/product_list_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/inventory/presentation/inventory_list_screen.dart';
import '../../features/inventory/presentation/stock_movement_screen.dart';
import '../../features/notifications/presentation/notification_screen.dart';
import '../../features/outlets/presentation/outlet_detail_screen.dart';
import '../../features/outlets/presentation/outlet_form_screen.dart';
import '../../features/outlets/presentation/outlet_list_screen.dart';
import '../../features/pos/presentation/pos_history_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/sensors/presentation/sensor_test_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/integrity/presentation/integrity_chain_screen.dart';
import '../../features/game/presentation/game_home_screen.dart';
import '../../features/search/presentation/global_search_screen.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/users/presentation/user_management_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// Navigator key global — dipakai push service untuk menampilkan banner
/// foreground tanpa harus punya BuildContext.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isAuthenticated = authState.isAuthenticated;

      // Jika user sudah terotentikasi dan masih berada di /splash atau /login, otomatis alihkan ke /shell (tab Dashboard)
      if (isAuthenticated && (isSplash || isLoggingIn)) {
        ref.read(shellTabIndexProvider.notifier).state = 0;
        return '/shell';
      }

      // Jika belum terotentikasi dan mengakses rute selain /login atau /splash, alihkan ke /login
      if (!isAuthenticated && !isLoggingIn && !isSplash) {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/shell', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/pos',
        builder: (context, state) => const PosScreen(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) => const PosHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/sensors',
        builder: (context, state) => const SensorTestScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      // Layar penuh untuk AI — dipakai target tap notifikasi hasil AI.
      GoRoute(path: '/ai', builder: (context, state) => const AiHomeScreen()),
      GoRoute(
        path: '/outlets',
        builder: (context, state) => const OutletListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const OutletFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                OutletDetailScreen(outletId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    OutletFormScreen(outletId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryListScreen(),
        routes: [
          GoRoute(
            path: 'movements',
            builder: (context, state) => StockMovementScreen(
              outletId: state.uri.queryParameters['outlet_id'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) => const ProductListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const MenuCreateScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ProductDetailScreen(productId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    ProductFormScreen(productId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/integrity',
        builder: (context, state) => const IntegrityChainScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameHomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
    ],
  );
});
