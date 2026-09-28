import '../../../core/api/api_client.dart';

class ReportData {
  final String period;
  final double sales;
  final int salesCount;
  final double expenses;
  final int expenseCount;
  final double profit;
  final int totalProducts;
  final double stockValue;
  final DateTime? generatedAt;

  const ReportData({
    this.period = 'month',
    this.sales = 0,
    this.salesCount = 0,
    this.expenses = 0,
    this.expenseCount = 0,
    this.profit = 0,
    this.totalProducts = 0,
    this.stockValue = 0,
    this.generatedAt,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? const {};
    final expenses = json['expenses'] as Map<String, dynamic>? ?? const {};
    final inventory = json['inventory'] as Map<String, dynamic>? ?? const {};
    return ReportData(
      period: json['period']?.toString() ?? '',
      sales: (sales['total'] as num?)?.toDouble() ?? 0,
      salesCount: (sales['count'] as num?)?.toInt() ?? 0,
      expenses: (expenses['total'] as num?)?.toDouble() ?? 0,
      expenseCount: (expenses['count'] as num?)?.toInt() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      totalProducts: (inventory['totalProducts'] as num?)?.toInt() ?? 0,
      stockValue: (inventory['stockValue'] as num?)?.toDouble() ?? 0,
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
    );
  }
}

class SalesReport {
  final int count;
  final double total;
  final double profit;
  final Map<String, dynamic> paymentSummary;
  final List<Map<String, dynamic>> sales;

  const SalesReport({
    this.count = 0,
    this.total = 0,
    this.profit = 0,
    this.paymentSummary = const {},
    this.sales = const [],
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    final summary = <String, dynamic>{};
    for (final item in (json['paymentSummary'] as List?) ?? const []) {
      final m = item as Map<String, dynamic>;
      summary[m['_id']?.toString() ?? ''] = {
        'total': (m['total'] as num?)?.toDouble() ?? 0,
        'count': (m['count'] as num?)?.toInt() ?? 0,
      };
    }
    return SalesReport(
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      profit: (json['profit'] as num?)?.toDouble() ?? 0,
      paymentSummary: summary,
      sales: (json['sales'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
    );
  }
}

class ExpenseReport {
  final int count;
  final double total;
  final List<Map<String, dynamic>> breakdown;
  final List<Map<String, dynamic>> expenses;

  const ExpenseReport({
    this.count = 0,
    this.total = 0,
    this.breakdown = const [],
    this.expenses = const [],
  });

  factory ExpenseReport.fromJson(Map<String, dynamic> json) => ExpenseReport(
        count: (json['count'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        breakdown: (json['breakdown'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
        expenses: (json['expenses'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      );
}

class InventoryReport {
  final int totalProducts;
  final int lowStockCount;
  final double totalStockValue;
  final double potentialRevenue;
  final List<Map<String, dynamic>> products;

  const InventoryReport({
    this.totalProducts = 0,
    this.lowStockCount = 0,
    this.totalStockValue = 0,
    this.potentialRevenue = 0,
    this.products = const [],
  });

  factory InventoryReport.fromJson(Map<String, dynamic> json) => InventoryReport(
        totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
        lowStockCount: (json['lowStockCount'] as num?)?.toInt() ?? 0,
        totalStockValue: (json['totalStockValue'] as num?)?.toDouble() ?? 0,
        potentialRevenue: (json['potentialRevenue'] as num?)?.toDouble() ?? 0,
        products: (json['products'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      );
}

class ReportRepository {
  ReportRepository(this._api);
  final ApiClient _api;

  Future<ReportData> getReport(String period, {String? shopId}) async {
    final res = await _api.request('GET', '/reports', query: {'period': period, 'shopId': ?shopId});
    return ReportData.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<SalesReport> getSalesReport(String period, {String? shopId}) async {
    final res = await _api.request('GET', '/reports/sales', query: {'period': period, 'shopId': ?shopId});
    return SalesReport.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ExpenseReport> getExpenseReport(String period, {String? shopId}) async {
    final res = await _api.request('GET', '/reports/expenses', query: {'period': period, 'shopId': ?shopId});
    return ExpenseReport.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<InventoryReport> getInventoryReport({String? shopId}) async {
    final res = await _api.request('GET', '/reports/inventory', query: {'shopId': ?shopId});
    return InventoryReport.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<int>> exportCsv({required String type, String period = 'month', String? shopId}) {
    return _api.download('/reports/export', query: {
      'type': type,
      'period': period,
      'shopId': ?shopId,
    });
  }

  Future<List<int>> exportAuditCsv({String? userId, String? shopId, String? actionType, String? module}) {
    return _api.download('/audit/export', query: {
      'userId': ?userId,
      'shopId': ?shopId,
      'actionType': ?actionType,
      'module': ?module,
    });
  }
}
