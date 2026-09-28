import '../../../core/api/api_client.dart';
import '../models/shop.dart';

class ShopRepository {
  ShopRepository(this._api);
  final ApiClient _api;

  Future<List<Shop>> getShops() async {
    final res = await _api.request('GET', '/shops');
    return (res['data'] as List).map((e) => Shop.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Shop> getShop(String id) async {
    final res = await _api.request('GET', '/shops/$id');
    return Shop.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Shop> create(Map<String, dynamic> data) async {
    final res = await _api.request('POST', '/shops', data: data);
    return Shop.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Shop> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/shops/$id', data: data);
    return Shop.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/shops/$id', data: {'deleteReason': reason});
  }

  Future<Shop> restore(String id) async {
    final res = await _api.request('POST', '/shops/$id/restore');
    return Shop.fromJson(res['data'] as Map<String, dynamic>);
  }
}
