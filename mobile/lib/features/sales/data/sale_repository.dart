import '../../../core/api/api_client.dart';
import '../models/sale.dart';

class SalePage {
  final List<Sale> sales;
  final int total;
  final int page;
  final int totalPages;

  const SalePage({required this.sales, required this.total, required this.page, required this.totalPages});
}

class SaleRepository {
  SaleRepository(this._api);
  final ApiClient _api;

  Future<SalePage> getSales({String? shopId, DateTime? from, DateTime? to, int page = 1, int limit = 30}) async {
    final res = await _api.request('GET', '/sales', query: {
      'shopId': ?shopId,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return SalePage(
      sales: (data['sales'] as List).map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Sale> getSale(String id) async {
    final res = await _api.request('GET', '/sales/$id');
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Sale> create({
    required List<Map<String, dynamic>> items,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    double discount = 0,
    String paymentMethod = 'cash',
    String notes = '',
    String? shopId,
    double paidAmount = 0,
  }) async {
    final res = await _api.request('POST', '/sales', data: {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'notes': notes,
      'paidAmount': paidAmount,
      'shopId': ?shopId,
    });
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Sale> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/sales/$id', data: data);
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = '', bool restock = false}) async {
    await _api.request('DELETE', '/sales/$id', data: {'deleteReason': reason, 'restock': restock});
  }

  Future<Sale> restore(String id) async {
    final res = await _api.request('POST', '/sales/$id/restore');
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }
}
