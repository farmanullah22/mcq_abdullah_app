class LoginPreview {
  final bool exists;
  final String? role;
  final String? name;
  final bool active;
  final List<ShopOption> shops;

  const LoginPreview({
    required this.exists,
    this.role,
    this.name,
    this.active = true,
    this.shops = const [],
  });

  bool get isManager => exists && role == 'manager';
  bool get isAdmin => exists && role == 'admin';

  factory LoginPreview.fromJson(Map<String, dynamic> json) {
    final shops = (json['shops'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => ShopOption.fromJson(e.cast<String, dynamic>()))
        .toList();
    return LoginPreview(
      exists: json['exists'] as bool? ?? false,
      role: json['role']?.toString(),
      name: json['name']?.toString(),
      active: json['active'] as bool? ?? true,
      shops: shops,
    );
  }
}

class ShopOption {
  final String id;
  final String name;

  const ShopOption({required this.id, required this.name});

  factory ShopOption.fromJson(Map<String, dynamic> json) => ShopOption(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
      );
}
