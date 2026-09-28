import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../models/shop.dart';

class ShopListState {
  final AsyncValue<List<Shop>> data;

  const ShopListState({this.data = const AsyncValue.loading()});
}

class ShopListController extends Notifier<ShopListState> {
  @override
  ShopListState build() {
    _load();
    return const ShopListState();
  }

  Future<void> _load() async {
    try {
      final shops = await ref.read(shopRepositoryProvider).getShops();
      state = ShopListState(data: AsyncValue.data(shops));
    } catch (e, st) {
      state = ShopListState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
}

final shopListControllerProvider =
    NotifierProvider<ShopListController, ShopListState>(ShopListController.new);
