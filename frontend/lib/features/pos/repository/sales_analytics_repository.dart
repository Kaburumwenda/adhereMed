import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class SalesAnalyticsRepository {
  final Dio _dio = ApiClient.instance;

  Future<Map<String, dynamic>> getSalesAnalytics({
    String period = 'month',
    int? branchId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, dynamic>{'period': period};
    if (branchId != null) params['branch_id'] = branchId;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    final response = await _dio.get('/pos/analytics/', queryParameters: params);
    return response.data as Map<String, dynamic>;
  }
}
