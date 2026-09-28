import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';

class TransferShopMeta {
  final String id;
  final String name;
  final String address;
  final String shopType; // 'warehouse' | 'branch'

  const TransferShopMeta({
    required this.id,
    required this.name,
    required this.address,
    required this.shopType,
  });

  bool get isWarehouse => shopType == 'warehouse';

  factory TransferShopMeta.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    var type = json['shopType']?.toString() ?? '';
    if (type.isEmpty) type = RegExp(r'warehouse', caseSensitive: false).hasMatch(name) ? 'warehouse' : 'branch';
    return TransferShopMeta(
      id: (json['id'] ?? json['_id']).toString(),
      name: name,
      address: json['address']?.toString() ?? '',
      shopType: type,
    );
  }
}

class TransferShopMetaState {
  final AsyncValue<List<TransferShopMeta>> shops;
  const TransferShopMetaState({this.shops = const AsyncValue.loading()});

  TransferShopMeta? get warehouse {
    return shops.when(
      loading: () => null,
      error: (_, _) => null,
      data: (list) {
        for (final s in list) {
          if (s.isWarehouse) return s;
        }
        return null;
      },
    );
  }
}

class TransferShopMetaController extends Notifier<TransferShopMetaState> {
  @override
  TransferShopMetaState build() {
    Future.microtask(() {
      if (ref.mounted) _load();
    });
    return const TransferShopMetaState();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(inventoryRepositoryProvider).transferShops();
      final shops = res.map(TransferShopMeta.fromJson).toList();
      state = TransferShopMetaState(shops: AsyncValue.data(shops));
    } catch (e, st) {
      state = TransferShopMetaState(shops: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() => _load();
}

final transferShopMetaControllerProvider =
    NotifierProvider<TransferShopMetaController, TransferShopMetaState>(TransferShopMetaController.new);