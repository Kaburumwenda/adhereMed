class Supplier {
  final int id;
  final String name;
  final String? contactPerson;
  final String? email;
  final String? phone;
  final String? address;
  final bool isActive;
  final String? createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    this.phone,
    this.address,
    this.isActive = true,
    this.createdAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'],
        name: json['name'] ?? '',
        contactPerson: json['contact_person'],
        email: json['email'],
        phone: json['phone'],
        address: json['address'],
        isActive: json['is_active'] ?? true,
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact_person': contactPerson,
        'email': email,
        'phone': phone,
        'address': address,
        'is_active': isActive,
      };
}
