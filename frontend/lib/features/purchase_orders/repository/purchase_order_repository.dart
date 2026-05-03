import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/purchase_order_model.dart';

class PurchaseOrderRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<PurchaseOrder>> getPurchaseOrders({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response =
        await _dio.get('/purchase-orders/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, PurchaseOrder.fromJson);
  }

  Future<PurchaseOrder> getPurchaseOrder(int id) async {
    final response = await _dio.get('/purchase-orders/$id/');
    return PurchaseOrder.fromJson(response.data);
  }

  Future<PurchaseOrder> createPurchaseOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/purchase-orders/', data: data);
    return PurchaseOrder.fromJson(response.data);
  }

  Future<PurchaseOrder> updatePurchaseOrder(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/purchase-orders/$id/', data: data);
    return PurchaseOrder.fromJson(response.data);
  }

  Future<void> deletePurchaseOrder(int id) async {
    await _dio.delete('/purchase-orders/$id/');
  }

  // ─── Goods Received Notes ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGRNsForOrder(int orderId) async {
    final response = await _dio.get('/purchase-orders/grns/',
        queryParameters: {'purchase_order': orderId});
    final data = response.data;
    final list = data is Map ? (data['results'] ?? []) : data as List;
    return (list as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> createGRN(Map<String, dynamic> data) async {
    final response =
        await _dio.post('/purchase-orders/grns/', data: data);
    return response.data as Map<String, dynamic>;
  }
}
