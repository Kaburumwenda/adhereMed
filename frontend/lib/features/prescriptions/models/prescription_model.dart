class Prescription {
  final int id;
  final int? consultationId;
  final int? patientId;
  final String? patientName;
  final int? doctorId;
  final String? doctorName;
  final String status;
  final String? notes;
  final String? createdAt;
  final List<PrescriptionItem> items;

  Prescription({
    required this.id,
    this.consultationId,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
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
      doctorId: doctor is Map ? doctor['id'] : json['doctor'],
      doctorName: json['doctor_name'] as String? ??
          (doctor is Map
              ? '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'
                  .trim()
              : null),
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
      };
}
