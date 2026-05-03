import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/department_model.dart';

class DepartmentRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Department>> getList({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/departments/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Department.fromJson);
  }

  Future<Department> getDetail(int id) async {
    final response = await _dio.get('/departments/$id/');
    return Department.fromJson(response.data);
  }

  Future<Department> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/departments/', data: data);
    return Department.fromJson(response.data);
  }

  Future<Department> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/departments/$id/', data: data);
    return Department.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/departments/$id/');
  }
}
