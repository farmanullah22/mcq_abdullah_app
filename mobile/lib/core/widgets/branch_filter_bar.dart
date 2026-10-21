import 'package:flutter/material.dart';

import '../../features/shops/models/shop.dart';
import '../theme/app_colors.dart';

/// Horizontal bar with a dropdown that scopes a log / activity feed to a
/// single branch (or the warehouse). An empty selection means "all branches".
///
/// Managers only ever get their own branch back from the API, so the list is
/// naturally limited for them.
class BranchFilterBar extends StatelessWidget {
  const BranchFilterBar({
    super.key,
    required this.shops,
    required this.selectedShopId,
    required this.onChanged,
    this.label = 'Branch',
    this.allLabel = 'All branches',
  });

  final List<Shop> shops;

  /// Currently selected branch id, `null` / empty means all branches.
  final String? selectedShopId;

  /// Called with the picked branch id, or `null` when "all branches" is picked.
  final ValueChanged<String?> onChanged;

  final String label;
  final String allLabel;

  static const String _allValue = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedShopId ?? '';

    // Guard against a branch that was deleted in the meantime.
    final value = shops.any((s) => s.id == selected) ? selected : _allValue;

    final branches = shops.where((s) => !s.isWarehouse).toList();
    final warehouses = shops.where((s) => s.isWarehouse).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded, size: 17, color: AppColors.accent),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Icons.expand_more_rounded, size: 20),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                items: [
                  DropdownMenuItem<String>(
                    value: _allValue,
                    child: Row(
                      children: [
                        const Icon(Icons.grid_view_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(allLabel),
                      ],
                    ),
                  ),
                  for (final shop in branches)
                    DropdownMenuItem<String>(
                      value: shop.id,
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              shop.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (shop.managerName != null && shop.managerName!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '· ${shop.managerName}',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  for (final shop in warehouses)
                    DropdownMenuItem<String>(
                      value: shop.id,
                      child: Row(
                        children: [
                          const Icon(Icons.warehouse_rounded, size: 16, color: AppColors.info),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              shop.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => onChanged(v == null || v == _allValue ? null : v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
