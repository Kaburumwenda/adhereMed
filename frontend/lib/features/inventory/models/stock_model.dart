double _toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class Category {
  final int id;
  final String name;
  final String? description;
  final String? createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'] ?? '',
        description: json['description'],
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description ?? '',
      };
}

class Unit {
  final int id;
  final String name;
  final String? abbreviation;
  final String? createdAt;

  Unit({
    required this.id,
    required this.name,
    this.abbreviation,
    this.createdAt,
  });

  factory Unit.fromJson(Map<String, dynamic> json) => Unit(
        id: json['id'],
        name: json['name'] ?? '',
        abbreviation: json['abbreviation'],
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'abbreviation': abbreviation ?? '',
      };
}

class MedicationStock {
  final int id;
  final String medicationId;
  final String medicationName;
  final double sellingPrice;
  final double costPrice;
  final int reorderLevel;
  final int reorderQuantity;
  final String? locationInStore;
  final String? barcode;
  final String prescriptionRequired;
  final bool isActive;
  final int? totalQuantity;
  final bool? isLowStock;
  final String? createdAt;
  final List<StockBatch> batches;
  final int? category;
  final String? categoryName;
  final int? unit;
  final String? unitName;
  final String? unitAbbreviation;

  MedicationStock({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.sellingPrice,
    this.costPrice = 0,
    this.reorderLevel = 10,
    this.reorderQuantity = 50,
    this.locationInStore,
    this.barcode,
    this.prescriptionRequired = 'none',
    this.isActive = true,
    this.totalQuantity,
    this.isLowStock,
    this.createdAt,
    this.batches = const [],
    this.category,
    this.categoryName,
    this.unit,
    this.unitName,
    this.unitAbbreviation,
  });

  factory MedicationStock.fromJson(Map<String, dynamic> json) =>
      MedicationStock(
        id: json['id'],
        medicationId: json['medication_id']?.toString() ?? '',
        medicationName: json['medication_name'] ?? '',
        sellingPrice: _toDouble(json['selling_price']),
        costPrice: _toDouble(json['cost_price']),
        reorderLevel: json['reorder_level'] ?? 10,
        reorderQuantity: json['reorder_quantity'] ?? 50,
        locationInStore: json['location_in_store'],
        barcode: json['barcode'],
        prescriptionRequired: json['prescription_required'] ?? 'none',
        isActive: json['is_active'] ?? true,
        totalQuantity: json['total_quantity'],
        isLowStock: json['is_low_stock'],
        createdAt: json['created_at'],
        batches: (json['batches'] as List? ?? [])
            .map((e) => StockBatch.fromJson(e))
            .toList(),
        category: json['category'],
        categoryName: json['category_name'],
        unit: json['unit'],
        unitName: json['unit_name'],
        unitAbbreviation: json['unit_abbreviation'],
      );

  Map<String, dynamic> toJson() => {
        'medication_id': medicationId,
        'medication_name': medicationName,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'reorder_level': reorderLevel,
        'reorder_quantity': reorderQuantity,
        'location_in_store': locationInStore,
        'barcode': barcode,
        'prescription_required': prescriptionRequired,
        'is_active': isActive,
        'category': category,
        'unit': unit,
      };
}

class StockBatch {
  final int id;
  final int? stockId;
  final String? stockName;
  final String batchNumber;
  final int quantityReceived;
  final int quantityRemaining;
  final double costPricePerUnit;
  final String expiryDate;
  final String? receivedDate;
  final bool isExpired;

  StockBatch({
    required this.id,
    this.stockId,
    this.stockName,
    required this.batchNumber,
    required this.quantityReceived,
    required this.quantityRemaining,
    this.costPricePerUnit = 0,
    required this.expiryDate,
    this.receivedDate,
    this.isExpired = false,
  });

  factory StockBatch.fromJson(Map<String, dynamic> json) => StockBatch(
        id: json['id'],
        stockId: json['stock'],
        stockName: json['stock_name'],
        batchNumber: json['batch_number'] ?? '',
        quantityReceived: json['quantity_received'] ?? 0,
        quantityRemaining: json['quantity_remaining'] ?? 0,
        costPricePerUnit: _toDouble(json['cost_price_per_unit']),
        expiryDate: json['expiry_date'] ?? '',
        receivedDate: json['received_date'],
        isExpired: json['is_expired'] ?? false,
      );
}
