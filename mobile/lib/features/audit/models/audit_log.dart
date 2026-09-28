class AuditLog {
  final String id;
  final String actionType;
  final String module;
  final String recordType;
  final String recordId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String performedById;
  final String performedByName;
  final String userRole;
  final String shopId;
  final String shopName;
  final DateTime? timestamp;
  final String ipAddress;
  final String platform;
  final String remarks;
  final String status;

  const AuditLog({
    required this.id,
    required this.actionType,
    required this.module,
    this.recordType = '',
    this.recordId = '',
    this.oldData,
    this.newData,
    this.performedById = '',
    this.performedByName = '',
    this.userRole = '',
    this.shopId = '',
    this.shopName = '',
    this.timestamp,
    this.ipAddress = '',
    this.platform = '',
    this.remarks = '',
    this.status = 'success',
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    final performedBy = json['performedBy'];
    String pId = '';
    String pName = '';
    String pRole = '';
    if (performedBy is Map<String, dynamic>) {
      pId = (performedBy['id'] ?? performedBy['_id']).toString();
      pName = performedBy['name']?.toString() ?? '';
      pRole = performedBy['role']?.toString() ?? '';
    }
    final shop = json['shopId'];
    String sName = '';
    if (shop is Map<String, dynamic>) {
      sName = shop['name']?.toString() ?? '';
    }
    final device = json['deviceInfo'];
    String platform = '';
    if (device is Map<String, dynamic>) {
      platform = device['platform']?.toString() ?? '';
    }
    return AuditLog(
      id: (json['id'] ?? json['_id']).toString(),
      actionType: json['actionType']?.toString() ?? '',
      module: json['module']?.toString() ?? '',
      recordType: json['recordType']?.toString() ?? '',
      recordId: json['recordId']?.toString() ?? '',
      oldData: (json['oldData'] is Map<String, dynamic>) ? (json['oldData'] as Map<String, dynamic>) : null,
      newData: (json['newData'] is Map<String, dynamic>) ? (json['newData'] as Map<String, dynamic>) : null,
      performedById: pId,
      performedByName: json['performedByName']?.toString() ?? pName,
      userRole: json['userRole']?.toString() ?? pRole,
      shopId: json['shopId'] is String ? json['shopId'] as String : ((json['shopId'] as Map<String, dynamic>?)?['id'] ?? '').toString(),
      shopName: json['shopName']?.toString() ?? sName,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      ipAddress: json['ipAddress']?.toString() ?? '',
      platform: platform,
      remarks: json['remarks']?.toString() ?? '',
      status: json['status']?.toString() ?? 'success',
    );
  }
}
