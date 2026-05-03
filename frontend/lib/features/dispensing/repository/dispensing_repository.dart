import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/dispensing_model.dart';

class DispensingRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<DispensingRecord>> getRecords({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/dispensing/', queryParameters: params);
    return PaginatedResponse.fromJson(
        response.data, DispensingRecord.fromJson);
  }

  Future<DispensingRecord> getRecord(int id) async {
    final response = await _dio.get('/dispensing/$id/');
    return DispensingRecord.fromJson(response.data);
  }

  Future<DispensingRecord> createRecord(Map<String, dynamic> data) async {
    final response = await _dio.post('/dispensing/', data: data);
    return DispensingRecord.fromJson(response.data);
  }

  Future<DispensingRecord> updateRecord(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/dispensing/$id/', data: data);
    return DispensingRecord.fromJson(response.data);
  }

  Future<void> deleteRecord(int id) async {
    await _dio.delete('/dispensing/$id/');
  }
}
