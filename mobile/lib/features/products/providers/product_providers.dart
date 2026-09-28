import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/product_repository.dart';
import '../models/product.dart';

class ProductListState {
  final AsyncValue<ProductPage> data;
  final String search;
  final String? categoryId;
  final bool lowStockOnly;

  const ProductListState({
    this.data = const AsyncValue.loading(),
    this.search = '',
    this.categoryId,
    this.lowStockOnly = false,
  });

  ProductListState copyWith({
    AsyncValue<ProductPage>? data,
    String? search,
    String? categoryId,
    bool? lowStockOnly,
  }) {
    return ProductListState(
      data: data ?? this.data,
      search: search ?? this.search,
      categoryId: categoryId,
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    );
  }
}

class ProductListController extends Notifier<ProductListState> {
  @override
  ProductListState build() {
    // Defer initial load until build() completes (see dashboard providers).
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const ProductListState();
  }

  Future<void> _load() async {
    state = state.copyWith(data: const AsyncValue.loading());
    try {
      final page = await ref.read(productRepositoryProvider).getProducts(
            search: state.search,
            categoryId: state.categoryId,
            lowStock: state.lowStockOnly,
          );
      state = state.copyWith(data: AsyncValue.data(page));
    } catch (e, st) {
      state = state.copyWith(data: AsyncValue.error(e, st));
    }
  }

  void setSearch(String value) {
    if (state.search == value) return;
    state = state.copyWith(search: value);
    _load();
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
    _load();
  }

  void setLowStockOnly(bool value) {
    state = state.copyWith(lowStockOnly: value);
    _load();
  }

  Future<void> refresh() => _load();
}

final productListControllerProvider =
    NotifierProvider<ProductListController, ProductListState>(ProductListController.new);

class ProductMutationState {
  final bool loading;
  final String? error;
  final Product? product;

  const ProductMutationState({this.loading = false, this.error, this.product});
}

class ProductMutationController extends Notifier<ProductMutationState> {
  @override
  ProductMutationState build() => const ProductMutationState();

  Future<bool> create(Map<String, dynamic> data) async {
    state = const ProductMutationState(loading: true);
    try {
      final product = await ref.read(productRepositoryProvider).create(data);
      state = ProductMutationState(product: product);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = ProductMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    state = const ProductMutationState(loading: true);
    try {
      final product = await ref.read(productRepositoryProvider).update(id, data);
      state = ProductMutationState(product: product);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = ProductMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const ProductMutationState(loading: true);
    try {
      await ref.read(productRepositoryProvider).delete(id, reason: reason);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = ProductMutationState(error: e.toString());
      return false;
    }
  }

  void reset() => state = const ProductMutationState();
}

final productMutationControllerProvider =
    NotifierProvider<ProductMutationController, ProductMutationState>(ProductMutationController.new);
