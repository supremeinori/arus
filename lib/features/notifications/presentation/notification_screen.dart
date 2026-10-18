import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../domain/notification_models.dart';
import 'notifications_provider.dart';

/// Formatter tanggal notifikasi — top-level final (aturan E21:
/// tidak dibuat di dalam build).
final notifDateFormatter = DateFormat('dd MMM, HH:mm');

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  String? _selectedFilter; // null = all, 'unread', 'low_stock', 'target_achieved'

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsListProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isProcessing = ref.watch(notificationActionProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pusat Notifikasi', maxLines: 1, overflow: TextOverflow.ellipsis),
            if (unreadCount > 0)
              Text(
                '$unreadCount pesan belum dibaca',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMutedDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Tandai Semua Dibaca',
            onPressed: isProcessing
                ? null
                : () async {
                    await ref.read(notificationActionProvider.notifier).markAllAsRead();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua notifikasi ditandai dibaca', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Evaluasi Pemicu Stok Kritis',
            onPressed: isProcessing
                ? null
                : () async {
                    final triggered = await ref
                        .read(notificationActionProvider.notifier)
                        .evaluateNotifications();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Evaluasi selesai ($triggered peringatan baru)', maxLines: 2, overflow: TextOverflow.ellipsis)),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            selectedFilter: _selectedFilter,
            onSelected: (val) => setState(() => _selectedFilter = val),
          ),
          Expanded(
            child: AsyncStateView<NotificationsResponse>(
              value: notifsAsync,
              onRetry: () => ref.invalidate(notificationsListProvider),
              dataBuilder: (data) {
                var list = data.notifications;
                if (_selectedFilter == 'unread') {
                  list = list.where((n) => !n.isRead).toList();
                } else if (_selectedFilter != null) {
                  list = list.where((n) => n.type == _selectedFilter).toList();
                }

                if (list.isEmpty) {
                  return const EmptyStateView(
                    message: 'Tidak Ada Notifikasi. Semua kondisi operasional berjalan lancar dan belum ada peringatan baru.',
                    icon: Icons.notifications_off_outlined,
                  );
                }

                return _NotificationList(items: list);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips notifikasi — widget class top-level (aturan E23).
class _FilterChips extends StatelessWidget {
  final String? selectedFilter;
  final ValueChanged<String?> onSelected;

  const _FilterChips({required this.selectedFilter, required this.onSelected});

  static const List<Map<String, String?>> _filters = [
    {'label': 'Semua', 'val': null},
    {'label': 'Belum Dibaca', 'val': 'unread'},
    {'label': 'Stok Menipis', 'val': 'low_stock'},
    {'label': 'Target', 'val': 'target_achieved'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((f) {
          final isSelected = selectedFilter == f['val'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              backgroundColor: AppTheme.darkCardSurface,
              selectedColor: AppTheme.jadeTosca,
              side: const BorderSide(color: AppTheme.darkCardBorder),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
              ),
              label: Text(f['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: isSelected,
              onSelected: (_) => onSelected(f['val']),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Daftar notifikasi — widget class top-level ConsumerWidget (aturan E23).
class _NotificationList extends ConsumerWidget {
  final List<NotificationModel> items;

  const _NotificationList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _NotificationCard(item: items[index]);
      },
    );
  }
}

/// Kartu satu notifikasi — widget class top-level (aturan E23).
class _NotificationCard extends ConsumerWidget {
  final NotificationModel item;

  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon = Icons.info_outline;
    Color color = AppTheme.jadeTosca;

    if (item.type == 'low_stock') {
      icon = Icons.warning_amber_rounded;
      color = AppTheme.dangerRed;
    } else if (item.type == 'target_achieved') {
      icon = Icons.emoji_events_outlined;
      color = const Color(0xFF10B981);
    } else if (item.type == 'sales_change') {
      icon = Icons.trending_up_rounded;
      color = const Color(0xFFF59E0B);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: item.isRead ? AppTheme.darkCardSurface : AppTheme.darkCardSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isRead ? AppTheme.darkCardBorder : AppTheme.jadeTosca.withAlpha(120),
          width: 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (!item.isRead) {
            await ref.read(notificationActionProvider.notifier).markAsRead(item.id);
          }

          if (!context.mounted) return;
          if (item.type == 'low_stock') {
            context.push('/inventory');
          } else if (item.type == 'target_achieved' || item.type == 'sales_change') {
            context.push('/shell');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.textPrimaryDark,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.jadeTosca,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryDark, height: 1.3),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notifDateFormatter.format(item.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMutedDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
