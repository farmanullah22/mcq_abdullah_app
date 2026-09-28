import '../../../core/api/api_client.dart';
import '../models/inventory_log.dart';

class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> stockIn({
    required String productId,
    required int quantity,
    String supplier = '',
    DateTime? date,
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    return _api.request('POST', '/inventory/in', data: {
      'productId': productId,
      'quantity': quantity,
      'supplier': supplier,
      if (date != null) 'date': date.toIso8601String(),
      'notes': notes,
      if (carpetPieces.isNotEmpty) 'carpetPieces': carpetPieces,
      if (qaleenSizes.isNotEmpty) 'qaleenSizes': qaleenSizes,
      if (length != null && length > 0) 'length': length,
    });
  }

  Future<Map<String, dynamic>> stockOut({
    required String productId,
    required int quantity,
    String reason = '',
    DateTime? date,
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    return _api.request('POST', '/inventory/out', data: {
      'productId': productId,
      'quantity': quantity,
      'reason': reason,
      if (date != null) 'date': date.toIso8601String(),
      'notes': notes,
      if (carpetPieces.isNotEmpty) 'carpetPieces': carpetPieces,
      if (qaleenSizes.isNotEmpty) 'qaleenSizes': qaleenSizes,
      if (length != null && length > 0) 'length': length,
    });
  }

  Future<Map<String, dynamic>> transfer({
    required String fromShopId,
    required String toShopId,
    required String productId,
    required int quantity,
    DateTime? date,
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    return _api.request('POST', '/inventory/transfer', data: {
      'fromShopId': fromShopId,
      'toShopId': toShopId,
      'productId': productId,
      'quantity': quantity,
      if (date != null) 'date': date.toIso8601String(),
      'notes': notes,
      if (carpetPieces.isNotEmpty) 'carpetPieces': carpetPieces,
      if (qaleenSizes.isNotEmpty) 'qaleenSizes': qaleenSizes,
      if (length != null && length > 0) 'length': length,
    });
  }

  Future<List<Map<String, dynamic>>> transferShops() async {
    final res = await _api.request('GET', '/inventory/shops');
    return (res['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> shopProducts(String shopId) async {
    final res = await _api.request('GET', '/inventory/products/$shopId');
    return (res['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<({List<InventoryLog> logs, int total})> history({
    String? actionType,
    String? productId,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.request('GET', '/inventory/history', query: {
      'actionType': ?actionType,
      'productId': ?productId,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return (
      logs: (data['logs'] as List).map((e) => InventoryLog.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }
}
