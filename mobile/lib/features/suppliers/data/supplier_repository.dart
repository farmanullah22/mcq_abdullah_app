import '../../../core/api/api_client.dart';
import '../models/supplier.dart';

class SupplierPage {
  final List<Supplier> suppliers;
  final int total;
  final int page;
  final int totalPages;

  const SupplierPage({
    required this.suppliers,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class SupplierRepository {
  SupplierRepository(this._api);
  final ApiClient _api;

  Future<SupplierPage> getSuppliers({String search = '', int page = 1, int limit = 50}) async {
    final res = await _api.request('GET', '/suppliers', query: {
      'search': search.isEmpty ? null : search,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return SupplierPage(
      suppliers: (data['suppliers'] as List)
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Supplier> getSupplier(String id) async {
    final res = await _api.request('GET', '/suppliers/$id');
    return Supplier.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Supplier> create({
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String city = '',
    String notes = '',
    double balance = 0,
  }) async {
    final res = await _api.request('POST', '/suppliers', data: {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'notes': notes,
      'balance': balance,
    });
    return Supplier.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Supplier> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/suppliers/$id', data: data);
    return Supplier.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/suppliers/$id', data: {'deleteReason': reason});
  }

  Future<Supplier> adjustBalance(String id, {required double amount, required String type, String note = ''}) async {
    final res = await _api.request('POST', '/suppliers/$id/balance', data: {
      'amount': amount,
      'type': type,
      'note': note,
    });
    return Supplier.fromJson(res['data'] as Map<String, dynamic>);
  }
}
