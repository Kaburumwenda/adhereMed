class TriageRecord {
  final int id;
  final int? patientId;
  final String? patientName;
  final double? temperature;
  final int? systolicBp;
  final int? diastolicBp;
  final int? pulseRate;
  final int? respiratoryRate;
  final double? oxygenSaturation;
  final double? weight;
  final double? height;
  final int? painLevel;
  final String? triageCategory;
  final String? notes;
  final String? createdAt;

  TriageRecord({
    required this.id,
    this.patientId,
    this.patientName,
    this.temperature,
    this.systolicBp,
    this.diastolicBp,
    this.pulseRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
    this.painLevel,
    this.triageCategory,
    this.notes,
    this.createdAt,
  });

  factory TriageRecord.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    return TriageRecord(
      id: json['id'],
      patientId: patient is Map ? patient['id'] : json['patient'],
      patientName: patient is Map
          ? '${patient['user']?['first_name'] ?? ''} ${patient['user']?['last_name'] ?? ''}'
              .trim()
          : null,
      temperature: (json['temperature'] as num?)?.toDouble(),
      systolicBp: json['systolic_bp'],
      diastolicBp: json['diastolic_bp'],
      pulseRate: json['pulse_rate'],
      respiratoryRate: json['respiratory_rate'],
      oxygenSaturation: (json['oxygen_saturation'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      height: (json['height'] as num?)?.toDouble(),
      painLevel: json['pain_level'],
      triageCategory: json['triage_category'],
      notes: json['notes'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'temperature': temperature,
        'systolic_bp': systolicBp,
        'diastolic_bp': diastolicBp,
        'pulse_rate': pulseRate,
        'respiratory_rate': respiratoryRate,
        'oxygen_saturation': oxygenSaturation,
        'weight': weight,
        'height': height,
        'pain_level': painLevel,
        'triage_category': triageCategory,
        'notes': notes,
      };
}
