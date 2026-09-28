import '../../../core/api/api_client.dart';
import '../models/expense.dart';

class ExpensePage {
  final List<Expense> expenses;
  final int total;
  final int page;
  final int totalPages;

  const ExpensePage({required this.expenses, required this.total, required this.page, required this.totalPages});
}

class ExpenseRepository {
  ExpenseRepository(this._api);
  final ApiClient _api;

  Future<ExpensePage> getExpenses({String? shopId, int page = 1, int limit = 30}) async {
    final res = await _api.request('GET', '/expenses', query: {
      'shopId': ?shopId,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return ExpensePage(
      expenses: (data['expenses'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Expense> create({
    required String category,
    required double amount,
    DateTime? expenseDate,
    String description = '',
    String? shopId,
  }) async {
    final res = await _api.request('POST', '/expenses', data: {
      'category': category,
      'amount': amount,
      if (expenseDate != null) 'expenseDate': expenseDate.toIso8601String(),
      'description': description,
      'shopId': ?shopId,
    });
    return Expense.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Expense> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/expenses/$id', data: data);
    return Expense.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/expenses/$id', data: {'deleteReason': reason});
  }

  Future<Expense> restore(String id) async {
    final res = await _api.request('POST', '/expenses/$id/restore');
    return Expense.fromJson(res['data'] as Map<String, dynamic>);
  }
}
