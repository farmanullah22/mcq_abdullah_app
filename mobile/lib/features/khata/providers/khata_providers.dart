import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../data/khata_repository.dart';

class KhataListState {
  final AsyncValue<KhataPage> data;
  final String? customer;
  final String? method;
  final String? direction;
  final bool searching;

  const KhataListState({
    this.data = const AsyncValue.loading(),
    this.customer,
    this.method,
    this.direction,
    this.searching = false,
  });

  KhataListState copyWith({
    AsyncValue<KhataPage>? data,
    String? customer,
    String? method,
    String? direction,
    bool? searching,
    bool clearCustomer = false,
    bool clearMethod = false,
    bool clearDirection = false,
  }) {
    return KhataListState(
      data: data ?? this.data,
      customer: clearCustomer ? null : (customer ?? this.customer),
      method: clearMethod ? null : (method ?? this.method),
      direction: clearDirection ? null : (direction ?? this.direction),
      searching: searching ?? this.searching,
    );
  }
}

class KhataListController extends Notifier<KhataListState> {
  @override
  KhataListState build() {
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const KhataListState();
  }

  Future<void> _load() async {
    try {
      final page = await ref.read(khataRepositoryProvider).getEntries(
            customer: state.searching ? state.customer : null,
            method: state.method,
            direction: state.direction,
          );
      state = state.copyWith(data: AsyncValue.data(page));
    } catch (e, st) {
      state = state.copyWith(data: AsyncValue.error(e, st));
    }
  }

  void setFilters({String? customer, String? method, String? direction}) {
    state = state.copyWith(
      customer: customer,
      clearCustomer: customer == null,
      method: method,
      clearMethod: method == null,
      direction: direction,
      clearDirection: direction == null,
    );
    _load();
  }

  Future<void> refresh() => _load();
}

final khataListControllerProvider =
    NotifierProvider<KhataListController, KhataListState>(KhataListController.new);

class KhataMutationState {
  final bool loading;
  final String? error;

  const KhataMutationState({this.loading = false, this.error});
}

class KhataMutationController extends Notifier<KhataMutationState> {
  @override
  KhataMutationState build() => const KhataMutationState();

  Future<bool> create({
    required String customerName,
    String customerNumber = '',
    required String direction,
    required double amount,
    String method = 'cash',
    DateTime? entryDate,
    String notes = '',
  }) async {
    state = const KhataMutationState(loading: true);
    try {
      await ref.read(khataRepositoryProvider).create(
            customerName: customerName,
            customerNumber: customerNumber,
            direction: direction,
            amount: amount,
            method: method,
            entryDate: entryDate,
            notes: notes,
          );
      state = const KhataMutationState();
      ref.invalidate(khataListControllerProvider);
      return true;
    } catch (e) {
      state = KhataMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> update(
    String id, {
    required String customerName,
    String customerNumber = '',
    required String direction,
    required double amount,
    String method = 'cash',
    DateTime? entryDate,
    String notes = '',
  }) async {
    state = const KhataMutationState(loading: true);
    try {
      await ref.read(khataRepositoryProvider).update(id, {
        'customerName': customerName,
        'customerNumber': customerNumber,
        'direction': direction,
        'amount': amount,
        'method': method,
        if (entryDate != null) 'entryDate': entryDate.toIso8601String(),
        'notes': notes,
      });
      state = const KhataMutationState();
      ref.invalidate(khataListControllerProvider);
      return true;
    } catch (e) {
      state = KhataMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> delete(String id, {String reason = ''}) async {
    state = const KhataMutationState(loading: true);
    try {
      await ref.read(khataRepositoryProvider).delete(id, reason: reason);
      state = const KhataMutationState();
      ref.invalidate(khataListControllerProvider);
      return true;
    } catch (e) {
      state = KhataMutationState(error: e.toString());
      return false;
    }
  }
}

final khataMutationControllerProvider =
    NotifierProvider<KhataMutationController, KhataMutationState>(KhataMutationController.new);