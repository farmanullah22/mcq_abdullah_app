class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.data = const {},
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: (json['id'] ?? json['_id']).toString(),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        type: json['type']?.toString() ?? 'system',
        isRead: json['isRead'] as bool? ?? false,
        data: json['data'] is Map<String, dynamic> ? (json['data'] as Map<String, dynamic>) : const {},
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}
