import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/notification_repository.dart';

class NotificationListState {
  final AsyncValue<NotificationPage> data;
  final int unread;

  const NotificationListState({this.data = const AsyncValue.loading(), this.unread = 0});
}

class NotificationController extends Notifier<NotificationListState> {
  @override
  NotificationListState build() {
    _load();
    return const NotificationListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref.read(notificationRepositoryProvider).getNotifications();
      state = NotificationListState(data: AsyncValue.data(page), unread: page.unread);
    } catch (e, st) {
      state = NotificationListState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();

  Future<void> markRead(String id) async {
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
      final page = state.data.value;
      if (page != null) {
        final updated = page.notifications.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
        state = NotificationListState(
          data: AsyncValue.data(NotificationPage(
            notifications: updated,
            unread: state.unread > 0 ? state.unread - 1 : 0,
            total: page.total,
            page: page.page,
            totalPages: page.totalPages,
          )),
          unread: state.unread > 0 ? state.unread - 1 : 0,
        );
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      final page = state.data.value;
      if (page != null) {
        final updated = page.notifications.map((n) => n.copyWith(isRead: true)).toList();
        state = NotificationListState(
          data: AsyncValue.data(NotificationPage(notifications: updated, unread: 0, total: page.total, page: page.page, totalPages: page.totalPages)),
          unread: 0,
        );
      }
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    try {
      await ref.read(notificationRepositoryProvider).delete(id);
      final page = state.data.value;
      if (page != null) {
        state = NotificationListState(
          data: AsyncValue.data(NotificationPage(
            notifications: page.notifications.where((n) => n.id != id).toList(),
            unread: page.unread,
            total: page.total,
            page: page.page,
            totalPages: page.totalPages,
          )),
          unread: page.unread,
        );
      }
    } catch (_) {}
  }

  /// Deletes every notification of the signed-in user and empties the list.
  Future<bool> deleteAll() async {
    try {
      await ref.read(notificationRepositoryProvider).deleteAll();
      state = NotificationListState(
        data: AsyncValue.data(NotificationPage(
          notifications: const [],
          unread: 0,
          total: 0,
          page: 1,
          totalPages: 1,
        )),
        unread: 0,
      );
      ref.read(unreadCountProvider.notifier).clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> decrementUnread() async {
    if (state.unread > 0) {
      state = NotificationListState(data: state.data, unread: state.unread - 1);
    }
  }
}

final notificationControllerProvider =
    NotifierProvider<NotificationController, NotificationListState>(NotificationController.new);

/// Fetches only the unread count (used by the app shell badge).
class UnreadCountController extends Notifier<int> {
  @override
  int build() {
    _fetch();
    return 0;
  }

  Future<void> _fetch() async {
    try {
      final count = await ref.read(notificationRepositoryProvider).unreadCount();
      state = count;
    } catch (_) {}
  }

  Future<void> refresh() => _fetch();

  void clear() {
    state = 0;
  }
}

final unreadCountProvider =
    NotifierProvider<UnreadCountController, int>(UnreadCountController.new);
