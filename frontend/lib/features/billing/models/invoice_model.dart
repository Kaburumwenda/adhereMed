double _toDouble(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

class Invoice {
  final int id;
  final String? invoiceNumber;
  final int? patientId;
  final String? patientName;
  final int? consultationId;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double totalAmount;
  final double amountPaid;
  final double balanceDue;
  final String status;
  final String? dueDate;
  final String? notes;
  final String? createdAt;
  final List<dynamic>? items;
  final List<dynamic>? payments;

  Invoice({
    required this.id,
    this.invoiceNumber,
    this.patientId,
    this.patientName,
    this.consultationId,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discount = 0,
    this.totalAmount = 0,
    this.amountPaid = 0,
    this.balanceDue = 0,
    required this.status,
    this.dueDate,
    this.notes,
    this.createdAt,
    this.items,
    this.payments,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'];
    return Invoice(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      patientId: patient is Map ? patient['id'] : json['patient'],
      patientName: patient is Map
          ? '${patient['user']?['first_name'] ?? ''} ${patient['user']?['last_name'] ?? ''}'
              .trim()
          : null,
      consultationId: json['consultation'],
      subtotal: _toDouble(json['subtotal']),
      taxAmount: _toDouble(json['tax_amount']),
      discount: _toDouble(json['discount']),
      totalAmount: _toDouble(json['total_amount']),
      amountPaid: _toDouble(json['amount_paid']),
      balanceDue: _toDouble(json['balance_due']),
      status: json['status'] ?? 'draft',
      dueDate: json['due_date'],
      notes: json['notes'],
      createdAt: json['created_at'],
      items: json['items'] as List?,
      payments: json['payments'] as List?,
    );
  }

  Map<String, dynamic> toJson() => {
        'patient': patientId,
        'consultation': consultationId,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'discount': discount,
        'total_amount': totalAmount,
        'status': status,
        'due_date': dueDate,
        'notes': notes,
      };
}
