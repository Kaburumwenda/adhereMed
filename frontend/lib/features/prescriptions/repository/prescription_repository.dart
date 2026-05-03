import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/prescription_model.dart';

class PrescriptionRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Prescription>> getList({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response =
        await _dio.get('/prescriptions/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Prescription.fromJson);
  }

  Future<Prescription> getDetail(int id) async {
    final response = await _dio.get('/prescriptions/$id/');
    return Prescription.fromJson(response.data);
  }

  Future<Prescription> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/prescriptions/', data: data);
    return Prescription.fromJson(response.data);
  }

  Future<Prescription> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/prescriptions/$id/', data: data);
    return Prescription.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/prescriptions/$id/');
  }

  Future<Map<String, dynamic>> sendToExchange(int id) async {
    final response =
        await _dio.post('/prescriptions/$id/send_to_exchange/');
    return response.data;
  }
}
