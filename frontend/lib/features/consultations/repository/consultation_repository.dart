import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/consultation_model.dart';

class ConsultationRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Consultation>> getList({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response =
        await _dio.get('/consultations/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Consultation.fromJson);
  }

  Future<Consultation> getDetail(int id) async {
    final response = await _dio.get('/consultations/$id/');
    return Consultation.fromJson(response.data);
  }

  Future<Consultation> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/consultations/', data: data);
    return Consultation.fromJson(response.data);
  }

  Future<Consultation> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/consultations/$id/', data: data);
    return Consultation.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/consultations/$id/');
  }
}
