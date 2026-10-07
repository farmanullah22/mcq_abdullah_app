class Shop {
  final String id;
  final String name;
  final String shopType;
  final String address;
  final String contactNumber;
  final String? managerId;
  final String? managerName;

  const Shop({
    required this.id,
    required this.name,
    this.shopType = 'branch',
    this.address = '',
    this.contactNumber = '',
    this.managerId,
    this.managerName,
  });

  bool get isWarehouse => shopType == 'warehouse';

  factory Shop.fromJson(Map<String, dynamic> json) {
    final manager = json['manager'];
    String? mgrId;
    String? mgrName;
    if (manager is Map<String, dynamic>) {
      mgrId = (manager['id'] ?? manager['_id'])?.toString();
      mgrName = manager['name']?.toString();
    } else if (manager != null) {
      mgrId = manager.toString();
    }
    return Shop(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      shopType: json['shopType']?.toString() ?? 'branch',
      address: json['address']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      managerId: mgrId,
      managerName: mgrName,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'shopType': shopType,
        'address': address,
        'contactNumber': contactNumber,
        'manager': managerId,
      };
}
