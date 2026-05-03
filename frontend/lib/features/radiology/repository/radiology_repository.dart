import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/radiology_model.dart';

class RadiologyRepository {
  final Dio _dio = ApiClient.instance;

  // ─── Orders ───
  Future<PaginatedResponse<RadiologyOrder>> getOrders({
    int page = 1,
    String? search,
    String? status,
    String? imagingType,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (imagingType != null && imagingType.isNotEmpty) {
      params['imaging_type'] = imagingType;
    }
    final response =
        await _dio.get('/radiology/orders/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, RadiologyOrder.fromJson);
  }

  Future<RadiologyOrder> getOrder(int id) async {
    final response = await _dio.get('/radiology/orders/$id/');
    return RadiologyOrder.fromJson(response.data);
  }

  Future<RadiologyOrder> createOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/radiology/orders/', data: data);
    return RadiologyOrder.fromJson(response.data);
  }

  Future<RadiologyOrder> updateOrder(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/radiology/orders/$id/', data: data);
    return RadiologyOrder.fromJson(response.data);
  }

  Future<void> deleteOrder(int id) async {
    await _dio.delete('/radiology/orders/$id/');
  }

  // ─── Results ───
  Future<RadiologyResult> createResult(Map<String, dynamic> data) async {
    final response = await _dio.post('/radiology/results/', data: data);
    return RadiologyResult.fromJson(response.data);
  }

  Future<RadiologyResult> updateResult(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/radiology/results/$id/', data: data);
    return RadiologyResult.fromJson(response.data);
  }
}
