class DoctorProfile {
  final int id;
  final int userId;
  final String name;
  final String email;
  final String phone;
  final String practiceType;
  final int? hospitalId;
  final String? hospitalName;
  final String specialization;
  final String licenseNumber;
  final String qualification;
  final int yearsOfExperience;
  final String bio;
  final double consultationFee;
  final bool isAcceptingPatients;
  final bool isVerified;
  final List<String> languages;
  final List<String> availableDays;
  final Map<String, dynamic> availableHours;
  final String? profilePictureUrl;
  final String? signatureUrl;

  DoctorProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone = '',
    required this.practiceType,
    this.hospitalId,
    this.hospitalName,
    required this.specialization,
    this.licenseNumber = '',
    this.qualification = '',
    this.yearsOfExperience = 0,
    this.bio = '',
    this.consultationFee = 0,
    this.isAcceptingPatients = true,
    this.isVerified = false,
    this.languages = const [],
    this.availableDays = const [],
    this.availableHours = const {},
    this.profilePictureUrl,
    this.signatureUrl,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'],
      userId: json['user'] ?? 0,
      name: json['name'] ?? json['user_name'] ?? '',
      email: json['email'] ?? json['user_email'] ?? '',
      phone: json['phone'] ?? json['user_phone'] ?? '',
      practiceType: json['practice_type'] ?? 'independent',
      hospitalId: json['hospital'],
      hospitalName: json['hospital_name'],
      specialization: json['specialization'] ?? '',
      licenseNumber: json['license_number'] ?? '',
      qualification: json['qualification'] ?? '',
      yearsOfExperience: json['years_of_experience'] ?? 0,
      bio: json['bio'] ?? '',
      consultationFee: double.tryParse('${json['consultation_fee']}') ?? 0,
      isAcceptingPatients: json['is_accepting_patients'] ?? true,
      isVerified: json['is_verified'] ?? false,
      languages: List<String>.from(json['languages'] ?? []),
      availableDays: List<String>.from(json['available_days'] ?? []),
      availableHours: Map<String, dynamic>.from(json['available_hours'] ?? {}),
      profilePictureUrl: json['profile_picture_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
    );
  }
}
