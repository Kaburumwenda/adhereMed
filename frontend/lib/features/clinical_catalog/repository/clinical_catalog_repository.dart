import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/clinical_catalog_models.dart';

class ClinicalCatalogRepository {
  final Dio _dio = ApiClient.instance;

  // ── Allergies ──────────────────────────────────────────────────────────────

  Future<List<AllergyModel>> getAllergies({
    String q = '',
    String category = '',
    bool? isActive,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['search'] = q;
    if (category.isNotEmpty) params['category'] = category;
    if (isActive != null) params['is_active'] = isActive;
    if (pageSize != null) params['page_size'] = pageSize;
    final res = await _dio.get('/clinical-catalog/allergies/', queryParameters: params);
    final data = res.data;
    final list = (data is List) ? data : (data['results'] as List<dynamic>? ?? []);
    return list.map((e) => AllergyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AllergyModel> createAllergy(Map<String, dynamic> data) async {
    final res = await _dio.post('/clinical-catalog/allergies/', data: data);
    return AllergyModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AllergyModel> updateAllergy(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/clinical-catalog/allergies/$id/', data: data);
    return AllergyModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteAllergy(int id) async {
    await _dio.delete('/clinical-catalog/allergies/$id/');
  }

  // ── Chronic Conditions ─────────────────────────────────────────────────────

  Future<List<ChronicConditionModel>> getConditions({
    String q = '',
    String category = '',
    bool? isActive,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['search'] = q;
    if (category.isNotEmpty) params['category'] = category;
    if (isActive != null) params['is_active'] = isActive;
    if (pageSize != null) params['page_size'] = pageSize;
    final res = await _dio.get('/clinical-catalog/conditions/', queryParameters: params);
    final data = res.data;
    final list = (data is List) ? data : (data['results'] as List<dynamic>? ?? []);
    return list.map((e) => ChronicConditionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChronicConditionModel> createCondition(Map<String, dynamic> data) async {
    final res = await _dio.post('/clinical-catalog/conditions/', data: data);
    return ChronicConditionModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChronicConditionModel> updateCondition(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/clinical-catalog/conditions/$id/', data: data);
    return ChronicConditionModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCondition(int id) async {
    await _dio.delete('/clinical-catalog/conditions/$id/');
  }
}
