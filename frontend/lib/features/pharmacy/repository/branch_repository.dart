import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/branch_model.dart';

class BranchRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<Branch>> getBranches({bool? isActive}) async {
    final params = <String, dynamic>{};
    if (isActive != null) params['is_active'] = isActive;

    final response = await _dio.get(
      '/pharmacy-profile/branches/',
      queryParameters: params.isNotEmpty ? params : null,
    );

    final data = response.data;
    final List<dynamic> results =
        data is List ? data : (data['results'] as List? ?? []);
    return results.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Branch> getBranch(int id) async {
    final response = await _dio.get('/pharmacy-profile/branches/$id/');
    return Branch.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Branch> createBranch(Map<String, dynamic> data) async {
    final response = await _dio.post('/pharmacy-profile/branches/', data: data);
    return Branch.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Branch> updateBranch(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/pharmacy-profile/branches/$id/', data: data);
    return Branch.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBranch(int id) async {
    await _dio.delete('/pharmacy-profile/branches/$id/');
  }
}
