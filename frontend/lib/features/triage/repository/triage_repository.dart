import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/triage_model.dart';

class TriageRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<TriageRecord>> getList({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/triage/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, TriageRecord.fromJson);
  }

  Future<TriageRecord> getDetail(int id) async {
    final response = await _dio.get('/triage/$id/');
    return TriageRecord.fromJson(response.data);
  }

  Future<TriageRecord> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/triage/', data: data);
    return TriageRecord.fromJson(response.data);
  }

  Future<TriageRecord> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/triage/$id/', data: data);
    return TriageRecord.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/triage/$id/');
  }
}
