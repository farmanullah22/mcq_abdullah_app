class Shop {
  final String id;
  final String name;
  final String address;
  final String contactNumber;
  final String? managerId;
  final String? managerName;

  const Shop({
    required this.id,
    required this.name,
    this.address = '',
    this.contactNumber = '',
    this.managerId,
    this.managerName,
  });

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
      address: json['address']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      managerId: mgrId,
      managerName: mgrName,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'contactNumber': contactNumber,
        'manager': managerId,
      };
}
