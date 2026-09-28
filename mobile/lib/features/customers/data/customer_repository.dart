import '../../../core/api/api_client.dart';
import '../models/customer.dart';

class CustomerPage {
  final List<Customer> customers;
  final int total;
  final int page;
  final int totalPages;

  const CustomerPage({
    required this.customers,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class CustomerRepository {
  CustomerRepository(this._api);
  final ApiClient _api;

  Future<CustomerPage> getCustomers({
    String search = '',
    int page = 1,
    int limit = 50,
    String? shopId,
  }) async {
    final res = await _api.request('GET', '/customers', query: {
      'search': search.isEmpty ? null : search,
      'shopId': ?shopId,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return CustomerPage(
      customers: (data['customers'] as List)
          .map((e) => Customer.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Customer> getCustomer(String id) async {
    final res = await _api.request('GET', '/customers/$id');
    return Customer.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Customer> create({
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String city = '',
    String notes = '',
    double balance = 0,
  }) async {
    final res = await _api.request('POST', '/customers', data: {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'notes': notes,
      'balance': balance,
    });
    return Customer.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Customer> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/customers/$id', data: data);
    return Customer.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/customers/$id', data: {'deleteReason': reason});
  }

  Future<Customer> adjustBalance(String id, {required double amount, required String type, String note = ''}) async {
    final res = await _api.request('POST', '/customers/$id/balance', data: {
      'amount': amount,
      'type': type,
      'note': note,
    });
    return Customer.fromJson(res['data'] as Map<String, dynamic>);
  }
}
