double _toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class PrescriptionExchange {
  final int id;
  final int? hospitalTenantId;
  final int? patientUserId;
  final String prescriptionRef;
  final List<dynamic> items;
  final String status;
  final int? selectedPharmacyTenantId;
  final String? createdAt;
  final String? expiresAt;
  final List<PharmacyQuote> quotes;
  final PharmacyQuote? lowestQuote;

  PrescriptionExchange({
    required this.id,
    this.hospitalTenantId,
    this.patientUserId,
    required this.prescriptionRef,
    required this.items,
    required this.status,
    this.selectedPharmacyTenantId,
    this.createdAt,
    this.expiresAt,
    this.quotes = const [],
    this.lowestQuote,
  });

  factory PrescriptionExchange.fromJson(Map<String, dynamic> json) =>
      PrescriptionExchange(
        id: json['id'],
        hospitalTenantId: json['hospital_tenant_id'],
        patientUserId: json['patient_user_id'],
        prescriptionRef: json['prescription_ref'] ?? '',
        items: json['items'] as List? ?? [],
        status: json['status'] ?? 'pending',
        selectedPharmacyTenantId: json['selected_pharmacy_tenant_id'],
        createdAt: json['created_at'],
        expiresAt: json['expires_at'],
        quotes: (json['quotes'] as List? ?? [])
            .map((e) => PharmacyQuote.fromJson(e))
            .toList(),
        lowestQuote: json['lowest_quote'] != null
            ? PharmacyQuote.fromJson(json['lowest_quote'])
            : null,
      );
}

class PharmacyQuote {
  final int id;
  final int exchangeId;
  final int pharmacyTenantId;
  final String pharmacyName;
  final List<dynamic> itemsPricing;
  final double subtotal;
  final bool deliveryAvailable;
  final double deliveryFee;
  final double totalCost;
  final String? validUntil;
  final String status;

  PharmacyQuote({
    required this.id,
    required this.exchangeId,
    required this.pharmacyTenantId,
    required this.pharmacyName,
    required this.itemsPricing,
    required this.subtotal,
    this.deliveryAvailable = false,
    this.deliveryFee = 0,
    required this.totalCost,
    this.validUntil,
    required this.status,
  });

  factory PharmacyQuote.fromJson(Map<String, dynamic> json) => PharmacyQuote(
        id: json['id'],
        exchangeId: json['exchange'] ?? 0,
        pharmacyTenantId: json['pharmacy_tenant_id'] ?? 0,
        pharmacyName: json['pharmacy_name'] ?? '',
        itemsPricing: json['items_pricing'] as List? ?? [],
        subtotal: _toDouble(json['subtotal']),
        deliveryAvailable: json['delivery_available'] ?? false,
        deliveryFee: _toDouble(json['delivery_fee']),
        totalCost: _toDouble(json['total_cost']),
        validUntil: json['valid_until'],
        status: json['status'] ?? 'pending',
      );
}
