class InventoryLog {
  final String id;
  final String productId;
  final String productName;
  final String actionType; // stock_in | stock_out
  final int quantity;
  final int previousStock;
  final int newStock;
  final String supplier;
  final String reason;
  final String performedByName;
  final String shopName;
  final DateTime? date;
  final List<Map<String, dynamic>> carpetPieces;
  final List<Map<String, dynamic>> qaleenSizes;
  final double length;

  const InventoryLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.actionType,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.supplier = '',
    this.reason = '',
    this.performedByName = '',
    this.shopName = '',
    this.date,
    this.carpetPieces = const [],
    this.qaleenSizes = const [],
    this.length = 0,
  });

  bool get isStockIn => actionType == 'stock_in';

  String get movementDetail {
    if (carpetPieces.isNotEmpty) {
      final dims = carpetPieces
          .map((p) => '${_fmt(p['width'])}x${_fmt(p['height'])}')
          .join(', ');
      return '$quantity sqft (${carpetPieces.length} piece${carpetPieces.length == 1 ? '' : 's'}: $dims)';
    }
    if (qaleenSizes.isNotEmpty) {
      final dims = qaleenSizes
          .map((s) => '${_fmt(s['width'])}x${_fmt(s['height'])} (${s['pieces']} pcs)')
          .join(', ');
      return '$quantity pcs ($dims)';
    }
    if (length > 0) {
      return '$quantity m';
    }
    return '';
  }

  static String _fmt(dynamic v) {
    final n = (v as num?)?.toDouble() ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    final performedBy = json['performedBy'];
    String pName = '';
    if (performedBy is Map<String, dynamic>) {
      pName = performedBy['name']?.toString() ?? '';
    }
    final shop = json['shop'];
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sName = shop['name']?.toString() ?? '';
    }
    return InventoryLog(
      id: (json['id'] ?? json['_id']).toString(),
      productId: (json['product'] is Map<String, dynamic>
              ? (json['product']['id'] ?? json['product']['_id'])
              : json['product'])
          ?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      actionType: json['actionType']?.toString() ?? 'stock_in',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      previousStock: (json['previousStock'] as num?)?.toInt() ?? 0,
      newStock: (json['newStock'] as num?)?.toInt() ?? 0,
      supplier: json['supplier']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      performedByName: pName,
      shopName: sName,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      carpetPieces: ((json['carpetPieces'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      qaleenSizes: ((json['qaleenSizes'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      length: (json['length'] as num?)?.toDouble() ?? 0,
    );
  }
}
