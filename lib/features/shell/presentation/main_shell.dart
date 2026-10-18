import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../dashboard/presentation/shift_summary_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../../operations/presentation/operations_hub_screen.dart';
import '../../ai_assistant/presentation/ai_home_screen.dart';
import '../../ai_assistant/presentation/ai_provider.dart';
import '../../analytics/presentation/analytics_screen.dart';
import '../../inventory/presentation/inventory_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../core/theme/app_theme.dart';

/// State Provider untuk mengontrol tab aktif pada MainShell (0-indexed).
final shellTabIndexProvider = StateProvider<int>((ref) => 0);

/// Global helper untuk membuka AI Companion Bottom Sheet dari halaman mana pun (misal Form Tambah Menu)
void showAiCompanionBottomSheet(BuildContext context, WidgetRef ref, {String? initialPrompt}) {
  if (initialPrompt != null && initialPrompt.isNotEmpty) {
    ref.read(aiPendingPromptProvider.notifier).state = initialPrompt;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: AppTheme.darkCardSurface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border.all(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        child: Column(
          children: [
            // Drag handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.darkCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                child: AiHomeScreen(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isStaff = user?.role == UserRole.staff;
    final currentIndex = ref.watch(shellTabIndexProvider);

    // Definisikan tab berdasarkan Role per SRS Section 16.2 (Tanpa tab AI terisolasi di bottom bar)
    final List<Widget> pages = isStaff
        ? const [
            ShiftSummaryScreen(),
            PosScreen(),
            InventoryListScreen(),
            ProfileScreen(),
          ]
        : const [
            DashboardScreen(),
            OperationsHubScreen(),
            AnalyticsScreen(),
            ProfileScreen(),
          ];

    final List<BottomNavigationBarItem> navItems = isStaff
        ? const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale_outlined),
              activeIcon: Icon(Icons.point_of_sale),
              label: 'Kasir',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Stok',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_outlined),
              activeIcon: Icon(Icons.menu),
              label: 'Lainnya',
            ),
          ]
        : const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Operasi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Analitik',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_outlined),
              activeIcon: Icon(Icons.menu),
              label: 'Lainnya',
            ),
          ];

    final safeIndex = currentIndex >= pages.length ? 0 : currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      // Global Floating Action Button untuk AI Companion (Selalu ada di mana pun)
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.darkCardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
        ),
        tooltip: 'ARUS AI Companion',
        onPressed: () => showAiCompanionBottomSheet(context, ref),
        child: ClipOval(
          child: Image.asset(
            'assets/images/ai_mascot.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.auto_awesome_rounded,
              size: 26,
              color: AppTheme.jadeTosca,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.darkCardSurface,
          border: Border(
            top: BorderSide(color: AppTheme.darkCardBorder, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.darkCardSurface,
          elevation: 0,
          currentIndex: safeIndex,
          onTap: (index) {
            ref.read(shellTabIndexProvider.notifier).state = index;
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.jadeTosca,
          unselectedItemColor: AppTheme.textMutedDark,
          selectedFontSize: 11.5,
          unselectedFontSize: 11.5,
          items: navItems,
        ),
      ),
    );
  }
}
