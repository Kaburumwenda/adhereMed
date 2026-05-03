import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/invoice_model.dart';

class BillingRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Invoice>> getList({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response =
        await _dio.get('/billing/invoices/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Invoice.fromJson);
  }

  Future<Invoice> getDetail(int id) async {
    final response = await _dio.get('/billing/invoices/$id/');
    return Invoice.fromJson(response.data);
  }

  Future<Invoice> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/billing/invoices/', data: data);
    return Invoice.fromJson(response.data);
  }

  Future<Invoice> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/billing/invoices/$id/', data: data);
    return Invoice.fromJson(response.data);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/billing/invoices/$id/');
  }

  Future<Map<String, dynamic>> recordPayment(
      int invoiceId, Map<String, dynamic> data) async {
    final response = await _dio.post(
      '/billing/invoices/$invoiceId/record_payment/',
      data: data,
    );
    return response.data;
  }
}
