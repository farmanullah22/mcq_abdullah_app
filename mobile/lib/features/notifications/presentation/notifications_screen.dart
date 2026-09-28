import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../notifications/models/app_notification.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unread > 0)
            TextButton(
              onPressed: () => ref.read(notificationControllerProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(notificationControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(notificationControllerProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              subtitle: 'You will be notified of important events here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(notificationControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: page.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = page.notifications[index];
                return _NotificationTile(
                  notification: n,
                  onTap: () {
                    if (!n.isRead) ref.read(notificationControllerProvider.notifier).markRead(n.id);
                  },
                  onDelete: () => ref.read(notificationControllerProvider.notifier).delete(n.id),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap, required this.onDelete});

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    return Card(
      color: unread ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (unread ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  unread ? Icons.notifications_active_outlined : Icons.notifications_none,
                  size: 20,
                  color: unread ? AppColors.primary : AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(notification.body, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.dateTime(notification.createdAt),
                      style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
