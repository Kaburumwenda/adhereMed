class LabOrderExchange {
  final int id;
  final int? sourceTenantId;
  final String? sourceTenantName;
  final String? orderingDoctorName;
  final int? orderingDoctorUserId;
  final int? patientUserId;
  final String patientName;
  final String? patientPhone;
  final List<Map<String, dynamic>> tests;
  final String priority;
  final String? clinicalNotes;
  final bool isHomeCollection;
  final String? collectionAddress;
  final int? labTenantId;
  final String? labTenantName;
  final List<Map<String, dynamic>>? results;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  LabOrderExchange({
    required this.id,
    this.sourceTenantId,
    this.sourceTenantName,
    this.orderingDoctorName,
    this.orderingDoctorUserId,
    this.patientUserId,
    required this.patientName,
    this.patientPhone,
    required this.tests,
    required this.priority,
    this.clinicalNotes,
    this.isHomeCollection = false,
    this.collectionAddress,
    this.labTenantId,
    this.labTenantName,
    this.results,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory LabOrderExchange.fromJson(Map<String, dynamic> json) {
    return LabOrderExchange(
      id: json['id'],
      sourceTenantId: json['source_tenant_id'],
      sourceTenantName: json['source_tenant_name'],
      orderingDoctorName: json['ordering_doctor_name'],
      orderingDoctorUserId: json['ordering_doctor_user_id'],
      patientUserId: json['patient_user_id'],
      patientName: json['patient_name'] ?? '',
      patientPhone: json['patient_phone'],
      tests: (json['tests'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      priority: json['priority'] ?? 'routine',
      clinicalNotes: json['clinical_notes'],
      isHomeCollection: json['is_home_collection'] ?? false,
      collectionAddress: json['collection_address'],
      labTenantId: json['lab_tenant_id'],
      labTenantName: json['lab_tenant_name'],
      results: (json['results'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'source_tenant_id': sourceTenantId,
        'source_tenant_name': sourceTenantName,
        'ordering_doctor_name': orderingDoctorName,
        'ordering_doctor_user_id': orderingDoctorUserId,
        'patient_user_id': patientUserId,
        'patient_name': patientName,
        'patient_phone': patientPhone,
        'tests': tests,
        'priority': priority,
        'clinical_notes': clinicalNotes,
        'is_home_collection': isHomeCollection,
        'collection_address': collectionAddress,
        'status': status,
      };

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'sample_collected':
        return 'Sample Collected';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'routine':
        return 'Routine';
      case 'urgent':
        return 'Urgent';
      case 'stat':
        return 'STAT';
      default:
        return priority;
    }
  }
}
