class Expense {
  final String id;
  final String shopId;
  final String shopName;
  final String category;
  final double amount;
  final DateTime? expenseDate;
  final String description;
  final String createdByName;
  final DateTime? createdAt;

  const Expense({
    required this.id,
    required this.shopId,
    this.shopName = '',
    required this.category,
    required this.amount,
    this.expenseDate,
    this.description = '',
    this.createdByName = '',
    this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'];
    String sId = (json['shopId'] ?? json['shop'])?.toString() ?? '';
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sId = (shop['id'] ?? shop['_id']).toString();
      sName = shop['name']?.toString() ?? '';
    }
    final createdBy = json['createdBy'];
    String cbName = '';
    if (createdBy is Map<String, dynamic>) {
      cbName = createdBy['name']?.toString() ?? '';
    }
    return Expense(
      id: (json['id'] ?? json['_id']).toString(),
      shopId: sId,
      shopName: sName,
      category: json['category']?.toString() ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      expenseDate: DateTime.tryParse(json['expenseDate']?.toString() ?? ''),
      description: json['description']?.toString() ?? '',
      createdByName: cbName,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}
