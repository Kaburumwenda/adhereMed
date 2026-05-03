class Consultation {
  final int id;
  final int? appointmentId;
  final int? patientId;
  final String? patientName;
  final int? doctorId;
  final String? doctorName;
  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? examination;
  final String? diagnosis;
  final String? treatmentPlan;
  final String? notes;
  final String status;
  final String? createdAt;
  final List<dynamic>? prescriptions;
  final List<dynamic>? labOrders;
  final List<dynamic>? radiologyOrders;

  Consultation({
    required this.id,
    this.appointmentId,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.examination,
    this.diagnosis,
    this.treatmentPlan,
    this.notes,
    required this.status,
    this.createdAt,
    this.prescriptions,
    this.labOrders,
    this.radiologyOrders,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final doctor = json['doctor'];
    return Consultation(
      id: json['id'],
      appointmentId: json['appointment'] is Map
          ? json['appointment']['id']
          : json['appointment'],
      patientId: patient is Map ? patient['id'] : json['patient'],
      patientName: patient is Map
          ? '${patient['user']?['first_name'] ?? ''} ${patient['user']?['last_name'] ?? ''}'
              .trim()
          : null,
      doctorId: doctor is Map ? doctor['id'] : json['doctor'],
      doctorName: doctor is Map
          ? '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'.trim()
          : null,
      chiefComplaint: json['chief_complaint'],
      historyOfPresentIllness: json['history_of_present_illness'],
      examination: json['examination'],
      diagnosis: json['diagnosis'],
      treatmentPlan: json['treatment_plan'],
      notes: json['notes'],
      status: json['status'] ?? 'in_progress',
      createdAt: json['created_at'],
      prescriptions: json['prescriptions'] as List?,
      labOrders: json['lab_orders'] as List?,
      radiologyOrders: json['radiology_orders'] as List?,
    );
  }

  Map<String, dynamic> toJson() => {
        'appointment': appointmentId,
        'patient': patientId,
        'doctor': doctorId,
        'chief_complaint': chiefComplaint,
        'history_of_present_illness': historyOfPresentIllness,
        'examination': examination,
        'diagnosis': diagnosis,
        'treatment_plan': treatmentPlan,
        'notes': notes,
        'status': status,
      };
}
