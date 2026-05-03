class RadiologyOrder {
  final int id;
  final int? consultationId;
  final int? patientId;
  final String? patientName;
  final int? orderedById;
  final String? orderedByName;
  final String imagingType;
  final String bodyPart;
  final String? clinicalIndication;
  final String status;
  final String priority;
  final RadiologyResult? result;
  final String? createdAt;

  RadiologyOrder({
    required this.id,
    this.consultationId,
    this.patientId,
    this.patientName,
    this.orderedById,
    this.orderedByName,
    required this.imagingType,
    required this.bodyPart,
    this.clinicalIndication,
    required this.status,
    required this.priority,
    this.result,
    this.createdAt,
  });

  factory RadiologyOrder.fromJson(Map<String, dynamic> json) {
    return RadiologyOrder(
      id: json['id'],
      consultationId: json['consultation'],
      patientId: json['patient'] is Map ? json['patient']['id'] : json['patient'],
      patientName: json['patient_name'],
      orderedById: json['ordered_by'] is Map ? json['ordered_by']['id'] : json['ordered_by'],
      orderedByName: json['ordered_by_name'],
      imagingType: json['imaging_type'] ?? '',
      bodyPart: json['body_part'] ?? '',
      clinicalIndication: json['clinical_indication'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'routine',
      result: json['result'] != null ? RadiologyResult.fromJson(json['result']) : null,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'consultation': consultationId,
        'patient': patientId,
        'ordered_by': orderedById,
        'imaging_type': imagingType,
        'body_part': bodyPart,
        'clinical_indication': clinicalIndication,
        'status': status,
        'priority': priority,
      };
}

class RadiologyResult {
  final int id;
  final int orderId;
  final String findings;
  final String? impression;
  final int? radiologistId;
  final String? radiologistName;
  final String? imageUrl;
  final String? resultDate;

  RadiologyResult({
    required this.id,
    required this.orderId,
    required this.findings,
    this.impression,
    this.radiologistId,
    this.radiologistName,
    this.imageUrl,
    this.resultDate,
  });

  factory RadiologyResult.fromJson(Map<String, dynamic> json) {
    return RadiologyResult(
      id: json['id'],
      orderId: json['order'] is Map ? json['order']['id'] : json['order'] ?? 0,
      findings: json['findings'] ?? '',
      impression: json['impression'],
      radiologistId: json['radiologist'] is Map
          ? json['radiologist']['id']
          : json['radiologist'],
      radiologistName: json['radiologist_name'],
      imageUrl: json['image_url'],
      resultDate: json['result_date'],
    );
  }

  Map<String, dynamic> toJson() => {
        'order': orderId,
        'findings': findings,
        'impression': impression,
        'radiologist': radiologistId,
        'image_url': imageUrl,
      };
}
