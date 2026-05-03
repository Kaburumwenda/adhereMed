class Ward {
  final int id;
  final String name;
  final String type;
  final String? floor;
  final int capacity;
  final double dailyRate;
  final bool isActive;
  final int? availableBeds;
  final List<Bed>? beds;

  Ward({
    required this.id,
    required this.name,
    required this.type,
    this.floor,
    required this.capacity,
    required this.dailyRate,
    required this.isActive,
    this.availableBeds,
    this.beds,
  });

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: json['id'],
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      floor: json['floor'],
      capacity: json['capacity'] ?? 0,
      dailyRate: double.tryParse('${json['daily_rate']}') ?? 0,
      isActive: json['is_active'] ?? true,
      availableBeds: json['available_beds'],
      beds: json['beds'] != null
          ? (json['beds'] as List).map((b) => Bed.fromJson(b)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'floor': floor,
        'capacity': capacity,
        'daily_rate': dailyRate,
        'is_active': isActive,
      };
}

class Bed {
  final int id;
  final int wardId;
  final String? wardName;
  final String bedNumber;
  final String status;

  Bed({
    required this.id,
    required this.wardId,
    this.wardName,
    required this.bedNumber,
    required this.status,
  });

  factory Bed.fromJson(Map<String, dynamic> json) {
    return Bed(
      id: json['id'],
      wardId: json['ward'] is Map ? json['ward']['id'] : json['ward'] ?? 0,
      wardName: json['ward_name'],
      bedNumber: json['bed_number'] ?? '',
      status: json['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toJson() => {
        'ward': wardId,
        'bed_number': bedNumber,
        'status': status,
      };
}

class Admission {
  final int id;
  final int? patientId;
  final String? patientName;
  final int? bedId;
  final String? bedLabel;
  final int? admittingDoctorId;
  final String? admittingDoctorName;
  final String admissionDate;
  final String? dischargeDate;
  final String reason;
  final String? dischargeSummary;
  final String status;
  final String? createdAt;

  Admission({
    required this.id,
    this.patientId,
    this.patientName,
    this.bedId,
    this.bedLabel,
    this.admittingDoctorId,
    this.admittingDoctorName,
    required this.admissionDate,
    this.dischargeDate,
    required this.reason,
    this.dischargeSummary,
    required this.status,
    this.createdAt,
  });

  factory Admission.fromJson(Map<String, dynamic> json) {
    return Admission(
      id: json['id'],
      patientId: json['patient'] is Map ? json['patient']['id'] : json['patient'],
      patientName: json['patient_name'],
      bedId: json['bed'] is Map ? json['bed']['id'] : json['bed'],
      bedLabel: json['bed_label'],
      admittingDoctorId: json['admitting_doctor'] is Map
          ? json['admitting_doctor']['id']
          : json['admitting_doctor'],
      admittingDoctorName: json['admitting_doctor_name'],
      admissionDate: json['admission_date'] ?? '',
      dischargeDate: json['discharge_date'],
      reason: json['reason'] ?? '',
      dischargeSummary: json['discharge_summary'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'bed': bedId,
        'admitting_doctor': admittingDoctorId,
        'admission_date': admissionDate,
        'discharge_date': dischargeDate,
        'reason': reason,
        'discharge_summary': dischargeSummary,
        'status': status,
      };
}
