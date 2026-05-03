class Appointment {
  final int id;
  final int? patientId;
  final String? patientName;
  final int? doctorId;
  final String? doctorName;
  final int? departmentId;
  final String? departmentName;
  final String date;
  final String startTime;
  final String? endTime;
  final String status;
  final String? appointmentType;
  final String? reason;
  final String? notes;
  final String? createdAt;

  Appointment({
    required this.id,
    this.patientId,
    this.patientName,
    this.doctorId,
    this.doctorName,
    this.departmentId,
    this.departmentName,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.status,
    this.appointmentType,
    this.reason,
    this.notes,
    this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    final doctor = json['doctor'];
    final dept = json['department'];
    return Appointment(
      id: json['id'],
      patientId: patient is Map ? patient['id'] : json['patient'],
      patientName: patient is Map
          ? '${patient['user']?['first_name'] ?? ''} ${patient['user']?['last_name'] ?? ''}'
              .trim()
          : null,
      doctorId: doctor is Map ? doctor['id'] : json['doctor'],
      doctorName: doctor is Map
          ? '${doctor['first_name'] ?? ''} ${doctor['last_name'] ?? ''}'.trim()
          : null,
      departmentId: dept is Map ? dept['id'] : json['department'],
      departmentName: dept is Map ? dept['name'] : null,
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'],
      status: json['status'] ?? 'scheduled',
      appointmentType: json['appointment_type'],
      reason: json['reason'],
      notes: json['notes'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'doctor': doctorId,
        'department': departmentId,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'status': status,
        'appointment_type': appointmentType,
        'reason': reason,
        'notes': notes,
      };
}
