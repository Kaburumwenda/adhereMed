import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/pos_transaction_model.dart';

class POSRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<POSTransaction>> getTransactions({
    int page = 1,
    String? search,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (pageSize != null) params['page_size'] = pageSize;
    final response = await _dio.get('/pos/transactions/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, POSTransaction.fromJson);
  }

  Future<POSTransaction> getTransaction(int id) async {
    final response = await _dio.get('/pos/transactions/$id/');
    return POSTransaction.fromJson(response.data);
  }

  Future<POSTransaction> createTransaction(Map<String, dynamic> data) async {
    final response = await _dio.post('/pos/transactions/', data: data);
    return POSTransaction.fromJson(response.data);
  }

  Future<List<POSTransaction>> getTodayTransactions() async {
    final response = await _dio.get('/pos/transactions/today/');
    return (response.data as List<dynamic>)
        .map((e) => POSTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<POSTransaction> updateTransactionStatus(
      int id, String txnStatus) async {
    final response = await _dio.patch(
      '/pos/transactions/$id/update_status/',
      data: {'status': txnStatus},
    );
    return POSTransaction.fromJson(response.data);
  }

  Future<List<int>> exportTransactions({
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{};
    if (period != null) params['period'] = period;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final response = await _dio.get(
      '/pos/transactions/export/',
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data as List<int>;
  }

  /// Fetches all transactions (no pagination) for PDF export.
  Future<List<POSTransaction>> getAllTransactionsForExport({
    String? period,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{'page_size': 10000};
    if (period != null) params['period'] = period;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final response = await _dio.get('/pos/transactions/',
        queryParameters: params);
    final data = response.data;
    final results = data is Map ? (data['results'] as List? ?? []) : data as List;
    return results
        .map((e) => POSTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
