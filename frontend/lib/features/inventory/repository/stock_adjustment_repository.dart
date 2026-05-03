import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';

class StockAdjustment {
  final int id;
  final int stock;
  final String? stockName;
  final int? batch;
  final int quantityChange;
  final String reason;
  final String? notes;
  final String? adjustedByName;
  final DateTime createdAt;

  StockAdjustment({
    required this.id,
    required this.stock,
    this.stockName,
    this.batch,
    required this.quantityChange,
    required this.reason,
    this.notes,
    this.adjustedByName,
    required this.createdAt,
  });

  factory StockAdjustment.fromJson(Map<String, dynamic> json) => StockAdjustment(
        id: json['id'] as int,
        stock: json['stock'] as int,
        stockName: json['stock_name'] as String?,
        batch: json['batch'] as int?,
        quantityChange: json['quantity_change'] as int,
        reason: json['reason'] as String,
        notes: json['notes'] as String?,
        adjustedByName: json['adjusted_by_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get reasonLabel {
    switch (reason) {
      case 'damage':
        return 'Damage';
      case 'theft':
        return 'Theft';
      case 'expiry':
        return 'Expiry';
      case 'count_correction':
        return 'Count Correction';
      case 'return_to_supplier':
        return 'Return to Supplier';
      case 'other':
        return 'Other';
      default:
        return reason;
    }
  }
}

class StockAdjustmentRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<StockAdjustment>> getAdjustments({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/inventory/adjustments/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, StockAdjustment.fromJson);
  }

  Future<StockAdjustment> createAdjustment(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/adjustments/', data: data);
    return StockAdjustment.fromJson(response.data);
  }
}
