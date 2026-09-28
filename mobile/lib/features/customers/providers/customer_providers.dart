import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/customer_repository.dart';

class CustomerListState {
  final AsyncValue<CustomerPage> data;
  final String search;

  const CustomerListState({this.data = const AsyncValue.loading(), this.search = ''});
}

class CustomerListController extends Notifier<CustomerListState> {
  @override
  CustomerListState build() {
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const CustomerListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref
          .read(customerRepositoryProvider)
          .getCustomers(search: state.search);
      state = CustomerListState(data: AsyncValue.data(page), search: state.search);
    } catch (e, st) {
      state = CustomerListState(data: AsyncValue.error(e, st), search: state.search);
    }
  }

  void setSearch(String value) {
    if (state.search == value) return;
    state = CustomerListState(search: value);
    _load();
  }

  Future<void> refresh() => _load();
}

final customerListControllerProvider =
    NotifierProvider<CustomerListController, CustomerListState>(CustomerListController.new);

class CustomerMutationState {
  final bool loading;
  final String? error;

  const CustomerMutationState({this.loading = false, this.error});
}

class CustomerMutationController extends Notifier<CustomerMutationState> {
  @override
  CustomerMutationState build() => const CustomerMutationState();

  Future<bool> create({
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String city = '',
    String notes = '',
    double balance = 0,
  }) async {
    state = const CustomerMutationState(loading: true);
    try {
      await ref.read(customerRepositoryProvider).create(
            name: name,
            phone: phone,
            email: email,
            address: address,
            city: city,
            notes: notes,
            balance: balance,
          );
      state = const CustomerMutationState();
      ref.invalidate(customerListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = CustomerMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> update(String id, Map<String, dynamic> data) async {
    state = const CustomerMutationState(loading: true);
    try {
      await ref.read(customerRepositoryProvider).update(id, data);
      state = const CustomerMutationState();
      ref.invalidate(customerListControllerProvider);
      return true;
    } catch (e) {
      state = CustomerMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const CustomerMutationState(loading: true);
    try {
      await ref.read(customerRepositoryProvider).delete(id, reason: reason);
      state = const CustomerMutationState();
      ref.invalidate(customerListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = CustomerMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> adjustBalance(String id, {required double amount, required String type, String note = ''}) async {
    state = const CustomerMutationState(loading: true);
    try {
      await ref.read(customerRepositoryProvider).adjustBalance(id, amount: amount, type: type, note: note);
      state = const CustomerMutationState();
      ref.invalidate(customerListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = CustomerMutationState(error: e.toString());
      return false;
    }
  }
}

final customerMutationControllerProvider =
    NotifierProvider<CustomerMutationController, CustomerMutationState>(CustomerMutationController.new);
