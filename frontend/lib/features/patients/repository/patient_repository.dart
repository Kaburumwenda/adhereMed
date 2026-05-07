import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/patient_model.dart';

class PatientRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Patient>> getPatients({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/patients/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Patient.fromJson);
  }

  Future<Patient> getPatient(int id) async {
    final response = await _dio.get('/patients/$id/');
    return Patient.fromJson(response.data);
  }

  Future<Patient> createPatient(Map<String, dynamic> data) async {
    final response = await _dio.post('/patients/', data: data);
    return Patient.fromJson(response.data);
  }

  Future<Patient> updatePatient(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/patients/$id/', data: data);
    return Patient.fromJson(response.data);
  }

  Future<Patient> getMyProfile() async {
    final response = await _dio.get('/patients/me/');
    return Patient.fromJson(response.data);
  }

  Future<Patient> updateMyProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/patients/me/', data: data);
    return Patient.fromJson(response.data);
  }

  Future<void> deletePatient(int id) async {
    await _dio.delete('/patients/$id/');
  }
}
