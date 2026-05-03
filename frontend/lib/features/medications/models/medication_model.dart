class Medication {
  final int id;
  final String genericName;
  final List<String> brandNames;
  final String category;
  final String? subcategory;
  final String dosageForm;
  final String? strength;
  final String? unit;
  final String? description;
  final bool requiresPrescription;
  final String? controlledSubstanceClass;
  final String? sideEffects;
  final String? contraindications;
  final bool isActive;
  final String? createdAt;

  Medication({
    required this.id,
    required this.genericName,
    this.brandNames = const [],
    required this.category,
    this.subcategory,
    required this.dosageForm,
    this.strength,
    this.unit,
    this.description,
    this.requiresPrescription = true,
    this.controlledSubstanceClass,
    this.sideEffects,
    this.contraindications,
    this.isActive = true,
    this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'],
        genericName: json['generic_name'] ?? '',
        brandNames: (json['brand_names'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        category: json['category'] ?? '',
        subcategory: json['subcategory'],
        dosageForm: json['dosage_form'] ?? '',
        strength: json['strength'],
        unit: json['unit'],
        description: json['description'],
        requiresPrescription: json['requires_prescription'] ?? true,
        controlledSubstanceClass: json['controlled_substance_class'],
        sideEffects: json['side_effects'],
        contraindications: json['contraindications'],
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'generic_name': genericName,
        'brand_names': brandNames,
        'category': category,
        'subcategory': subcategory ?? '',
        'dosage_form': dosageForm,
        'strength': strength ?? '',
        'unit': unit ?? '',
        'description': description ?? '',
        'requires_prescription': requiresPrescription,
        'controlled_substance_class': controlledSubstanceClass ?? '',
        'side_effects': sideEffects ?? '',
        'contraindications': contraindications ?? '',
        'is_active': isActive,
      };

  String get label {
    final s = strength?.isNotEmpty == true ? ' $strength' : '';
    return '$genericName$s (${_formLabel(dosageForm)})';
  }

  static String _formLabel(String form) {
    const map = {
      'tablet': 'Tablet',
      'capsule': 'Capsule',
      'syrup': 'Syrup',
      'injection': 'Injection',
      'cream': 'Cream',
      'ointment': 'Ointment',
      'drops': 'Drops',
      'inhaler': 'Inhaler',
      'suppository': 'Suppository',
      'suspension': 'Suspension',
      'powder': 'Powder',
      'gel': 'Gel',
      'patch': 'Patch',
      'lozenge': 'Lozenge',
      'spray': 'Spray',
      'solution': 'Solution',
    };
    return map[form] ?? form;
  }
}
