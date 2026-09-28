import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/expense.dart';
import '../providers/expense_providers.dart';
import 'expense_form_screen.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseListControllerProvider);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(expenseListControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          if (!isAdmin)
            IconButton(
              tooltip: 'Add Expense',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              ),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: state.data.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.read(expenseListControllerProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.expenses.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No expenses recorded',
              subtitle: 'Add your first expense to start tracking costs.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(expenseListControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: page.expenses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ExpenseTile(
                expense: page.expenses[index],
                canDelete: !isAdmin,
                onDelete: () => _confirmDelete(context, ref, page.expenses[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete the ${AppConstants.expenseCategoryLabels[expense.category] ?? expense.category} expense of ${Formatters.currency(expense.amount)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success = await ref.read(expenseMutationControllerProvider.notifier).delete(expense.id);
    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(expenseMutationControllerProvider).error ?? 'Delete failed')),
      );
    }
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.canDelete,
    required this.onDelete,
  });

  final Expense expense;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_outlined, color: AppColors.danger),
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
                          AppConstants.expenseCategoryLabels[expense.category] ?? Formatters.title(expense.category),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      Text(
                        Formatters.currency(expense.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (expense.description.isNotEmpty) expense.description,
                      if (expense.shopName.isNotEmpty) expense.shopName,
                      if (expense.createdByName.isNotEmpty) 'by ${expense.createdByName}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.dateTime(expense.expenseDate),
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
