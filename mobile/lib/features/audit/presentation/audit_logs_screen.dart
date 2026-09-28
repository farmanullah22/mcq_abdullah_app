import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../models/audit_log.dart';
import '../providers/audit_providers.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _showFilters(context, ref, state.filter),
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(auditControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _StatsBar(state: state),
          Expanded(
            child: state.logs.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(auditControllerProvider.notifier).refresh(),
              ),
              data: (page) {
                if (page.logs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history_outlined,
                    title: 'No audit logs found',
                    subtitle: 'Adjust filters or try again later.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(auditControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: page.logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = page.logs[index];
                      return _AuditTile(log: log, onTap: () => _openDetail(context, ref, log));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, AuditLog log) {
    ref.read(auditDetailIdProvider.notifier).set(log.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuditDetailScreen()),
    );
  }

  Future<void> _showFilters(BuildContext context, WidgetRef ref, AuditFilter current) async {
    String? module = current.module;
    String? actionType = current.actionType;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Filter Audit Logs'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: module,
                decoration: const InputDecoration(labelText: 'Module'),
                items: AppConstants.auditModules
                    .map((m) => DropdownMenuItem(value: m, child: Text(m == 'all' ? 'All modules' : Formatters.title(m))))
                    .toList(),
                onChanged: (v) => setState(() => module = v == 'all' ? null : v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: actionType,
                decoration: const InputDecoration(labelText: 'Action'),
                items: AppConstants.actionLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => actionType = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(auditControllerProvider.notifier).clearFilter();
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(auditControllerProvider.notifier).setFilter(
                      current.copyWith(module: module, actionType: actionType),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.state});

  final AuditState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats.value;
    if (stats == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _StatPill(icon: Icons.receipt_long_outlined, label: '${stats.total} total', color: AppColors.primary),
          const SizedBox(width: 8),
          _StatPill(icon: Icons.today_outlined, label: '${stats.today} today', color: AppColors.secondary),
          const SizedBox(width: 8),
          _StatPill(icon: Icons.delete_outline, label: '${stats.deleted} deletes', color: AppColors.danger),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.log, required this.onTap});

  final AuditLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelete = log.actionType.contains('DELETE');
    final isCreate = log.actionType.contains('CREATE');
    final color = isDelete ? AppColors.danger : (isCreate ? AppColors.success : AppColors.secondary);
    final icon = isDelete
        ? Icons.delete_outline
        : (isCreate
            ? Icons.add_circle_outline
            : Icons.edit_outlined);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
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
                            AppConstants.actionLabels[log.actionType] ?? log.actionType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        if (log.status == 'failed')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('FAILED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.danger)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        log.performedByName.isEmpty ? 'System' : log.performedByName,
                        Formatters.title(log.module),
                        if (log.shopName.isNotEmpty) log.shopName,
                        log.remarks.isEmpty ? '' : log.remarks,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.dateTime(log.timestamp),
                      style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class AuditDetailScreen extends ConsumerWidget {
  const AuditDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditDetailControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log Detail')),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(auditDetailControllerProvider.notifier).refresh(),
        ),
        data: (log) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.actionLabels[log.actionType] ?? log.actionType,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    _Row(label: 'Module', value: Formatters.title(log.module)),
                    _Row(label: 'Record Type', value: log.recordType),
                    _Row(label: 'Record ID', value: log.recordId),
                    _Row(label: 'Performed By', value: '${log.performedByName} (${log.userRole})'),
                    _Row(label: 'Shop', value: log.shopName),
                    _Row(label: 'Timestamp', value: Formatters.dateTime(log.timestamp)),
                    _Row(label: 'IP', value: log.ipAddress),
                    _Row(label: 'Platform', value: log.platform),
                    _Row(label: 'Status', value: log.status),
                    if (log.remarks.isNotEmpty) _Row(label: 'Remarks', value: log.remarks),
                  ],
                ),
              ),
            ),
            if (log.oldData != null && log.oldData!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  title: const Text('Old Data', style: TextStyle(fontWeight: FontWeight.w700)),
                  children: [Padding(
                    padding: const EdgeInsets.all(12),
                    child: _JsonView(data: log.oldData!),
                  )],
                ),
              ),
            ],
            if (log.newData != null && log.newData!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  title: const Text('New Data', style: TextStyle(fontWeight: FontWeight.w700)),
                  children: [Padding(
                    padding: const EdgeInsets.all(12),
                    child: _JsonView(data: log.newData!),
                  )],
                ),
              ),
            ],
            if (log.actionType.contains('DELETE')) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () async {
                  final ok = await ref.read(auditControllerProvider.notifier).restore(log.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore failed')));
                  }
                },
                icon: const Icon(Icons.restore),
                label: const Text('Restore Record'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  const _JsonView({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${e.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: '${e.value}'),
                  ]),
                  style: const TextStyle(fontSize: 12),
                ),
              ))
          .toList(),
    );
  }
}
