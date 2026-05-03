// Models for super admin views

class TenantAdminModel {
  final int id;
  final String name;
  final String type;
  final String slug;
  final String schemaName;
  final String address;
  final String city;
  final String country;
  final String phone;
  final String email;
  final String website;
  final bool isActive;
  final String createdAt;
  final int userCount;
  final List<Map<String, dynamic>> domains;

  const TenantAdminModel({
    required this.id,
    required this.name,
    required this.type,
    required this.slug,
    required this.schemaName,
    this.address = '',
    this.city = '',
    this.country = 'Kenya',
    this.phone = '',
    this.email = '',
    this.website = '',
    required this.isActive,
    required this.createdAt,
    this.userCount = 0,
    this.domains = const [],
  });

  factory TenantAdminModel.fromJson(Map<String, dynamic> j) =>
      TenantAdminModel(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        schemaName: j['schema_name'] as String? ?? '',
        address: j['address'] as String? ?? '',
        city: j['city'] as String? ?? '',
        country: j['country'] as String? ?? 'Kenya',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        website: j['website'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
        createdAt: j['created_at'] as String? ?? '',
        userCount: j['user_count'] is int ? j['user_count'] as int : 0,
        domains: (j['domains'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );

  String get primaryDomain {
    final primary = domains.where((d) => d['is_primary'] == true).firstOrNull;
    return primary?['domain'] as String? ??
        (domains.isNotEmpty ? domains.first['domain'] as String? ?? '' : '');
  }

  String get typeLabel {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'pharmacy':
        return 'Pharmacy';
      case 'lab':
        return 'Laboratory';
      default:
        return type;
    }
  }
}

class AdminUserModel {
  final int id;
  final String email;
  final String phone;
  final String firstName;
  final String lastName;
  final String role;
  final int? tenant;
  final String? tenantName;
  final String? tenantType;
  final bool isActive;
  final bool isStaff;
  final String? dateJoined;

  const AdminUserModel({
    required this.id,
    required this.email,
    this.phone = '',
    this.firstName = '',
    this.lastName = '',
    required this.role,
    this.tenant,
    this.tenantName,
    this.tenantType,
    required this.isActive,
    this.isStaff = false,
    this.dateJoined,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> j) => AdminUserModel(
        id: j['id'] as int,
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        role: j['role'] as String? ?? '',
        tenant: j['tenant'] as int?,
        tenantName: j['tenant_name'] as String?,
        tenantType: j['tenant_type'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        isStaff: j['is_staff'] as bool? ?? false,
        dateJoined: j['date_joined'] as String?,
      );

  String get fullName => '$firstName $lastName'.trim();

  String get roleLabel {
    final labels = {
      'super_admin': 'Super Admin',
      'tenant_admin': 'Tenant Admin',
      'doctor': 'Doctor',
      'clinical_officer': 'Clinical Officer',
      'nurse': 'Nurse',
      'midwife': 'Midwife',
      'lab_tech': 'Lab Technologist',
      'pharmacist': 'Pharmacist',
      'pharmacy_tech': 'Pharmacy Tech',
      'cashier': 'Cashier',
      'receptionist': 'Receptionist',
      'radiologist': 'Radiologist',
      'patient': 'Patient',
    };
    return labels[role] ?? role;
  }
}

class PlatformStats {
  final int totalTenants;
  final int activeTenants;
  final int inactiveTenants;
  final int newTenants30d;
  final List<Map<String, dynamic>> tenantsByType;
  final int totalUsers;
  final int activeUsers;
  final int inactiveUsers;
  final int newUsers30d;
  final List<Map<String, dynamic>> usersByRole;

  const PlatformStats({
    required this.totalTenants,
    required this.activeTenants,
    required this.inactiveTenants,
    required this.newTenants30d,
    required this.tenantsByType,
    required this.totalUsers,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.newUsers30d,
    required this.usersByRole,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> j) {
    final t = j['tenants'] as Map<String, dynamic>? ?? {};
    final u = j['users'] as Map<String, dynamic>? ?? {};
    return PlatformStats(
      totalTenants: t['total'] as int? ?? 0,
      activeTenants: t['active'] as int? ?? 0,
      inactiveTenants: t['inactive'] as int? ?? 0,
      newTenants30d: t['new_last_30_days'] as int? ?? 0,
      tenantsByType: (t['by_type'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      totalUsers: u['total'] as int? ?? 0,
      activeUsers: u['active'] as int? ?? 0,
      inactiveUsers: u['inactive'] as int? ?? 0,
      newUsers30d: u['new_last_30_days'] as int? ?? 0,
      usersByRole: (u['by_role'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}
