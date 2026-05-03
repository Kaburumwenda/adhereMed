import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/ward_model.dart';

class WardRepository {
  final Dio _dio = ApiClient.instance;

  // ─── Wards ───
  Future<PaginatedResponse<Ward>> getWards({
    int page = 1,
    String? search,
    String? type,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (type != null && type.isNotEmpty) params['type'] = type;
    final response = await _dio.get('/wards/wards/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Ward.fromJson);
  }

  Future<Ward> getWard(int id) async {
    final response = await _dio.get('/wards/wards/$id/');
    return Ward.fromJson(response.data);
  }

  Future<Ward> createWard(Map<String, dynamic> data) async {
    final response = await _dio.post('/wards/wards/', data: data);
    return Ward.fromJson(response.data);
  }

  Future<Ward> updateWard(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/wards/wards/$id/', data: data);
    return Ward.fromJson(response.data);
  }

  Future<void> deleteWard(int id) async {
    await _dio.delete('/wards/wards/$id/');
  }

  // ─── Beds ───
  Future<PaginatedResponse<Bed>> getBeds({
    int page = 1,
    String? search,
    int? wardId,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (wardId != null) params['ward'] = wardId;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _dio.get('/wards/beds/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Bed.fromJson);
  }

  Future<Bed> createBed(Map<String, dynamic> data) async {
    final response = await _dio.post('/wards/beds/', data: data);
    return Bed.fromJson(response.data);
  }

  Future<Bed> updateBed(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/wards/beds/$id/', data: data);
    return Bed.fromJson(response.data);
  }

  Future<void> deleteBed(int id) async {
    await _dio.delete('/wards/beds/$id/');
  }

  // ─── Admissions ───
  Future<PaginatedResponse<Admission>> getAdmissions({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response =
        await _dio.get('/wards/admissions/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Admission.fromJson);
  }

  Future<Admission> getAdmission(int id) async {
    final response = await _dio.get('/wards/admissions/$id/');
    return Admission.fromJson(response.data);
  }

  Future<Admission> createAdmission(Map<String, dynamic> data) async {
    final response = await _dio.post('/wards/admissions/', data: data);
    return Admission.fromJson(response.data);
  }

  Future<Admission> updateAdmission(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/wards/admissions/$id/', data: data);
    return Admission.fromJson(response.data);
  }

  Future<void> deleteAdmission(int id) async {
    await _dio.delete('/wards/admissions/$id/');
  }
}
