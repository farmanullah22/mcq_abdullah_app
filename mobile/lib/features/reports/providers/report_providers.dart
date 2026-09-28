import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/report_repository.dart';

class ReportState {
  final String period;
  final AsyncValue<ReportData> summary;
  final AsyncValue<SalesReport> sales;
  final AsyncValue<ExpenseReport> expenses;
  final AsyncValue<InventoryReport> inventory;
  final bool exporting;

  const ReportState({
    this.period = 'month',
    this.summary = const AsyncValue.loading(),
    this.sales = const AsyncValue.loading(),
    this.expenses = const AsyncValue.loading(),
    this.inventory = const AsyncValue.loading(),
    this.exporting = false,
  });

  ReportState copyWith({
    String? period,
    AsyncValue<ReportData>? summary,
    AsyncValue<SalesReport>? sales,
    AsyncValue<ExpenseReport>? expenses,
    AsyncValue<InventoryReport>? inventory,
    bool? exporting,
  }) {
    return ReportState(
      period: period ?? this.period,
      summary: summary ?? this.summary,
      sales: sales ?? this.sales,
      expenses: expenses ?? this.expenses,
      inventory: inventory ?? this.inventory,
      exporting: exporting ?? this.exporting,
    );
  }
}

class ReportController extends Notifier<ReportState> {
  @override
  ReportState build() {
    Future.microtask(_loadAll);
    return const ReportState();
  }

  Future<void> _loadAll() async {
    _loadSummary();
    _loadSales();
    _loadExpenses();
    _loadInventory();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await ref.read(reportRepositoryProvider).getReport(state.period);
      state = state.copyWith(summary: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(summary: AsyncValue.error(e, st));
    }
  }

  Future<void> _loadSales() async {
    try {
      final data = await ref.read(reportRepositoryProvider).getSalesReport(state.period);
      state = state.copyWith(sales: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(sales: AsyncValue.error(e, st));
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final data = await ref.read(reportRepositoryProvider).getExpenseReport(state.period);
      state = state.copyWith(expenses: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(expenses: AsyncValue.error(e, st));
    }
  }

  Future<void> _loadInventory() async {
    try {
      final data = await ref.read(reportRepositoryProvider).getInventoryReport();
      state = state.copyWith(inventory: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(inventory: AsyncValue.error(e, st));
    }
  }

  Future<void> setPeriod(String period) async {
    state = state.copyWith(period: period);
    await _loadAll();
  }

  Future<void> refresh() => _loadAll();

  Future<List<int>?> exportCsv({required String type}) async {
    state = state.copyWith(exporting: true);
    try {
      final bytes = await ref.read(reportRepositoryProvider).exportCsv(type: type, period: state.period);
      return bytes;
    } catch (_) {
      return null;
    } finally {
      state = state.copyWith(exporting: false);
    }
  }

  Future<List<int>?> exportAuditCsv() async {
    try {
      return await ref.read(reportRepositoryProvider).exportAuditCsv();
    } catch (_) {
      return null;
    }
  }
}

final reportControllerProvider =
    NotifierProvider<ReportController, ReportState>(ReportController.new);
