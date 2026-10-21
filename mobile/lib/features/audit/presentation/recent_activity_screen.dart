import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/activity_timeline.dart';
import '../../../core/widgets/lux_widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/models/dashboard_data.dart';

const _gold = Color(0xFFD4AF37);
const _goldLight = Color(0xFFF7D488);
const _bg = Color(0xFF0B0B0F);

/// Merged feed of stock movements and audit activity.
///
/// Passing a [shopId] scopes the feed to a single branch (used by the admin
/// dashboard's "view branch logs" button). Leaving it null falls back to the
/// current user's branch for managers, or every branch for admins.
final recentActivityProvider = FutureProvider.family<List<ActivityItem>, String?>((ref, branchId) async {
  final user = ref.watch(currentUserProvider);
  final isAdmin = user?.isAdmin ?? false;
  final shopId = branchId ?? (isAdmin ? null : user?.assignedShopId);

  final invFuture = ref.read(inventoryRepositoryProvider).history(shopId: shopId, limit: 80);
  final auditFuture = ref.read(auditRepositoryProvider).getLogs(shopId: shopId, limit: 80);
  final (inventory, audit) = await (invFuture, auditFuture).wait;

  final items = <ActivityItem>[
    for (final l in inventory.logs)
      ActivityItem(
        type: l.isStockIn ? 'STOCK_IN' : 'STOCK_OUT',
        title: '${l.isStockIn ? 'Stock in' : 'Stock out'} · ${l.productName}',
        subtitle: [
          '${l.quantity} units',
          if (l.reason.isNotEmpty) l.reason,
          if (l.performedByName.isNotEmpty) l.performedByName,
          if (l.shopName.isNotEmpty) l.shopName,
        ].join(' · '),
        time: l.date?.toIso8601String(),
      ),
    for (final a in audit.logs)
      // A branch feed is about what changed in the branch, so the noisy
      // sign-in / sign-out entries are left out of it.
      if (branchId == null || !_isSessionEvent(a.actionType))
        ActivityItem(
          type: a.actionType,
          title: a.remarks.isNotEmpty ? a.remarks : a.actionType,
          subtitle: [a.performedByName, a.shopName].where((s) => s.isNotEmpty).join(' · '),
          time: a.timestamp?.toIso8601String(),
          changes: a.changes,
          facts: a.facts,
          itemLines: a.itemLines,
        ),
  ];

  items.sort((a, b) {
    final ta = DateTime.tryParse(a.time ?? '');
    final tb = DateTime.tryParse(b.time ?? '');
    return (tb ?? DateTime(2000)).compareTo(ta ?? DateTime(2000));
  });
  return items.take(100).toList();
});

/// Login / logout / report-download entries carry no business change.
bool _isSessionEvent(String actionType) {
  final t = actionType.toUpperCase();
  return t == 'LOGIN' || t == 'LOGOUT' || t.contains('REPORT_DOWNLOAD');
}

class RecentActivityScreen extends ConsumerWidget {
  const RecentActivityScreen({super.key, this.shopId, this.shopName});

  /// When set, the feed is scoped to this branch only.
  final String? shopId;

  /// Display name of the branch being viewed (optional).
  final String? shopName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = recentActivityProvider(shopId);
    final activity = ref.watch(provider);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ShowroomBackground(),
          SafeArea(
            child: activity.when(
              loading: () => const LuxLoadingView(message: 'Loading activity...'),
              error: (e, st) => LuxErrorView(
                message: e.toString(),
                onRetry: () => ref.refresh(provider),
              ),
              data: (items) => RefreshIndicator(
                color: _gold,
                backgroundColor: const Color(0xFF16141B),
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                  children: [
                    _ActivityTopBar(
                      onRefresh: () => ref.refresh(provider),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      shopName ?? 'Recent Activity',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shopName != null
                          ? 'All recent logs for this branch'
                          : 'Latest stock movements and changes',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const LuxGoldDivider(),
                    const SizedBox(height: 18),
                    LuxGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: items.isEmpty
                          ? const LuxEmptyNote('No recent activity yet')
                          : ActivityTimeline(items: items),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTopBar extends StatelessWidget {
  const _ActivityTopBar({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _goldLight,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.refresh_rounded, size: 19, color: _goldLight),
          ),
        ),
      ],
    );
  }
}
