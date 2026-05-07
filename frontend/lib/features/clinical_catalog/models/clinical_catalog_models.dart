class AllergyModel {
  final int id;
  final String name;
  final String category;
  final String categoryDisplay;
  final String description;
  final String commonSymptoms;
  final bool isActive;

  const AllergyModel({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryDisplay,
    required this.description,
    required this.commonSymptoms,
    required this.isActive,
  });

  factory AllergyModel.fromJson(Map<String, dynamic> json) => AllergyModel(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        categoryDisplay: json['category_display'] as String? ?? json['category'] as String,
        description: json['description'] as String? ?? '',
        commonSymptoms: json['common_symptoms'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'description': description,
        'common_symptoms': commonSymptoms,
        'is_active': isActive,
      };

  AllergyModel copyWith({
    String? name,
    String? category,
    String? description,
    String? commonSymptoms,
    bool? isActive,
  }) =>
      AllergyModel(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        categoryDisplay: categoryDisplay,
        description: description ?? this.description,
        commonSymptoms: commonSymptoms ?? this.commonSymptoms,
        isActive: isActive ?? this.isActive,
      );
}

class ChronicConditionModel {
  final int id;
  final String name;
  final String category;
  final String categoryDisplay;
  final String icdCode;
  final String description;
  final bool isActive;

  const ChronicConditionModel({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryDisplay,
    required this.icdCode,
    required this.description,
    required this.isActive,
  });

  factory ChronicConditionModel.fromJson(Map<String, dynamic> json) =>
      ChronicConditionModel(
        id: json['id'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        categoryDisplay: json['category_display'] as String? ?? json['category'] as String,
        icdCode: json['icd_code'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'icd_code': icdCode,
        'description': description,
        'is_active': isActive,
      };

  ChronicConditionModel copyWith({
    String? name,
    String? category,
    String? icdCode,
    String? description,
    bool? isActive,
  }) =>
      ChronicConditionModel(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        categoryDisplay: categoryDisplay,
        icdCode: icdCode ?? this.icdCode,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
      );
}
