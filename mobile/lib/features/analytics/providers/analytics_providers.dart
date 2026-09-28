import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/analytics_repository.dart';

class AnalyticsState {
  final AsyncValue<AnalyticsData> data;

  const AnalyticsState({this.data = const AsyncValue.loading()});
}

class AnalyticsController extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    _load();
    return const AnalyticsState();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(analyticsRepositoryProvider).getAnalytics();
      state = AnalyticsState(data: AsyncValue.data(data));
    } catch (e, st) {
      state = AnalyticsState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
}

final analyticsControllerProvider =
    NotifierProvider<AnalyticsController, AnalyticsState>(AnalyticsController.new);
