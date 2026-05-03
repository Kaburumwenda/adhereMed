import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/pharmacy_store_models.dart';

class PharmacyStoreRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<PharmacyInfo>> getPharmacies() async {
    final response = await _dio.get('/exchange/pharmacies/');
    return (response.data as List)
        .map((e) => PharmacyInfo.fromJson(e))
        .toList();
  }

  Future<({List<PharmacyProduct> products, int count, String? next, String pharmacyName, List<ProductCategory> categories})>
      getProducts(
    String pharmacyId, {
    int page = 1,
    String? search,
    String? categoryId,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category'] = categoryId;

    final response = await _dio.get(
      '/exchange/pharmacies/$pharmacyId/products/',
      queryParameters: params,
    );
    final data = response.data as Map<String, dynamic>;
    return (
      products: (data['results'] as List)
          .map((e) => PharmacyProduct.fromJson(e))
          .toList(),
      count: data['count'] as int? ?? 0,
      next: data['next'] as String?,
      pharmacyName: data['pharmacy_name'] as String? ?? '',
      categories: (data['categories'] as List? ?? [])
          .map((e) => ProductCategory.fromJson(e))
          .toList(),
    );
  }

  Future<PatientOrder> createOrder(Map<String, dynamic> data) async {
    final response = await _dio.post('/exchange/orders/create/', data: data);
    return PatientOrder.fromJson(response.data);
  }

  Future<PaginatedResponse<PatientOrder>> getOrders({int page = 1}) async {
    final response = await _dio.get(
      '/exchange/orders/',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(response.data, PatientOrder.fromJson);
  }

  Future<PatientOrder> getOrder(String id) async {
    final response = await _dio.get('/exchange/orders/$id/');
    return PatientOrder.fromJson(response.data);
  }

  // ── Pharmacy-side order management ──

  Future<PaginatedResponse<PatientOrder>> getPharmacyOrders({
    int page = 1,
    String? status,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get(
      '/exchange/pharmacy/orders/',
      queryParameters: params,
    );
    return PaginatedResponse.fromJson(response.data, PatientOrder.fromJson);
  }

  Future<PatientOrder> updateOrderStatus(int orderId, String status) async {
    final response = await _dio.patch(
      '/exchange/pharmacy/orders/$orderId/status/',
      data: {'status': status},
    );
    return PatientOrder.fromJson(response.data);
  }
}
