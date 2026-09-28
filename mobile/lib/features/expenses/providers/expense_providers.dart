import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/expense_repository.dart';

class ExpenseListState {
  final AsyncValue<ExpensePage> data;

  const ExpenseListState({this.data = const AsyncValue.loading()});
}

class ExpenseListController extends Notifier<ExpenseListState> {
  @override
  ExpenseListState build() {
    _load();
    return const ExpenseListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref.read(expenseRepositoryProvider).getExpenses();
      state = ExpenseListState(data: AsyncValue.data(page));
    } catch (e, st) {
      state = ExpenseListState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
}

final expenseListControllerProvider =
    NotifierProvider<ExpenseListController, ExpenseListState>(ExpenseListController.new);

class ExpenseMutationState {
  final bool loading;
  final String? error;

  const ExpenseMutationState({this.loading = false, this.error});
}

class ExpenseMutationController extends Notifier<ExpenseMutationState> {
  @override
  ExpenseMutationState build() => const ExpenseMutationState();

  Future<bool> create({
    required String category,
    required double amount,
    DateTime? expenseDate,
    String description = '',
    String? shopId,
  }) async {
    state = const ExpenseMutationState(loading: true);
    try {
      await ref.read(expenseRepositoryProvider).create(
            category: category,
            amount: amount,
            expenseDate: expenseDate,
            description: description,
            shopId: shopId,
          );
      state = const ExpenseMutationState();
      ref.invalidate(expenseListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = ExpenseMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const ExpenseMutationState(loading: true);
    try {
      await ref.read(expenseRepositoryProvider).delete(id, reason: reason);
      ref.invalidate(expenseListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      state = const ExpenseMutationState();
      return true;
    } catch (e) {
      state = ExpenseMutationState(error: e.toString());
      return false;
    }
  }
}

final expenseMutationControllerProvider =
    NotifierProvider<ExpenseMutationController, ExpenseMutationState>(ExpenseMutationController.new);
