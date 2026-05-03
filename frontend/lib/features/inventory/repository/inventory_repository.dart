import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/stock_model.dart';

class InventoryRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<MedicationStock>> getStocks({
    int page = 1,
    String? search,
    int? category,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (category != null) params['category'] = category;
    final response = await _dio.get('/inventory/stocks/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, MedicationStock.fromJson);
  }

  Future<MedicationStock> getStock(int id) async {
    final response = await _dio.get('/inventory/stocks/$id/');
    return MedicationStock.fromJson(response.data);
  }

  Future<MedicationStock> createStock(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/stocks/', data: data);
    return MedicationStock.fromJson(response.data);
  }

  Future<MedicationStock> updateStock(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/inventory/stocks/$id/', data: data);
    return MedicationStock.fromJson(response.data);
  }

  Future<void> deleteStock(int id) async {
    await _dio.delete('/inventory/stocks/$id/');
  }

  Future<Map<String, dynamic>> createBatch(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/batches/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBatch(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/inventory/batches/$id/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<PaginatedResponse<MedicationStock>> getLowStock({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response =
        await _dio.get('/inventory/stocks/low_stock/', queryParameters: params);
    if (response.data is List) {
      final list = (response.data as List)
          .map((e) => MedicationStock.fromJson(e as Map<String, dynamic>))
          .toList();
      return PaginatedResponse(count: list.length, results: list);
    }
    return PaginatedResponse.fromJson(response.data as Map<String, dynamic>, MedicationStock.fromJson);
  }

  Future<List<StockBatch>> getExpiringSoon({int days = 30}) async {
    final response = await _dio.get('/inventory/stocks/expiring_soon/', queryParameters: {'days': days});
    final raw = response.data is Map ? (response.data['results'] ?? []) : response.data;
    return (raw as List).map((e) => StockBatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _dio.get('/inventory/analytics/');
    return response.data as Map<String, dynamic>;
  }

  // ── Categories ──

  Future<List<Category>> getCategories() async {
    final response = await _dio.get('/inventory/categories/', queryParameters: {'page_size': 1000});
    final results = response.data is Map ? response.data['results'] : response.data;
    return (results as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> createCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/categories/', data: data);
    return Category.fromJson(response.data);
  }

  Future<Category> updateCategory(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/inventory/categories/$id/', data: data);
    return Category.fromJson(response.data);
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete('/inventory/categories/$id/');
  }

  // ── Units ──

  Future<List<Unit>> getUnits() async {
    final response = await _dio.get('/inventory/units/', queryParameters: {'page_size': 1000});
    final results = response.data is Map ? response.data['results'] : response.data;
    return (results as List).map((e) => Unit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Unit> createUnit(Map<String, dynamic> data) async {
    final response = await _dio.post('/inventory/units/', data: data);
    return Unit.fromJson(response.data);
  }

  Future<Unit> updateUnit(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/inventory/units/$id/', data: data);
    return Unit.fromJson(response.data);
  }

  Future<void> deleteUnit(int id) async {
    await _dio.delete('/inventory/units/$id/');
  }

  // ── Export ──

  /// Returns raw bytes of the export file. [format] = 'csv' | 'excel' | 'pdf'
  Future<List<int>> exportStocks({String format = 'csv'}) async {
    final response = await _dio.get<List<int>>(
      '/inventory/stocks/export/',
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  // ── Import ──

  /// Uploads a CSV or Excel file. Returns summary {created, updated, errors, error_details}.
  Future<Map<String, dynamic>> importStocks(String filePath, String filename) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final response = await _dio.post('/inventory/stocks/import/', data: formData);
    return response.data as Map<String, dynamic>;
  }
}
