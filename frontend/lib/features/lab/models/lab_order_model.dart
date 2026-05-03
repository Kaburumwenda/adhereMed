class LabTestCatalog {
  final int id;
  final String name;
  final String code;
  final String? department;
  final String specimenType;
  final Map<String, dynamic>? referenceRanges;
  final double price;
  final String? turnaroundTime;
  final String? instructions;
  final bool isActive;

  LabTestCatalog({
    required this.id,
    required this.name,
    required this.code,
    this.department,
    required this.specimenType,
    this.referenceRanges,
    required this.price,
    this.turnaroundTime,
    this.instructions,
    required this.isActive,
  });

  factory LabTestCatalog.fromJson(Map<String, dynamic> json) {
    return LabTestCatalog(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      department: json['department'],
      specimenType: json['specimen_type'] ?? '',
      referenceRanges: json['reference_ranges'] is Map
          ? Map<String, dynamic>.from(json['reference_ranges'])
          : null,
      price: double.tryParse('${json['price']}') ?? 0,
      turnaroundTime: json['turnaround_time'],
      instructions: json['instructions'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'department': department,
        'specimen_type': specimenType,
        'reference_ranges': referenceRanges ?? {},
        'price': price,
        'turnaround_time': turnaroundTime,
        'instructions': instructions,
        'is_active': isActive,
      };
}

class LabOrder {
  final int id;
  final int? consultationId;
  final int? patientId;
  final String? patientName;
  final int? orderedById;
  final String? orderedByName;
  final List<int>? testIds;
  final List<String>? testNames;
  final String status;
  final String priority;
  final String? clinicalNotes;
  final bool isHomeCollection;
  final List<LabResult>? results;
  final String? createdAt;
  final String? updatedAt;

  LabOrder({
    required this.id,
    this.consultationId,
    this.patientId,
    this.patientName,
    this.orderedById,
    this.orderedByName,
    this.testIds,
    this.testNames,
    required this.status,
    required this.priority,
    this.clinicalNotes,
    this.isHomeCollection = false,
    this.results,
    this.createdAt,
    this.updatedAt,
  });

  factory LabOrder.fromJson(Map<String, dynamic> json) {
    return LabOrder(
      id: json['id'],
      consultationId: json['consultation'],
      patientId: json['patient'] is Map ? json['patient']['id'] : json['patient'],
      patientName: json['patient_name'],
      orderedById: json['ordered_by'] is Map ? json['ordered_by']['id'] : json['ordered_by'],
      orderedByName: json['ordered_by_name'],
      testIds: json['tests'] != null
          ? (json['tests'] as List).map((e) => e is Map ? e['id'] as int : e as int).toList()
          : null,
      testNames: json['test_names'] != null
          ? (json['test_names'] as List).cast<String>()
          : null,
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'routine',
      clinicalNotes: json['clinical_notes'],
      isHomeCollection: json['is_home_collection'] ?? false,
      results: json['results'] != null
          ? (json['results'] as List).map((r) => LabResult.fromJson(r)).toList()
          : null,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'consultation': consultationId,
        'patient': patientId,
        'ordered_by': orderedById,
        'test_ids': testIds,
        'status': status,
        'priority': priority,
        'clinical_notes': clinicalNotes,
        'is_home_collection': isHomeCollection,
      };
}

class LabResult {
  final int id;
  final int orderId;
  final int? testId;
  final String? testName;
  final String resultValue;
  final String? unit;
  final bool isAbnormal;
  final String? comments;
  final int? performedById;
  final String? performedByName;
  final int? verifiedById;
  final String? verifiedByName;
  final String? resultDate;

  LabResult({
    required this.id,
    required this.orderId,
    this.testId,
    this.testName,
    required this.resultValue,
    this.unit,
    this.isAbnormal = false,
    this.comments,
    this.performedById,
    this.performedByName,
    this.verifiedById,
    this.verifiedByName,
    this.resultDate,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      id: json['id'],
      orderId: json['order'] is Map ? json['order']['id'] : json['order'] ?? 0,
      testId: json['test'] is Map ? json['test']['id'] : json['test'],
      testName: json['test_name'],
      resultValue: '${json['result_value'] ?? ''}',
      unit: json['unit'],
      isAbnormal: json['is_abnormal'] ?? false,
      comments: json['comments'],
      performedById: json['performed_by'] is Map ? json['performed_by']['id'] : json['performed_by'],
      performedByName: json['performed_by_name'],
      verifiedById: json['verified_by'] is Map ? json['verified_by']['id'] : json['verified_by'],
      verifiedByName: json['verified_by_name'],
      resultDate: json['result_date'],
    );
  }

  Map<String, dynamic> toJson() => {
        'order': orderId,
        'test': testId,
        'result_value': resultValue,
        'unit': unit,
        'is_abnormal': isAbnormal,
        'comments': comments,
        'performed_by': performedById,
        'verified_by': verifiedById,
      };
}
