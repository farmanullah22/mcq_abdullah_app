import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../products/providers/product_providers.dart';
import '../models/inventory_log.dart';

class InventoryHistoryState {
  final AsyncValue<({List<InventoryLog> logs, int total})> data;
  final String? actionType;

  const InventoryHistoryState({this.data = const AsyncValue.loading(), this.actionType});
}

class InventoryHistoryController extends Notifier<InventoryHistoryState> {
  @override
  InventoryHistoryState build() {
    // Defer initial load until build() completes (see dashboard providers).
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const InventoryHistoryState();
  }

  Future<void> _load() async {
    try {
      final result = await ref.read(inventoryRepositoryProvider).history(actionType: state.actionType);
      state = InventoryHistoryState(data: AsyncValue.data(result), actionType: state.actionType);
    } catch (e, st) {
      state = InventoryHistoryState(data: AsyncValue.error(e, st), actionType: state.actionType);
    }
  }

  void setActionType(String? value) {
    state = InventoryHistoryState(actionType: value);
    _load();
  }

  Future<void> refresh() => _load();
}

final inventoryHistoryControllerProvider =
    NotifierProvider<InventoryHistoryController, InventoryHistoryState>(InventoryHistoryController.new);

class StockMutationState {
  final bool loading;
  final String? error;

  const StockMutationState({this.loading = false, this.error});
}

class StockMutationController extends Notifier<StockMutationState> {
  @override
  StockMutationState build() => const StockMutationState();

  Future<bool> stockIn({
    required String productId,
    required int quantity,
    String supplier = '',
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    state = const StockMutationState(loading: true);
    try {
      await ref.read(inventoryRepositoryProvider).stockIn(
            productId: productId,
            quantity: quantity,
            supplier: supplier,
            notes: notes,
            carpetPieces: carpetPieces,
            qaleenSizes: qaleenSizes,
            length: length,
          );
      state = const StockMutationState();
      ref.invalidate(inventoryHistoryControllerProvider);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = StockMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> stockOut({
    required String productId,
    required int quantity,
    String reason = '',
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    state = const StockMutationState(loading: true);
    try {
      await ref.read(inventoryRepositoryProvider).stockOut(
            productId: productId,
            quantity: quantity,
            reason: reason,
            notes: notes,
            carpetPieces: carpetPieces,
            qaleenSizes: qaleenSizes,
            length: length,
          );
      state = const StockMutationState();
      ref.invalidate(inventoryHistoryControllerProvider);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = StockMutationState(error: e.toString());
      return false;
    }
  }
  Future<bool> transfer({
    required String fromShopId,
    required String toShopId,
    required String productId,
    required int quantity,
    String notes = '',
    List<Map<String, dynamic>> carpetPieces = const [],
    List<Map<String, dynamic>> qaleenSizes = const [],
    double? length,
  }) async {
    state = const StockMutationState(loading: true);
    try {
      await ref.read(inventoryRepositoryProvider).transfer(
            fromShopId: fromShopId,
            toShopId: toShopId,
            productId: productId,
            quantity: quantity,
            notes: notes,
            carpetPieces: carpetPieces,
            qaleenSizes: qaleenSizes,
            length: length,
          );
      state = const StockMutationState();
      ref.invalidate(inventoryHistoryControllerProvider);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      state = StockMutationState(error: e.toString());
      return false;
    }
  }
}

final stockMutationControllerProvider =
    NotifierProvider<StockMutationController, StockMutationState>(StockMutationController.new);
