import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/notification_models.dart';
import 'notifications_provider.dart';

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pusat Notifikasi'),
            if (unreadCount > 0)
              Text(
                '$unreadCount pesan belum dibaca',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                      const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
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
                      SnackBar(content: Text('Evaluasi selesai ($triggered peringatan baru)')),
                    );
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: notifsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Gagal memuat notifikasi: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(notificationsListProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                var list = data.notifications;
                if (_selectedFilter == 'unread') {
                  list = list.where((n) => !n.isRead).toList();
                } else if (_selectedFilter != null) {
                  list = list.where((n) => n.type == _selectedFilter).toList();
                }

                if (list.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildNotificationList(list);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Semua', 'val': null},
      {'label': 'Belum Dibaca', 'val': 'unread'},
      {'label': 'Stok Menipis', 'val': 'low_stock'},
      {'label': 'Target', 'val': 'target_achieved'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['val'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = f['val']);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Tidak Ada Notifikasi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Semua kondisi operasional berjalan lancar dan belum ada peringatan baru.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationModel> list) {
    final dateFormatter = DateFormat('dd MMM, HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];

        IconData icon = Icons.info_outline;
        Color color = Colors.blue;

        if (item.type == 'low_stock') {
          icon = Icons.warning_amber_rounded;
          color = Colors.red;
        } else if (item.type == 'target_achieved') {
          icon = Icons.emoji_events_outlined;
          color = Colors.green;
        } else if (item.type == 'sales_change') {
          icon = Icons.trending_up_rounded;
          color = Colors.orange;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          color: item.isRead ? Colors.white : Colors.blue.shade50.withAlpha(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: item.isRead ? Colors.grey.shade200 : AppTheme.primaryBlue.withAlpha(50),
              width: item.isRead ? 1 : 1.5,
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
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (!item.isRead) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dateFormatter.format(item.createdAt),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
