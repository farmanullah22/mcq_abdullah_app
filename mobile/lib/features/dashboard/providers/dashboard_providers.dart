import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/dashboard_data.dart';

class DashboardState {
  final AsyncValue<DashboardData> data;
  final String? selectedShopId;
  final List<({String id, String name})> shops;

  const DashboardState({
    this.data = const AsyncValue.loading(),
    this.selectedShopId,
    this.shops = const [],
  });

  DashboardState copyWith({
    AsyncValue<DashboardData>? data,
    String? selectedShopId,
    List<({String id, String name})>? shops,
    bool clearShop = false,
  }) {
    return DashboardState(
      data: data ?? this.data,
      selectedShopId: clearShop ? null : (selectedShopId ?? this.selectedShopId),
      shops: shops ?? this.shops,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    // Rebuild whenever the signed-in user changes so a previous session's
    // selectedShopId can never leak into a new session (e.g. manager -> admin).
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    final isAdmin = user?.isAdmin ?? true;
    // Defer initial loads until build() completes; touching `state` here
    // would read this provider before it is initialized (Riverpod readSelf).
    Future.microtask(() {
      if (!ref.mounted) return;
      _loadShops();
      _load();
    });
    return DashboardState(
      selectedShopId: isAdmin ? null : user?.assignedShopId,
      shops: isAdmin
          ? const []
          : (user?.assignedShopId != null
              ? [(id: user!.assignedShopId!, name: user.assignedShopName ?? 'My Shop')]
              : const []),
    );
  }

  Future<void> _loadShops() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isAdmin == false) return;
    try {
      final shops = await ref.read(shopRepositoryProvider).getShops();
      state = state.copyWith(
        shops: shops.map((s) => (id: s.id, name: s.name)).toList(),
      );
    } catch (_) {
      // shops load best-effort
    }
  }

  Future<void> _load() async {
    state = state.copyWith(data: const AsyncValue.loading());
    try {
      final user = ref.read(authControllerProvider).user;
      final isAdmin = user?.isAdmin ?? true;
      final data = await ref.read(dashboardRepositoryProvider).getDashboard(
            shopId: isAdmin ? null : (user?.assignedShopId ?? state.selectedShopId),
          );
      state = state.copyWith(data: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(data: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() async {
    await _load();
  }

  void selectShop(String? shopId) {
    state = state.copyWith(selectedShopId: shopId);
    _load();
  }

  // Re-fetches after quick actions (add product, stock changes, sales).
  Future<void> reload() => _load();
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);

final shopDetailProvider = FutureProvider.family<DashboardData, String>((ref, shopId) {
  return ref.watch(dashboardRepositoryProvider).getDashboard(shopId: shopId);
});

// Full branch command-center payload (customers, products, receivables,
// staff, recent sales/expenses) for a single branch. Admin only.
final shopOverviewProvider = FutureProvider.family<ShopOverview, String>((ref, shopId) {
  return ref.watch(dashboardRepositoryProvider).getShopOverview(shopId);
});
