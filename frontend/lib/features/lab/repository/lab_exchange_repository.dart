import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/lab_exchange_model.dart';

class LabExchangeRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<LabOrderExchange>> getLabExchanges({
    int page = 1,
    String? search,
    String? status,
    String? priority,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (priority != null && priority.isNotEmpty) params['priority'] = priority;
    final response =
        await _dio.get('/exchange/lab/', queryParameters: params);
    return PaginatedResponse.fromJson(
        response.data, LabOrderExchange.fromJson);
  }

  Future<LabOrderExchange> getLabExchange(int id) async {
    final response = await _dio.get('/exchange/lab/$id/');
    return LabOrderExchange.fromJson(response.data);
  }

  Future<LabOrderExchange> createLabExchange(Map<String, dynamic> data) async {
    final response = await _dio.post('/exchange/lab/', data: data);
    return LabOrderExchange.fromJson(response.data);
  }

  Future<LabOrderExchange> updateLabExchange(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/exchange/lab/$id/', data: data);
    return LabOrderExchange.fromJson(response.data);
  }

  Future<LabOrderExchange> acceptLabExchange(int id) async {
    final response = await _dio.post('/exchange/lab/$id/accept/');
    return LabOrderExchange.fromJson(response.data);
  }

  Future<LabOrderExchange> submitResults(
      int id, List<Map<String, dynamic>> results) async {
    final response = await _dio
        .post('/exchange/lab/$id/results/', data: {'results': results});
    return LabOrderExchange.fromJson(response.data);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/exchange/lab/dashboard/');
    return Map<String, dynamic>.from(response.data);
  }
}
