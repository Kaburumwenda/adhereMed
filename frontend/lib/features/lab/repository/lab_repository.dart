import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/lab_order_model.dart';

class LabRepository {
  final Dio _dio = ApiClient.instance;

  // ─── Test Catalog ───
  Future<PaginatedResponse<LabTestCatalog>> getCatalog({
    int page = 1,
    String? search,
    String? department,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (department != null && department.isNotEmpty) params['department'] = department;
    final response = await _dio.get('/lab/catalog/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, LabTestCatalog.fromJson);
  }

  Future<List<LabTestCatalog>> getAllCatalogTests() async {
    final tests = <LabTestCatalog>[];
    int page = 1;
    while (true) {
      final response = await _dio.get('/lab/catalog/', queryParameters: {'page': page, 'page_size': 100});
      final data = PaginatedResponse.fromJson(response.data, LabTestCatalog.fromJson);
      tests.addAll(data.results);
      if (data.next == null) break;
      page++;
    }
    return tests;
  }

  // ─── Lab Orders ───
  Future<PaginatedResponse<LabOrder>> getOrders({
    int page = 1,
    String? search,
    String? status,
    String? priority,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;
    final response = await _dio.get('/lab/orders/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, LabOrder.fromJson);
  }

  Future<LabOrder> getOrder(int id) async {
    final response = await _dio.get('/lab/orders/$id/');
    return LabOrder.fromJson(response.data);
  }

  Future<LabOrder> createOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/lab/orders/', data: data);
    return LabOrder.fromJson(response.data);
  }

  Future<LabOrder> updateOrder(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/lab/orders/$id/', data: data);
    return LabOrder.fromJson(response.data);
  }

  Future<void> deleteOrder(int id) async {
    await _dio.delete('/lab/orders/$id/');
  }

  // ─── Lab Results ───
  Future<LabResult> createResult(Map<String, dynamic> data) async {
    final response = await _dio.post('/lab/results/', data: data);
    return LabResult.fromJson(response.data);
  }

  Future<LabResult> updateResult(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/lab/results/$id/', data: data);
    return LabResult.fromJson(response.data);
  }

  Future<Map<String, dynamic>> sendToLab(int orderId) async {
    final response = await _dio.post('/lab/orders/$orderId/send_to_lab/');
    return Map<String, dynamic>.from(response.data);
  }
}
