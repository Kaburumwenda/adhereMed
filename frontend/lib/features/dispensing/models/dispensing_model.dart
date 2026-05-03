class DispensingRecord {
  final int id;
  final int? prescriptionExchangeId;
  final int? patientUserId;
  final String? patientName;
  final String status;
  final String? dispensedBy;
  final String? notes;
  final String? createdAt;
  final List<DispensingItem> items;

  DispensingRecord({
    required this.id,
    this.prescriptionExchangeId,
    this.patientUserId,
    this.patientName,
    required this.status,
    this.dispensedBy,
    this.notes,
    this.createdAt,
    this.items = const [],
  });

  factory DispensingRecord.fromJson(Map<String, dynamic> json) =>
      DispensingRecord(
        id: json['id'],
        prescriptionExchangeId: json['prescription_exchange'],
        patientUserId: json['patient_user_id'],
        patientName: json['patient_name'],
        status: json['status'] ?? 'pending',
        dispensedBy: json['dispensed_by'] is Map
            ? '${json['dispensed_by']['first_name']} ${json['dispensed_by']['last_name']}'
            : null,
        notes: json['notes'],
        createdAt: json['created_at'],
        items: (json['items'] as List? ?? [])
            .map((e) => DispensingItem.fromJson(e))
            .toList(),
      );
}

class DispensingItem {
  final int? id;
  final int? medicationStockId;
  final String? medicationName;
  final int quantity;
  final bool dispensed;

  DispensingItem({
    this.id,
    this.medicationStockId,
    this.medicationName,
    required this.quantity,
    this.dispensed = false,
  });

  factory DispensingItem.fromJson(Map<String, dynamic> json) => DispensingItem(
        id: json['id'],
        medicationStockId: json['medication_stock'],
        medicationName: json['medication_name'],
        quantity: json['quantity'] ?? 0,
        dispensed: json['dispensed'] ?? false,
      );
}
