import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../models/exchange_model.dart';

class ExchangeRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<PrescriptionExchange>> getExchanges({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _dio.get('/exchange/', queryParameters: params);
    return PaginatedResponse.fromJson(
        response.data, PrescriptionExchange.fromJson);
  }

  Future<PrescriptionExchange> getExchange(int id) async {
    final response = await _dio.get('/exchange/$id/');
    return PrescriptionExchange.fromJson(response.data);
  }

  Future<List<PharmacyQuote>> getQuotes(int exchangeId) async {
    final response = await _dio.get('/exchange/$exchangeId/quotes/');
    final data = response.data;
    final List results = data is List ? data : (data['results'] as List?) ?? [];
    return results
        .map((e) => PharmacyQuote.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptQuote(int exchangeId, int quoteId) async {
    await _dio.post('/exchange/$exchangeId/quotes/$quoteId/accept/');
  }

  Future<List<Map<String, dynamic>>> getPharmacies() async {
    final response = await _dio.get('/exchange/pharmacies/');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<PharmacyQuote> generateQuote(int exchangeId, int pharmacyTenantId) async {
    final response = await _dio.post(
      '/exchange/$exchangeId/generate-quote/',
      data: {'pharmacy_tenant_id': pharmacyTenantId},
    );
    return PharmacyQuote.fromJson(response.data);
  }
}
