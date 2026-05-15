class User {
  final int id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String role;
  final int? tenantId;
  final String? tenantName;
  final String? tenantType;
  final String? tenantSchema;
  final bool isActive;
  final String? pin;

  User({
    required this.id,
    required this.email,
    this.phone = '',
    required this.firstName,
    required this.lastName,
    required this.role,
    this.tenantId,
    this.tenantName,
    this.tenantType,
    this.tenantSchema,
    this.isActive = true,
    this.pin,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] ?? 0,
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        role: j['role'] ?? 'patient',
        tenantId: j['tenant'],
        tenantName: j['tenant_name'],
        tenantType: j['tenant_type'],
        tenantSchema: j['tenant_schema'],
        isActive: j['is_active'] ?? true,
        pin: j['pin'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'tenant': tenantId,
        'tenant_name': tenantName,
        'tenant_type': tenantType,
        'tenant_schema': tenantSchema,
        'is_active': isActive,
        'pin': pin,
      };
}
