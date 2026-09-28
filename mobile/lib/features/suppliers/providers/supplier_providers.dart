import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/supplier_repository.dart';

class SupplierListState {
  final AsyncValue<SupplierPage> data;
  final String search;

  const SupplierListState({this.data = const AsyncValue.loading(), this.search = ''});
}

class SupplierListController extends Notifier<SupplierListState> {
  @override
  SupplierListState build() {
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const SupplierListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref
          .read(supplierRepositoryProvider)
          .getSuppliers(search: state.search);
      state = SupplierListState(data: AsyncValue.data(page), search: state.search);
    } catch (e, st) {
      state = SupplierListState(data: AsyncValue.error(e, st), search: state.search);
    }
  }

  void setSearch(String value) {
    if (state.search == value) return;
    state = SupplierListState(search: value);
    _load();
  }

  Future<void> refresh() => _load();
}

final supplierListControllerProvider =
    NotifierProvider<SupplierListController, SupplierListState>(SupplierListController.new);

class SupplierMutationState {
  final bool loading;
  final String? error;

  const SupplierMutationState({this.loading = false, this.error});
}

class SupplierMutationController extends Notifier<SupplierMutationState> {
  @override
  SupplierMutationState build() => const SupplierMutationState();

  Future<bool> create({
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String city = '',
    String notes = '',
    double balance = 0,
  }) async {
    state = const SupplierMutationState(loading: true);
    try {
      await ref.read(supplierRepositoryProvider).create(
            name: name,
            phone: phone,
            email: email,
            address: address,
            city: city,
            notes: notes,
            balance: balance,
          );
      state = const SupplierMutationState();
      ref.invalidate(supplierListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = SupplierMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    state = const SupplierMutationState(loading: true);
    try {
      await ref.read(supplierRepositoryProvider).update(id, data);
      state = const SupplierMutationState();
      ref.invalidate(supplierListControllerProvider);
      return true;
    } catch (e) {
      state = SupplierMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const SupplierMutationState(loading: true);
    try {
      await ref.read(supplierRepositoryProvider).delete(id, reason: reason);
      state = const SupplierMutationState();
      ref.invalidate(supplierListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = SupplierMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> adjustBalance(String id, {required double amount, required String type, String note = ''}) async {
    state = const SupplierMutationState(loading: true);
    try {
      await ref.read(supplierRepositoryProvider).adjustBalance(id, amount: amount, type: type, note: note);
      state = const SupplierMutationState();
      ref.invalidate(supplierListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = SupplierMutationState(error: e.toString());
      return false;
    }
  }
}

final supplierMutationControllerProvider =
    NotifierProvider<SupplierMutationController, SupplierMutationState>(SupplierMutationController.new);
