import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../models/category.dart';

class CategoryListState {
  final AsyncValue<List<Category>> data;

  const CategoryListState({this.data = const AsyncValue.loading()});
}

class CategoryListController extends Notifier<CategoryListState> {
  @override
  CategoryListState build() {
    _load();
    return const CategoryListState();
  }

  Future<void> _load() async {
    try {
      final categories = await ref.read(categoryRepositoryProvider).getCategories();
      state = CategoryListState(data: AsyncValue.data(categories));
    } catch (e, st) {
      state = CategoryListState(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
}

final categoryListControllerProvider =
    NotifierProvider<CategoryListController, CategoryListState>(CategoryListController.new);

class CategoryMutationState {
  final bool loading;
  final String? error;

  const CategoryMutationState({this.loading = false, this.error});
}

class CategoryMutationController extends Notifier<CategoryMutationState> {
  @override
  CategoryMutationState build() => const CategoryMutationState();

  Future<bool> create(String name, {String description = ''}) async {
    state = const CategoryMutationState(loading: true);
    try {
      await ref.read(categoryRepositoryProvider).create(name, description: description);
      ref.invalidate(categoryListControllerProvider);
      state = const CategoryMutationState();
      return true;
    } catch (e) {
      state = CategoryMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> update(String id, String name, {String description = ''}) async {
    state = const CategoryMutationState(loading: true);
    try {
      await ref.read(categoryRepositoryProvider).update(id, name, description: description);
      ref.invalidate(categoryListControllerProvider);
      state = const CategoryMutationState();
      return true;
    } catch (e) {
      state = CategoryMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const CategoryMutationState(loading: true);
    try {
      await ref.read(categoryRepositoryProvider).delete(id, reason: reason);
      ref.invalidate(categoryListControllerProvider);
      state = const CategoryMutationState();
      return true;
    } catch (e) {
      state = CategoryMutationState(error: e.toString());
      return false;
    }
  }
}

final categoryMutationControllerProvider =
    NotifierProvider<CategoryMutationController, CategoryMutationState>(CategoryMutationController.new);
