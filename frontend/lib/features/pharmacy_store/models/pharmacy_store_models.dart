double _toDouble(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class PharmacyInfo {
  final int id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final double deliveryRadiusKm;
  final double deliveryFee;
  final bool acceptsInsurance;
  final String description;
  final int productCount;
  final List<String> services;

  PharmacyInfo({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.phone = '',
    this.email = '',
    this.deliveryRadiusKm = 0,
    this.deliveryFee = 0,
    this.acceptsInsurance = false,
    this.description = '',
    this.productCount = 0,
    this.services = const [],
  });

  factory PharmacyInfo.fromJson(Map<String, dynamic> json) => PharmacyInfo(
        id: json['id'],
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        city: json['city'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
        deliveryRadiusKm: _toDouble(json['delivery_radius_km']),
        deliveryFee: _toDouble(json['delivery_fee']),
        acceptsInsurance: json['accepts_insurance'] ?? false,
        description: json['description'] ?? '',
        productCount: json['product_count'] ?? 0,
        services: (json['services'] as List?)?.cast<String>() ?? [],
      );
}

class PharmacyProduct {
  final int id;
  final String medicationId;
  final String medicationName;
  final double sellingPrice;
  final String categoryName;
  final String unitName;
  final int availableQty;
  final bool inStock;

  PharmacyProduct({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.sellingPrice,
    this.categoryName = '',
    this.unitName = '',
    this.availableQty = 0,
    this.inStock = false,
  });

  factory PharmacyProduct.fromJson(Map<String, dynamic> json) =>
      PharmacyProduct(
        id: json['id'],
        medicationId: json['medication_id'] ?? '',
        medicationName: json['medication_name'] ?? '',
        sellingPrice: _toDouble(json['selling_price']),
        categoryName: json['category_name'] ?? '',
        unitName: json['unit_name'] ?? '',
        availableQty: json['available_qty'] ?? 0,
        inStock: json['in_stock'] ?? false,
      );
}

class ProductCategory {
  final String id;
  final String name;

  ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(id: json['id'].toString(), name: json['name'] ?? '');
}

class CartItem {
  final PharmacyProduct product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get total => product.sellingPrice * quantity;
}

class PatientOrder {
  final int id;
  final String orderNumber;
  final String patientName;
  final String patientPhone;
  final int pharmacyTenantId;
  final String pharmacyName;
  final List<dynamic> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryAddress;
  final String paymentMethod;
  final String status;
  final String notes;
  final DateTime? createdAt;

  PatientOrder({
    required this.id,
    required this.orderNumber,
    this.patientName = '',
    this.patientPhone = '',
    required this.pharmacyTenantId,
    required this.pharmacyName,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0,
    required this.total,
    this.deliveryAddress = '',
    this.paymentMethod = 'cash',
    required this.status,
    this.notes = '',
    this.createdAt,
  });

  factory PatientOrder.fromJson(Map<String, dynamic> json) => PatientOrder(
        id: json['id'],
        orderNumber: json['order_number'] ?? '',
        patientName: json['patient_name'] ?? '',
        patientPhone: json['patient_phone'] ?? '',
        pharmacyTenantId: json['pharmacy_tenant_id'],
        pharmacyName: json['pharmacy_name'] ?? '',
        items: json['items'] as List? ?? [],
        subtotal: _toDouble(json['subtotal']),
        deliveryFee: _toDouble(json['delivery_fee']),
        total: _toDouble(json['total']),
        deliveryAddress: json['delivery_address'] ?? '',
        paymentMethod: json['payment_method'] ?? 'cash',
        status: json['status'] ?? 'pending',
        notes: json['notes'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );
}
