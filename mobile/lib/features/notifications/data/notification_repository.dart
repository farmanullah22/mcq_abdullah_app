import '../../../core/api/api_client.dart';
import '../models/app_notification.dart';

class NotificationPage {
  final List<AppNotification> notifications;
  final int unread;
  final int total;
  final int page;
  final int totalPages;

  const NotificationPage({
    required this.notifications,
    this.unread = 0,
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
  });
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;

  Future<NotificationPage> getNotifications({int page = 1, int limit = 30}) async {
    final res = await _api.request('GET', '/notifications', query: {'page': '$page', 'limit': '$limit'});
    final data = res['data'] as Map<String, dynamic>;
    return NotificationPage(
      notifications: (data['notifications'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      unread: (data['unread'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? 0,
      page: (data['page'] as num?)?.toInt() ?? 1,
      totalPages: (data['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<int> unreadCount() async {
    final res = await _api.request('GET', '/notifications/unread-count');
    return (res['data'] as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<void> markRead(String id) async {
    await _api.request('PUT', '/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.request('PUT', '/notifications/read-all');
  }

  Future<void> delete(String id) async {
    await _api.request('DELETE', '/notifications/$id');
  }

  Future<void> registerToken(String fcmToken) async {
    await _api.request('POST', '/notifications/token', data: {'fcmToken': fcmToken});
  }
}
