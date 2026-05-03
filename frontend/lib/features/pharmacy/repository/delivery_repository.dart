import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';

class Delivery {
  final int id;
  final int transaction;
  final String? transactionNumber;
  final String deliveryAddress;
  final String recipientName;
  final String recipientPhone;
  final double deliveryFee;
  final String status;
  final int? assignedTo;
  final String? assignedToName;
  final String? notes;
  final DateTime? scheduledAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;

  Delivery({
    required this.id,
    required this.transaction,
    this.transactionNumber,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryFee,
    required this.status,
    this.assignedTo,
    this.assignedToName,
    this.notes,
    this.scheduledAt,
    this.deliveredAt,
    required this.createdAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
        id: json['id'] as int,
        transaction: json['transaction'] as int,
        transactionNumber: json['transaction_number'] as String?,
        deliveryAddress: json['delivery_address'] as String,
        recipientName: json['recipient_name'] as String,
        recipientPhone: json['recipient_phone'] as String,
        deliveryFee: double.tryParse('${json['delivery_fee']}') ?? 0,
        status: json['status'] as String,
        assignedTo: json['assigned_to'] as int?,
        assignedToName: json['assigned_to_name'] as String?,
        notes: json['notes'] as String?,
        scheduledAt: json['scheduled_at'] != null ? DateTime.parse(json['scheduled_at'] as String) : null,
        deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

class DeliveryRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Delivery>> getDeliveries({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _dio.get('/pharmacy-profile/deliveries/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Delivery.fromJson);
  }

  Future<Delivery> getDelivery(int id) async {
    final response = await _dio.get('/pharmacy-profile/deliveries/$id/');
    return Delivery.fromJson(response.data);
  }

  Future<Delivery> createDelivery(Map<String, dynamic> data) async {
    final response = await _dio.post('/pharmacy-profile/deliveries/', data: data);
    return Delivery.fromJson(response.data);
  }

  Future<Delivery> updateStatus(int id, String status) async {
    final response = await _dio.post('/pharmacy-profile/deliveries/$id/update_status/', data: {'status': status});
    return Delivery.fromJson(response.data);
  }
}
