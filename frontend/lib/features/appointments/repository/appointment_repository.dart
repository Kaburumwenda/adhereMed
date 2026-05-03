import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/appointment_model.dart';

class AppointmentRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Appointment>> getList({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/appointments/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Appointment.fromJson);
  }

  Future<Appointment> getDetail(int id) async {
    final response = await _dio.get('/appointments/$id/');
    return Appointment.fromJson(response.data);
  }

  Future<Appointment> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/appointments/', data: data);
    return Appointment.fromJson(response.data);
  }

  Future<Appointment> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/appointments/$id/', data: data);
    return Appointment.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/appointments/$id/');
  }
}
