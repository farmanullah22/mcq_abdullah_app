import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/change_details_view.dart';
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
            tooltip: 'Delete all',
            onPressed: () => _confirmDeleteAll(context, ref),
            icon: const Icon(Icons.delete_sweep_rounded),
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

  /// Asks for confirmation, then wipes every notification of the user.
  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final count = _notificationCount(ref);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no notifications to delete.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: Text(
          'This permanently removes all $count notification${count == 1 ? '' : 's'} from your device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(notificationControllerProvider.notifier).deleteAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'All notifications deleted.' : 'Could not delete notifications.')),
    );
  }

  /// Total number of notifications currently listed (read + unread).
  int _notificationCount(WidgetRef ref) {
    final page = ref.read(notificationControllerProvider).data.value;
    if (page == null) return 0;
    return page.total > 0 ? page.total : page.notifications.length;
  }
}

/// Visual treatment for a notification, derived from the action it reports.
({IconData icon, Color color, String badge}) _styleFor(AppNotification n) {
  final action = (n.actionType.isNotEmpty ? n.actionType : n.type).toUpperCase();
  if (action.contains('DELETE')) {
    return (icon: Icons.delete_outline, color: AppColors.danger, badge: 'Deleted');
  }
  if (action.contains('UPDATE') || action.contains('EDIT')) {
    return (icon: Icons.edit_outlined, color: AppColors.warning, badge: 'Edited');
  }
  if (action.contains('RESTORE')) {
    return (icon: Icons.restore, color: AppColors.success, badge: 'Restored');
  }
  if (action.contains('LOW_STOCK')) {
    return (icon: Icons.warning_amber_rounded, color: AppColors.warning, badge: 'Low stock');
  }
  if (action.contains('EXPENSE')) {
    return (icon: Icons.receipt_long_outlined, color: AppColors.warning, badge: 'Expense');
  }
  if (action.contains('SALE')) {
    return (icon: Icons.point_of_sale_outlined, color: AppColors.primary, badge: 'Sale');
  }
  if (action.contains('STOCK_IN')) {
    return (icon: Icons.arrow_downward, color: AppColors.info, badge: 'Stock in');
  }
  if (action.contains('STOCK_OUT')) {
    return (icon: Icons.arrow_upward, color: AppColors.info, badge: 'Stock out');
  }
  if (action.contains('STOCK')) {
    return (icon: Icons.inventory_2_outlined, color: AppColors.info, badge: 'Stock');
  }
  if (action.contains('CREATE') || action.contains('ADD')) {
    return (icon: Icons.add_box_outlined, color: AppColors.success, badge: 'Added');
  }
  return (icon: Icons.notifications_none, color: AppColors.secondary, badge: 'Update');
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({required this.notification, required this.onTap, required this.onDelete});

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = widget.notification;
    final unread = !n.isRead;
    final style = _styleFor(n);

    final footer = [
      if (n.shopName.isNotEmpty) n.shopName,
      if (n.performedByName.isNotEmpty) 'by ${n.performedByName}',
    ].join(' · ');

    return Card(
      color: unread ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: InkWell(
        onTap: () {
          widget.onTap();
          if (n.hasDetails) setState(() => _expanded = !_expanded);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      unread ? style.icon : Icons.notifications_none,
                      size: 20,
                      color: style.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: style.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                style.badge.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: style.color,
                                ),
                              ),
                            ),
                            if (unread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.body,
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              if (n.hasDetails) ...[
                const SizedBox(height: 10),
                _DetailBlock(
                  notification: n,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (footer.isNotEmpty)
                    Expanded(
                      child: Text(
                        footer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  Text(
                    Formatters.dateTime(n.createdAt),
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.notification, required this.expanded, required this.onToggle});

  final AppNotification notification;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.identity.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.label_important_outline, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      n.identity,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          if (expanded)
            ChangeDetailsView(
              changes: n.changes,
              facts: n.facts,
              itemLines: n.itemLines,
            )
          else
            _CollapsedPreview(notification: n),
          const SizedBox(height: 6),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded ? 'Hide details' : 'View full details',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One line preview shown before the block is expanded.
class _CollapsedPreview extends StatelessWidget {
  const _CollapsedPreview({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    if (n.changes.isNotEmpty) {
      final c = n.changes.first;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${c.label}: ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: c.from,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger.withValues(alpha: 0.9),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.danger.withValues(alpha: 0.5),
                ),
              ),
              const TextSpan(text: '  →  '),
              TextSpan(
                text: c.to,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (n.facts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          n.facts.take(3).map((f) => '${f.label}: ${f.value}').join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
