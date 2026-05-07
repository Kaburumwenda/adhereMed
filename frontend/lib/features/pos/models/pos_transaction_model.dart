double _toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class POSTransaction {
  final int id;
  final String? receiptNumber;
  final String? customerName;
  final String? customerPhone;
  final String paymentMethod;
  final String status;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double totalAmount;
  final double amountTendered;
  final double changeGiven;
  final String? servedBy;
  final String? createdAt;
  final List<POSItem> items;

  POSTransaction({
    required this.id,
    this.receiptNumber,
    this.customerName,
    this.customerPhone,
    required this.paymentMethod,
    this.status = 'completed',
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.totalAmount = 0,
    this.amountTendered = 0,
    this.changeGiven = 0,
    this.servedBy,
    this.createdAt,
    this.items = const [],
  });

  factory POSTransaction.fromJson(Map<String, dynamic> json) =>
      POSTransaction(
        id: json['id'],
        receiptNumber: json['transaction_number'] ?? json['receipt_number'],
        customerName: json['customer_name'],
        customerPhone: json['customer_phone'],
        paymentMethod: json['payment_method'] ?? 'cash',
        status: json['status'] ?? 'completed',
        subtotal: _toDouble(json['subtotal']),
        discount: _toDouble(json['discount']),
        taxAmount: _toDouble(json['tax'] ?? json['tax_amount']),
        totalAmount: _toDouble(json['total'] ?? json['total_amount']),
        amountTendered: _toDouble(json['amount_tendered']),
        changeGiven: _toDouble(json['change_given']),
        servedBy: json['cashier_name'] is String
            ? json['cashier_name']
            : json['served_by'] is Map
                ? '${json['served_by']['first_name']} ${json['served_by']['last_name']}'
                : null,
        createdAt: json['created_at'],
        items: (json['items'] as List? ?? [])
            .map((e) => POSItem.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'payment_method': paymentMethod,
        'discount': discount,
        'amount_tendered': amountTendered,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class POSItem {
  final int? id;
  final int? medicationStockId;
  final String? medicationName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  POSItem({
    this.id,
    this.medicationStockId,
    this.medicationName,
    required this.quantity,
    required this.unitPrice,
    this.lineTotal = 0,
  });

  factory POSItem.fromJson(Map<String, dynamic> json) => POSItem(
        id: json['id'],
        medicationStockId: json['medication_stock'] is Map
            ? json['medication_stock']['id']
            : json['medication_stock'],
        medicationName: json['medication_stock'] is Map
            ? json['medication_stock']['medication_name']
            : json['medication_name'],
        quantity: json['quantity'] ?? 0,
        unitPrice: _toDouble(json['unit_price']),
        lineTotal: _toDouble(json['line_total']),
      );

  Map<String, dynamic> toJson() => {
        'medication_stock': medicationStockId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
}
