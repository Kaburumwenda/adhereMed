class Department {
  final int id;
  final String name;
  final String? description;
  final bool isActive;
  final String? createdAt;

  Department({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'],
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'is_active': isActive,
      };
}
