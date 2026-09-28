import '../../../core/api/api_client.dart';
import '../models/product.dart';

class ProductPage {
  final List<Product> products;
  final int total;
  final int page;
  final int totalPages;

  const ProductPage({required this.products, required this.total, required this.page, required this.totalPages});
}

class ProductRepository {
  ProductRepository(this._api);
  final ApiClient _api;

  Future<ProductPage> getProducts({
    String? search,
    String? categoryId,
    String? shopId,
    bool? lowStock,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.request('GET', '/products', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      'categoryId': ?categoryId,
      'shopId': ?shopId,
      if (lowStock != null) 'lowStock': '$lowStock',
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return ProductPage(
      products: (data['products'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<Product>> getLowStock() async {
    final res = await _api.request('GET', '/products/low-stock');
    return (res['data'] as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> getProduct(String id) async {
    final res = await _api.request('GET', '/products/$id');
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> create(Map<String, dynamic> data) async {
    final res = await _api.request('POST', '/products', data: data);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Product> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/products/$id', data: data);
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/products/$id', data: {'deleteReason': reason});
  }

  Future<Product> restore(String id) async {
    final res = await _api.request('POST', '/products/$id/restore');
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }
}
