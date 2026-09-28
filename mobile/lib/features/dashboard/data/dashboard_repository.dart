import '../../../core/api/api_client.dart';
import '../models/dashboard_data.dart';

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardData> getDashboard({String? shopId}) async {
    final res = await _api.request('GET', '/dashboard', query: {
      'shopId': ?shopId,
    });
    return DashboardData.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ShopOverview> getShopOverview(String shopId) async {
    final res = await _api.request('GET', '/shops/$shopId/overview');
    return ShopOverview.fromJson(res['data'] as Map<String, dynamic>);
  }
}
