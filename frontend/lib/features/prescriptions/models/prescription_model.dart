class Prescription {
  final int id;
  final int? consultationId;
  final int? patientId;
  final String? patientName;
  final String? patientPhone;
  final String? patientEmail;
  final String? patientNationalId;
  final List<String> patientAllergies;
  final List<String> patientChronicConditions;
  final String? patientInsuranceProvider;
  final String? patientInsuranceNumber;
  final int? doctorId;
  final String? doctorName;
  final String? doctorLicenseNumber;
  final String? doctorPracticeType;
  final String? doctorSignatureUrl;
  final String status;
  final String? notes;
  final String? createdAt;
  final List<PrescriptionItem> items;

  Prescription({
    required this.id,
    this.consultationId,
    this.patientId,
    this.patientName,
    this.patientPhone,
    this.patientEmail,
    this.patientNationalId,
    this.patientAllergies = const [],
    this.patientChronicConditions = const [],
    this.patientInsuranceProvider,
    this.patientInsuranceNumber,
    this.doctorId,
    this.doctorName,
    this.doctorLicenseNumber,
    this.doctorPracticeType,
    this.doctorSignatureUrl,
    required this.status,
    this.notes,
    this.createdAt,
    this.items = const [],
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final doctor = json['doctor'];
    return Prescription(
      id: json['id'],
      consultationId: json['consultation'] is Map
          ? json['consultation']['id']
          : json['consultation'],
      patientId: patient is Map ? patient['id'] : json['patient'],
      patientName: json['patient_name'] as String? ??
          (patient is Map
              ? '${patient['user']?['first_name'] ?? ''} ${patient['user']?['last_name'] ?? ''}'
                  .trim()
              : null),
      patientPhone: json['patient_phone'] as String?,
      patientEmail: json['patient_email'] as String?,
      patientNationalId: json['patient_national_id'] as String?,
      patientAllergies:
          List<String>.from(json['patient_allergies'] as List? ?? []),
      patientChronicConditions:
          List<String>.from(json['patient_chronic_conditions'] as List? ?? []),
      patientInsuranceProvider: json['patient_insurance_provider'] as String?,
      patientInsuranceNumber: json['patient_insurance_number'] as String?,
      doctorId: doctor is Map ? doctor['id'] : json['doctor'],
      doctorName: json['doctor_name'] as String? ??
          (doctor is Map
              ? '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'
                  .trim()
              : null),
      doctorLicenseNumber: json['doctor_license_number'] as String?,
      doctorPracticeType: json['doctor_practice_type'] as String?,
      doctorSignatureUrl: json['doctor_signature_url'] as String?,
      status: json['status'] ?? 'active',
      notes: json['notes'],
      createdAt: json['created_at'],
      items: (json['items'] as List? ?? [])
          .map((e) => PrescriptionItem.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'consultation': consultationId,
        'patient': patientId,
        'doctor': doctorId,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PrescriptionItem {
  final int? id;
  final int? medicationId;
  final String medicationName;
  final String? customMedicationName;
  final bool isCustom;
  final String dosage;
  final String frequency;
  final String duration;
  final int quantity;
  final String? instructions;
  final String? schedule;
  final int refills;

  PrescriptionItem({
    this.id,
    this.medicationId,
    required this.medicationName,
    this.customMedicationName,
    this.isCustom = false,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.quantity = 1,
    this.instructions,
    this.schedule,
    this.refills = 0,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) =>
      PrescriptionItem(
        id: json['id'],
        medicationId: json['medication_id'],
        medicationName: json['medication_name'] ?? '',
        customMedicationName: json['custom_medication_name'],
        isCustom: json['is_custom'] ?? false,
        dosage: json['dosage'] ?? '',
        frequency: json['frequency'] ?? '',
        duration: json['duration'] ?? '',
        quantity: json['quantity'] ?? 1,
        instructions: json['instructions'],
        schedule: json['schedule'] as String?,
        refills: json['refills'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'medication_id': medicationId,
        'medication_name': medicationName,
        'custom_medication_name': customMedicationName,
        'is_custom': isCustom,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
        'quantity': quantity,
        'instructions': instructions,
        'schedule': schedule,
        'refills': refills,
      };
}
