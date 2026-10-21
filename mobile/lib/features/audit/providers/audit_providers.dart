import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/audit_repository.dart';
import '../models/audit_log.dart';

class AuditFilter {
  final String? userId;
  final String? shopId;
  final String? actionType;
  final String? module;
  final String? status;

  const AuditFilter({this.userId, this.shopId, this.actionType, this.module, this.status});

  static const Object _unset = Object();

  AuditFilter copyWith({
    Object? userId = _unset,
    Object? shopId = _unset,
    Object? actionType = _unset,
    Object? module = _unset,
    Object? status = _unset,
  }) {
    return AuditFilter(
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      shopId: identical(shopId, _unset) ? this.shopId : shopId as String?,
      actionType: identical(actionType, _unset) ? this.actionType : actionType as String?,
      module: identical(module, _unset) ? this.module : module as String?,
      status: identical(status, _unset) ? this.status : status as String?,
    );
  }
}

class AuditState {
  final AsyncValue<AuditPage> logs;
  final AsyncValue<AuditStats> stats;
  final AuditFilter filter;

  const AuditState({
    this.logs = const AsyncValue.loading(),
    this.stats = const AsyncValue.loading(),
    this.filter = const AuditFilter(),
  });
}

class AuditController extends Notifier<AuditState> {
  @override
  AuditState build() {
    // Defer initial loads until build() completes (see dashboard providers).
    Future.microtask(() {
      if (!ref.mounted) return;
      _loadLogs();
      _loadStats();
    });
    return const AuditState();
  }

  Future<void> _loadLogs() async {
    final f = state.filter;
    try {
      final page = await ref.read(auditRepositoryProvider).getLogs(
            userId: f.userId,
            shopId: f.shopId,
            actionType: f.actionType,
            module: f.module,
            status: f.status,
          );
      state = AuditState(logs: AsyncValue.data(page), stats: state.stats, filter: state.filter);
    } catch (e, st) {
      state = AuditState(logs: AsyncValue.error(e, st), stats: state.stats, filter: state.filter);
    }
  }

  Future<void> _loadStats() async {
    final f = state.filter;
    try {
      final stats = await ref.read(auditRepositoryProvider).getStats(shopId: f.shopId);
      state = AuditState(logs: state.logs, stats: AsyncValue.data(stats), filter: state.filter);
    } catch (e, st) {
      state = AuditState(logs: state.logs, stats: AsyncValue.error(e, st), filter: state.filter);
    }
  }

  void setFilter(AuditFilter filter) {
    state = AuditState(logs: const AsyncValue.loading(), stats: const AsyncValue.loading(), filter: filter);
    _loadLogs();
    _loadStats();
  }

  void clearFilter() {
    state = AuditState(logs: const AsyncValue.loading(), stats: const AsyncValue.loading(), filter: const AuditFilter());
    _loadLogs();
    _loadStats();
  }

  Future<void> refresh() {
    _loadLogs();
    return _loadStats();
  }

  Future<bool> restore(String logId) async {
    try {
      await ref.read(auditRepositoryProvider).restore(logId);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final auditControllerProvider =
    NotifierProvider<AuditController, AuditState>(AuditController.new);

class AuditDetailState {
  final AsyncValue<AuditLog> data;

  const AuditDetailState({this.data = const AsyncValue.loading()});
}

class AuditDetailController extends Notifier<AuditDetailState> {
  @override
  AuditDetailState build() {
    final id = ref.watch(auditDetailIdProvider);
    _load(id);
    return const AuditDetailState();
  }

  Future<void> _load(String id) async {
    if (id.isEmpty) return;
    try {
      final log = await ref.read(auditRepositoryProvider).getLog(id);
      state = AuditDetailState(data: AsyncValue.data(log));
    } catch (e, st) {
      state = AuditDetailState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load(ref.read(auditDetailIdProvider));
}

class AuditDetailIdController extends Notifier<String> {
  @override
  String build() => '';

  void set(String id) => state = id;
}

final auditDetailIdProvider =
    NotifierProvider<AuditDetailIdController, String>(AuditDetailIdController.new);

final auditDetailControllerProvider =
    NotifierProvider<AuditDetailController, AuditDetailState>(AuditDetailController.new);
