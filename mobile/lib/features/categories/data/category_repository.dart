import '../../../core/api/api_client.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository(this._api);
  final ApiClient _api;

  Future<List<Category>> getCategories() async {
    final res = await _api.request('GET', '/categories');
    return (res['data'] as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> create(String name, {String description = ''}) async {
    final res = await _api.request('POST', '/categories', data: {'name': name, 'description': description});
    return Category.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Category> update(String id, String name, {String description = ''}) async {
    final res = await _api.request('PUT', '/categories/$id', data: {'name': name, 'description': description});
    return Category.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/categories/$id', data: {'deleteReason': reason});
  }

  Future<Category> restore(String id) async {
    final res = await _api.request('POST', '/categories/$id/restore');
    return Category.fromJson(res['data'] as Map<String, dynamic>);
  }
}
