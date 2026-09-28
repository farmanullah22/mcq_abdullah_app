import '../../../core/api/api_client.dart';
import '../models/audit_log.dart';

class AuditPage {
  final List<AuditLog> logs;
  final int total;
  final int page;
  final int totalPages;

  const AuditPage({required this.logs, required this.total, required this.page, required this.totalPages});
}

class AuditStats {
  final int total;
  final int today;
  final int deleted;
  final List<Map<String, dynamic>> byAction;
  final List<Map<String, dynamic>> byUser;

  const AuditStats({
    this.total = 0,
    this.today = 0,
    this.deleted = 0,
    this.byAction = const [],
    this.byUser = const [],
  });

  factory AuditStats.fromJson(Map<String, dynamic> json) => AuditStats(
        total: (json['total'] as num?)?.toInt() ?? 0,
        today: (json['today'] as num?)?.toInt() ?? 0,
        deleted: (json['deleted'] as num?)?.toInt() ?? 0,
        byAction: (json['byAction'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
        byUser: (json['byUser'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? const [],
      );
}

class AuditRepository {
  AuditRepository(this._api);
  final ApiClient _api;

  Future<AuditPage> getLogs({
    String? userId,
    String? shopId,
    String? actionType,
    String? module,
    String? status,
    int page = 1,
    int limit = 30,
  }) async {
    final res = await _api.request('GET', '/audit', query: {
      'userId': ?userId,
      'shopId': ?shopId,
      'actionType': ?actionType,
      'module': ?module,
      'status': ?status,
      'page': '$page',
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    return AuditPage(
      logs: (data['logs'] as List).map((e) => AuditLog.fromJson(e as Map<String, dynamic>)).toList(),
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<AuditStats> getStats({int days = 30}) async {
    final res = await _api.request('GET', '/audit/stats', query: {'days': '$days'});
    return AuditStats.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AuditLog> getLog(String id) async {
    final res = await _api.request('GET', '/audit/$id');
    return AuditLog.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> restore(String logId) async {
    return _api.request('POST', '/audit/$logId/restore');
  }
}
