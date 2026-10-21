/// One field-level change, e.g.
/// `Selling price: Rs. 1,200 -> Rs. 1,350 (+Rs. 150)`.
class ChangeDetail {
  final String label;
  final String from;
  final String to;
  final String delta;

  const ChangeDetail({
    required this.label,
    this.from = '',
    this.to = '',
    this.delta = '',
  });

  bool get hasDelta => delta.isNotEmpty;

  factory ChangeDetail.fromJson(Map<String, dynamic> json) => ChangeDetail(
        label: json['label']?.toString() ?? '',
        from: json['from']?.toString() ?? '',
        to: json['to']?.toString() ?? '',
        delta: json['delta']?.toString() ?? '',
      );
}

/// A key fact about the affected record, e.g. `Quantity: 120`.
class ChangeFact {
  final String label;
  final String value;

  const ChangeFact({required this.label, this.value = ''});

  factory ChangeFact.fromJson(Map<String, dynamic> json) => ChangeFact(
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}

/// Parses a list of maps coming from the API into typed change objects.
List<ChangeDetail> parseChangeDetails(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => ChangeDetail.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<ChangeFact> parseChangeFacts(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => ChangeFact.fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<String> parseItemLines(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(growable: false);
}
