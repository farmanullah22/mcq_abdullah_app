class KhataEntry {
  final String id;
  final String customerName;
  final String customerNumber;
  final String direction; // 'in' | 'out'
  final double amount;
  final String method;
  final DateTime? entryDate;
  final String notes;
  final DateTime? createdAt;

  const KhataEntry({
    required this.id,
    required this.customerName,
    this.customerNumber = '',
    required this.direction,
    required this.amount,
    this.method = 'cash',
    this.entryDate,
    this.notes = '',
    this.createdAt,
  });

  /// Money the admin handed over.
  bool get isGiven => direction == 'out';

  /// Money the admin took back.
  bool get isReceived => direction == 'in';

  factory KhataEntry.fromJson(Map<String, dynamic> json) {
    return KhataEntry(
      id: (json['id'] ?? json['_id']).toString(),
      customerName: json['customerName']?.toString() ?? '',
      customerNumber: json['customerNumber']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'out',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method']?.toString() ?? 'cash',
      entryDate: DateTime.tryParse(json['entryDate']?.toString() ?? ''),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Running per-customer figures returned alongside the page of entries.
class KhataBalance {
  final String customerName;
  final String customerNumber;
  final double given;
  final double received;
  final double outstanding;
  final int entryCount;
  final DateTime? lastActivity;

  const KhataBalance({
    required this.customerName,
    this.customerNumber = '',
    required this.given,
    required this.received,
    required this.outstanding,
    this.entryCount = 0,
    this.lastActivity,
  });

  factory KhataBalance.fromJson(Map<String, dynamic> json) {
    return KhataBalance(
      customerName: json['customerName']?.toString() ?? '',
      customerNumber: json['customerNumber']?.toString() ?? '',
      given: (json['given'] as num?)?.toDouble() ?? 0,
      received: (json['received'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
      lastActivity: DateTime.tryParse(json['lastActivity']?.toString() ?? ''),
    );
  }
}

class KhataTotals {
  final double given;
  final double received;
  final double outstanding;
  final int entryCount;

  const KhataTotals({
    this.given = 0,
    this.received = 0,
    this.outstanding = 0,
    this.entryCount = 0,
  });

  factory KhataTotals.fromJson(Map<String, dynamic> json) {
    return KhataTotals(
      given: (json['given'] as num?)?.toDouble() ?? 0,
      received: (json['received'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ?? 0,
      entryCount: (json['entryCount'] as num?)?.toInt() ?? 0,
    );
  }
}