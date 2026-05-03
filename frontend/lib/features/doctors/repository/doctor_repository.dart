import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/doctor_model.dart';

class DoctorRepository {
  final Dio _dio = ApiClient.instance;

  /// Register a new doctor account.
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/doctors/register/', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Public doctor directory (paginated, searchable).
  Future<PaginatedResponse<DoctorProfile>> getDirectory({
    int page = 1,
    String? search,
    String? specialization,
    String? practiceType,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (specialization != null && specialization.isNotEmpty) {
      params['specialization'] = specialization;
    }
    if (practiceType != null && practiceType.isNotEmpty) {
      params['practice_type'] = practiceType;
    }
    final response = await _dio.get(
      '/doctors/directory/',
      queryParameters: params,
    );
    return PaginatedResponse.fromJson(response.data, DoctorProfile.fromJson);
  }

  /// Get a single doctor profile detail.
  Future<DoctorProfile> getDoctor(int id) async {
    final response = await _dio.get('/doctors/directory/$id/');
    return DoctorProfile.fromJson(response.data);
  }

  /// Get the logged-in doctor's own profile.
  Future<DoctorProfile> getMyProfile() async {
    final response = await _dio.get('/doctors/me/');
    return DoctorProfile.fromJson(response.data);
  }

  /// Update the logged-in doctor's profile.
  Future<DoctorProfile> updateMyProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/doctors/me/', data: data);
    return DoctorProfile.fromJson(response.data);
  }
}
