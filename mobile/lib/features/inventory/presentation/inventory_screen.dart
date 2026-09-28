import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_bar_brand.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/inventory_log.dart';
import '../providers/inventory_providers.dart';
import 'stock_screens.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryHistoryControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final isWarehouse = ref.watch(currentUserProvider)?.isWarehouseManager ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppBarBrand(showText: false),
            const SizedBox(width: 10),
            Text('Inventory'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Low stock',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LowStockScreen()),
            ),
            icon: const Icon(Icons.warning_amber_outlined),
          ),
          PopupMenuButton<String?>(
            initialValue: state.actionType,
            onSelected: (v) => ref.read(inventoryHistoryControllerProvider.notifier).setActionType(v),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: null, child: Text('All Activity')),
              PopupMenuItem(value: 'stock_in', child: Text('Stock In')),
              PopupMenuItem(value: 'stock_out', child: Text('Stock Out')),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      // Admin is view-only: stock mutations are manager actions. The warehouse
      // also cannot do direct stock out (stock leaves via transfer).
      floatingActionButton: isAdmin || isWarehouse
          ? null
          : FloatingActionButton.small(
              heroTag: 'stockOut',
              tooltip: 'Stock Out',
              backgroundColor: AppColors.danger,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockOutScreen()),
              ),
              child: const Icon(Icons.arrow_upward),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by product or supplier...',
                hintStyle: const TextStyle(fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.28)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.data.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
              ),
              data: (result) {
                final logs = _query.isEmpty
                    ? result.logs
                    : result.logs
                        .where((l) =>
                            l.productName.toLowerCase().contains(_query) ||
                            l.supplier.toLowerCase().contains(_query))
                        .toList();
                if (logs.isEmpty) {
                  return EmptyState(
                    icon: _query.isEmpty ? Icons.sync_alt : Icons.search_off,
                    title: _query.isEmpty ? 'No stock activity yet' : 'No matches found',
                    subtitle: _query.isEmpty
                        ? 'Stock in or stock out to see a history here.'
                        : 'No products match your search.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(inventoryHistoryControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _InventoryTile(log: logs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({required this.log});

  final InventoryLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stockIn = log.isStockIn;
    final color = stockIn ? AppColors.success : AppColors.danger;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                stockIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
              ),
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
                          log.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      Text(
                        '${stockIn ? '+' : '-'}${log.quantity}',
                        style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (log.supplier.isNotEmpty) 'Supplier: ${log.supplier}',
                      if (log.reason.isNotEmpty) log.reason,
                      if (log.performedByName.isNotEmpty) log.performedByName,
                      if (log.shopName.isNotEmpty) log.shopName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (log.movementDetail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      log.movementDetail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      'Stock: ${log.previousStock} → ${log.newStock}',
                      Formatters.dateTime(log.date),
                    ].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
