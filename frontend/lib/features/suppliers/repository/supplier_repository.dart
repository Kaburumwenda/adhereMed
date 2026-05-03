import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/supplier_model.dart';

class SupplierRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Supplier>> getSuppliers({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/suppliers/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Supplier.fromJson);
  }

  Future<Supplier> getSupplier(int id) async {
    final response = await _dio.get('/suppliers/$id/');
    return Supplier.fromJson(response.data);
  }

  Future<Supplier> createSupplier(Map<String, dynamic> data) async {
    final response = await _dio.post('/suppliers/', data: data);
    return Supplier.fromJson(response.data);
  }

  Future<Supplier> updateSupplier(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/suppliers/$id/', data: data);
    return Supplier.fromJson(response.data);
  }

  Future<void> deleteSupplier(int id) async {
    await _dio.delete('/suppliers/$id/');
  }
}
