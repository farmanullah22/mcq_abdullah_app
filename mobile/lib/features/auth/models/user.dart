class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'admin' | 'manager'
  final String? assignedShopId;
  final String? assignedShopName;
  final String? assignedShopType; // 'warehouse' | 'branch'
  final String? fcmToken;
  final bool notificationEnabled;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.role,
    this.assignedShopId,
    this.assignedShopName,
    this.assignedShopType,
    this.fcmToken,
    this.notificationEnabled = true,
  });

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isWarehouseManager => isManager && assignedShopType == 'warehouse';

  factory User.fromJson(Map<String, dynamic> json) {
    final assigned = json['assignedShop'];
    String? shopId;
    String? shopName;
    String? shopType;
    if (assigned is Map<String, dynamic>) {
      shopId = assigned['id']?.toString() ?? assigned['_id']?.toString();
      shopName = assigned['name']?.toString();
      shopType = (assigned['shopType']?.toString() ?? '')
          .isNotEmpty
          ? assigned['shopType'].toString()
          : (RegExp(r'warehouse', caseSensitive: false).hasMatch(shopName ?? '') ? 'warehouse' : 'branch');
    } else if (assigned != null) {
      shopId = assigned.toString();
    } else {
      shopId = json['assignedShopId']?.toString();
      shopName = json['assignedShopName']?.toString();
    }
    return User(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'manager',
      assignedShopId: shopId,
      assignedShopName: shopName,
      assignedShopType: shopType,
      fcmToken: json['fcmToken']?.toString(),
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'assignedShopId': assignedShopId,
        'assignedShopName': assignedShopName,
        'assignedShopType': assignedShopType,
        'notificationEnabled': notificationEnabled,
      };
}
