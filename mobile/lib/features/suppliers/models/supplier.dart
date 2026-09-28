class SupplierTransaction {
  final double amount;
  final String type;
  final String note;
  final DateTime? date;

  const SupplierTransaction({
    required this.amount,
    required this.type,
    required this.note,
    this.date,
  });

  bool get isPayment => type == 'payment';

  factory SupplierTransaction.fromJson(Map<String, dynamic> json) => SupplierTransaction(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: json['type']?.toString() ?? 'charge',
        note: json['note']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
      );
}

class Supplier {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String notes;
  final double balance;
  final List<SupplierTransaction> transactions;
  final String? shopId;
  final String? shopName;
  final DateTime? createdAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.notes = '',
    this.balance = 0,
    this.transactions = const [],
    this.shopId,
    this.shopName,
    this.createdAt,
  });

  bool get hasDue => balance > 0;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    String? sId;
    String? sName;
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id'])?.toString();
      sName = shop['name']?.toString();
    } else if (shop != null) {
      sId = shop.toString();
    }
    return Supplier(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      transactions: (json['transactions'] as List?)
              ?.map((e) => SupplierTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      shopId: sId,
      shopName: sName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
