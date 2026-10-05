import '../../../core/api/api_client.dart';
import '../models/khata_entry.dart';

class KhataPage {
  final List<KhataEntry> entries;
  final List<KhataBalance> balances;
  final KhataTotals totals;
  final int total;
  final int page;
  final int totalPages;

  const KhataPage({
    required this.entries,
    required this.balances,
    required this.totals,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class KhataRepository {
  KhataRepository(this._api);
  final ApiClient _api;

  Future<KhataPage> getEntries({
    String? customer,
    String? method,
    String? direction,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.request('GET', '/khata', query: {
      'customer': ?customer,
      'method': ?method,
      'direction': ?direction,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return KhataPage(
      entries: (data['entries'] as List)
          .map((e) => KhataEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      balances: (data['balances'] as List? ?? const [])
          .map((e) => KhataBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      totals: KhataTotals.fromJson(data['totals'] as Map<String, dynamic>? ?? const {}),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<KhataEntry> create({
    required String customerName,
    String customerNumber = '',
    required String direction,
    required double amount,
    String method = 'cash',
    DateTime? entryDate,
    String notes = '',
  }) async {
    final res = await _api.request('POST', '/khata', data: {
      'customerName': customerName,
      'customerNumber': customerNumber,
      'direction': direction,
      'amount': amount,
      'method': method,
      if (entryDate != null) 'entryDate': entryDate.toIso8601String(),
      'notes': notes,
    });
    return KhataEntry.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<KhataEntry> update(String id, Map<String, dynamic> data) async {
    final res = await _api.request('PUT', '/khata/$id', data: data);
    return KhataEntry.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> delete(String id, {String reason = ''}) async {
    await _api.request('DELETE', '/khata/$id', data: {'deleteReason': reason});
  }
}