import 'package:dio/dio.dart';

import '../models/paginated_response.dart';

class PaginatedApiService<T> {
  final Dio dio;
  final String endpoint;
  final T Function(Map<String, dynamic>) fromJson;

  PaginatedApiService({
    required this.dio,
    required this.endpoint,
    required this.fromJson,
  });

  Future<PaginatedResponse<T>> fetchPage(
    int page, {
    String? search,
    Map<String, dynamic>? filters,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      if (search != null && search.isNotEmpty) 'search': search,
      if (filters != null) ...filters,
    };

    final response = await dio.get(
      endpoint,
      queryParameters: queryParams,
    );

    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      fromJson,
    );
  }
}
