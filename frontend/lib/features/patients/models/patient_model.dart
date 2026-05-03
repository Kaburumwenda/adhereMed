class Patient {
  final int id;
  final int? userId;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? gender;
  final String? dateOfBirth;
  final String? idNumber;
  final String? bloodGroup;
  final String? address;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? allergies;
  final String? chronicConditions;
  final String? insuranceProvider;
  final String? insurancePolicyNumber;
  final String? createdAt;

  Patient({
    required this.id,
    this.userId,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.idNumber,
    this.bloodGroup,
    this.address,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.allergies,
    this.chronicConditions,
    this.insuranceProvider,
    this.insurancePolicyNumber,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Patient.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return Patient(
      id: json['id'],
      userId: user?['id'] ?? json['user_id'],
      firstName: user?['first_name'] ?? json['first_name'] ?? '',
      lastName: user?['last_name'] ?? json['last_name'] ?? '',
      email: user?['email'] ?? json['email'],
      phone: user?['phone'] ?? json['phone'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'],
      idNumber: json['national_id'] ?? json['id_number'],
      bloodGroup: json['blood_type'] ?? json['blood_group'],
      address: json['address'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      allergies: (json['allergies'] is List)
          ? (json['allergies'] as List).join(', ')
          : json['allergies'],
      chronicConditions: (json['chronic_conditions'] is List)
          ? (json['chronic_conditions'] as List).join(', ')
          : json['chronic_conditions'],
      insuranceProvider: json['insurance_provider'],
      insurancePolicyNumber: json['insurance_number'] ?? json['insurance_policy_number'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'national_id': idNumber,
        'blood_type': bloodGroup,
        'address': address,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
        'allergies': allergies,
        'chronic_conditions': chronicConditions,
        'insurance_provider': insuranceProvider,
        'insurance_number': insurancePolicyNumber,
        'email': email,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
      };
}
