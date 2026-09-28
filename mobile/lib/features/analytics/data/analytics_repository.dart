import '../../../core/api/api_client.dart';
import '../../dashboard/models/dashboard_data.dart';

class AnalyticsData {
  final List<ChartPoint> daily;
  final List<ChartPoint> weekly;
  final List<ChartPoint> monthly;
  final List<ChartPoint> yearly;
  final List<ExpenseCategoryTotal> expenseBreakdown;
  final List<ShopComparison> comparison;

  const AnalyticsData({
    this.daily = const [],
    this.weekly = const [],
    this.monthly = const [],
    this.yearly = const [],
    this.expenseBreakdown = const [],
    this.comparison = const [],
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) => AnalyticsData(
        daily: (json['daily'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        weekly: (json['weekly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        monthly: (json['monthly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        yearly: (json['yearly'] as List?)?.map((e) => ChartPoint.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        expenseBreakdown: (json['expenseBreakdown'] as List?)?.map((e) => ExpenseCategoryTotal.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
        comparison: (json['comparison'] as List?)?.map((e) => ShopComparison.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      );
}

class AnalyticsRepository {
  AnalyticsRepository(this._api);
  final ApiClient _api;

  Future<AnalyticsData> getAnalytics({String? shopId}) async {
    final res = await _api.request('GET', '/analytics', query: {'shopId': ?shopId});
    return AnalyticsData.fromJson(res['data'] as Map<String, dynamic>);
  }
}
