class Category {
  final String id;
  final String name;
  final String description;

  const Category({required this.id, required this.name, this.description = ''});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['id'] ?? json['_id']).toString(),
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}
