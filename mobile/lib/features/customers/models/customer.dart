class CustomerTransaction {
  final double amount;
  final String type;
  final String note;
  final DateTime? date;

  const CustomerTransaction({
    required this.amount,
    required this.type,
    required this.note,
    this.date,
  });

  bool get isPayment => type == 'payment';

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) => CustomerTransaction(
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: json['type']?.toString() ?? 'charge',
        note: json['note']?.toString() ?? '',
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
      );
}

class CustomerRecentSale {
  final String invoiceNo;
  final double totalAmount;
  final String paymentMethod;
  final DateTime? createdAt;

  const CustomerRecentSale({
    required this.invoiceNo,
    required this.totalAmount,
    required this.paymentMethod,
    this.createdAt,
  });

  factory CustomerRecentSale.fromJson(Map<String, dynamic> json) => CustomerRecentSale(
        invoiceNo: json['invoiceNo']?.toString() ?? '',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        paymentMethod: json['paymentMethod']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String notes;
  final double balance;
  final double totalSpent;
  final int purchaseCount;
  final DateTime? lastPurchaseAt;
  final List<CustomerTransaction> transactions;
  final List<CustomerRecentSale> recentSales;
  final String? shopId;
  final String? shopName;
  final DateTime? createdAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.notes = '',
    this.balance = 0,
    this.totalSpent = 0,
    this.purchaseCount = 0,
    this.lastPurchaseAt,
    this.transactions = const [],
    this.recentSales = const [],
    this.shopId,
    this.shopName,
    this.createdAt,
  });

  bool get hasDue => balance > 0;

  factory Customer.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    String? sId;
    String? sName;
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id'])?.toString();
      sName = shop['name']?.toString();
    } else if (shop != null) {
      sId = shop.toString();
    }
    return Customer(
      id: (json['id'] ?? json['_id']).toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0,
      purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
      lastPurchaseAt: DateTime.tryParse(json['lastPurchaseAt']?.toString() ?? ''),
      transactions: (json['transactions'] as List?)
              ?.map((e) => CustomerTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentSales: (json['recentSales'] as List?)
              ?.map((e) => CustomerRecentSale.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      shopId: sId,
      shopName: sName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
