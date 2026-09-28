import 'package:flutter/material.dart';

import '../../features/dashboard/models/dashboard_data.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

/// Maps an audit actionType to a visual (icon, color).
({IconData icon, Color color}) activityStyle(String type) {
  final t = type.toUpperCase();
  if (t.contains('SALE')) {
    if (t.contains('DELETE')) return (icon: Icons.delete_outline, color: AppColors.danger);
    if (t.contains('UPDATE')) return (icon: Icons.edit_outlined, color: AppColors.warning);
    return (icon: Icons.point_of_sale_outlined, color: AppColors.success);
  }
  if (t.contains('TRANSFER')) {
    return (icon: Icons.swap_horiz_rounded, color: AppColors.violet);
  }
  if (t.contains('STOCK')) {
    if (t.contains('OUT')) return (icon: Icons.arrow_downward, color: AppColors.danger);
    return (icon: Icons.inventory_2_outlined, color: AppColors.info);
  }
  if (t.contains('EXPENSE')) {
    if (t.contains('DELETE')) return (icon: Icons.delete_outline, color: AppColors.danger);
    return (icon: Icons.receipt_long_outlined, color: AppColors.warning);
  }
  if (t.contains('PRODUCT')) {
    if (t.contains('DELETE')) return (icon: Icons.delete_outline, color: AppColors.danger);
    if (t.contains('CREATE')) return (icon: Icons.add_box_outlined, color: AppColors.primary);
    return (icon: Icons.edit_outlined, color: AppColors.secondary);
  }
  if (t.contains('CATEGORY')) {
    if (t.contains('DELETE')) return (icon: Icons.delete_outline, color: AppColors.danger);
    return (icon: Icons.category_outlined, color: AppColors.violet);
  }
  if (t.contains('USER')) {
    if (t.contains('DELETE')) return (icon: Icons.delete_outline, color: AppColors.danger);
    return (icon: Icons.person_add_alt_1_outlined, color: AppColors.secondary);
  }
  if (t.contains('LOGIN')) return (icon: Icons.login_rounded, color: AppColors.success);
  if (t.contains('LOGOUT')) return (icon: Icons.logout_rounded, color: AppColors.warning);
  if (t.contains('REPORT')) return (icon: Icons.download_outlined, color: AppColors.violet);
  return (icon: Icons.history_rounded, color: AppColors.textSecondary);
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.items, this.onViewAll});

  final List<ActivityItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 40, color: theme.textTheme.bodySmall?.color),
                const SizedBox(height: 8),
                Text('No recent activity', style: theme.textTheme.bodySmall),
              ],
            ),
          )
        else
          ...items.indexed.map((e) => _ActivityRow(item: e.$2, isLast: e.$1 == items.length - 1)),
        if (onViewAll != null && items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.history_rounded, size: 16),
              label: const Text('View All Activity'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.isLast});

  final ActivityItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = activityStyle(item.type);
    final label = AppConstants.actionLabels[item.type] ?? (item.title.isNotEmpty ? item.title : item.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: style.color.withValues(alpha: 0.4)),
                ),
                child: Icon(style.icon, size: 14, color: style.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: style.color.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (item.time != null)
                        Text(
                          _formatTime(item.time!),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt == null) return iso;
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${_months[dt.month - 1]} $h:$m';
    } catch (_) {
      return iso;
    }
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}
