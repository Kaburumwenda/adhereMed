class PurchaseOrder {
  final int id;
  final String? poNumber;
  final int? supplierId;
  final String? supplierName;
  final String status;
  final double totalAmount;
  final String? notes;
  final String? createdAt;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    this.poNumber,
    this.supplierId,
    this.supplierName,
    required this.status,
    this.totalAmount = 0,
    this.notes,
    this.createdAt,
    this.items = const [],
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'];
    return PurchaseOrder(
      id: json['id'],
      poNumber: json['po_number'],
      supplierId: supplier is Map ? supplier['id'] : json['supplier'],
      supplierName: supplier is Map ? supplier['name'] : null,
      status: json['status'] ?? 'draft',
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      notes: json['notes'],
      createdAt: json['created_at'],
      items: (json['items'] as List? ?? [])
          .map((e) => PurchaseOrderItem.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'supplier': supplierId,
        'status': status,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseOrderItem {
  final int? id;
  final int? medicationStockId;
  final String? medicationName;
  final int quantity;
  final double unitCost;
  final double totalCost;

  PurchaseOrderItem({
    this.id,
    this.medicationStockId,
    this.medicationName,
    required this.quantity,
    required this.unitCost,
    this.totalCost = 0,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) =>
      PurchaseOrderItem(
        id: json['id'],
        medicationStockId: json['medication_stock'] is Map
            ? json['medication_stock']['id']
            : json['medication_stock'],
        medicationName: json['medication_stock'] is Map
            ? json['medication_stock']['medication_name']
            : json['medication_name'],
        quantity: json['quantity'] ?? 0,
        unitCost: (json['unit_cost'] ?? 0).toDouble(),
        totalCost: (json['total_cost'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'medication_stock': medicationStockId,
        'quantity': quantity,
        'unit_cost': unitCost,
      };
}
