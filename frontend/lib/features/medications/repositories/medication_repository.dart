import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/medication_model.dart';

class MedicationRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Medication>> getMedications({
    int page = 1,
    String? search,
    String? category,
    String? dosageForm,
    bool? requiresPrescription,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (dosageForm != null && dosageForm.isNotEmpty) {
      params['dosage_form'] = dosageForm;
    }
    if (requiresPrescription != null) {
      params['requires_prescription'] = requiresPrescription;
    }
    final response =
        await _dio.get('/medications/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Medication.fromJson);
  }

  Future<Medication> getMedication(int id) async {
    final response = await _dio.get('/medications/$id/');
    return Medication.fromJson(response.data);
  }

  Future<List<Medication>> searchMedications(String q) async {
    if (q.length < 2) return [];
    final response =
        await _dio.get('/medications/search/', queryParameters: {'q': q});
    final data = response.data;
    final list = data is List ? data : (data['results'] ?? []) as List;
    return list
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Medication> createMedication(Map<String, dynamic> data) async {
    final response = await _dio.post('/medications/', data: data);
    return Medication.fromJson(response.data);
  }

  Future<Medication> updateMedication(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/medications/$id/', data: data);
    return Medication.fromJson(response.data);
  }
}
