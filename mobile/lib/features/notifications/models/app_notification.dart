import '../../../core/models/change_detail.dart';

export '../../../core/models/change_detail.dart' show ChangeDetail, ChangeFact;

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  // Structured detail of what happened (populated for manager actions).
  final List<ChangeDetail> changes;
  final List<ChangeFact> facts;
  final List<String> itemLines;
  final String actionType;
  final String shopName;
  final String performedByName;
  final String identity;
  final String auditLogId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.data = const {},
    this.createdAt,
    this.changes = const [],
    this.facts = const [],
    this.itemLines = const [],
    this.actionType = '',
    this.shopName = '',
    this.performedByName = '',
    this.identity = '',
    this.auditLogId = '',
  });

  /// True when the notification carries a readable breakdown of the change.
  bool get hasDetails => changes.isNotEmpty || facts.isNotEmpty || itemLines.isNotEmpty;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        data: data,
        createdAt: createdAt,
        changes: changes,
        facts: facts,
        itemLines: itemLines,
        actionType: actionType,
        shopName: shopName,
        performedByName: performedByName,
        identity: identity,
        auditLogId: auditLogId,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data =
        json['data'] is Map<String, dynamic> ? (json['data'] as Map<String, dynamic>) : const <String, dynamic>{};
    return AppNotification(
      id: (json['id'] ?? json['_id']).toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'system',
      isRead: json['isRead'] as bool? ?? false,
      data: data,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      changes: parseChangeDetails(data['changes']),
      facts: parseChangeFacts(data['facts']),
      itemLines: parseItemLines(data['itemLines']),
      actionType: data['actionType']?.toString() ?? '',
      shopName: data['shopName']?.toString() ?? '',
      performedByName: data['performedByName']?.toString() ?? '',
      identity: data['identity']?.toString() ?? '',
      auditLogId: data['auditLogId']?.toString() ?? '',
    );
  }
}
