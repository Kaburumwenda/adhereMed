import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
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

  /// Upload a profile picture for the logged-in doctor.
  /// [bytes] is the raw file data, [filename] is the original file name.
  Future<DoctorProfile> uploadProfilePicture({
    required List<int> bytes,
    required String filename,
  }) async {
    final ext = filename.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'png'
        : ext == 'gif'
            ? 'gif'
            : 'jpeg';
    final formData = FormData.fromMap({
      'profile_picture': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType('image', mime),
      ),
    });
    final response = await _dio.patch(
      '/doctors/me/upload-picture/',
      data: formData,
    );
    return DoctorProfile.fromJson(response.data);
  }

  /// Upload a digital signature for the logged-in doctor.
  /// [bytes] is the raw PNG data.
  Future<DoctorProfile> uploadSignature({
    required List<int> bytes,
    String filename = 'signature.png',
  }) async {
    final formData = FormData.fromMap({
      'signature': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: MediaType('image', 'png'),
      ),
    });
    final response = await _dio.patch(
      '/doctors/me/upload-signature/',
      data: formData,
    );
    return DoctorProfile.fromJson(response.data);
  }

  /// Delete the stored digital signature.
  Future<DoctorProfile> deleteSignature() async {
    final response = await _dio.delete('/doctors/me/delete-signature/');
    return DoctorProfile.fromJson(response.data);
  }
}
