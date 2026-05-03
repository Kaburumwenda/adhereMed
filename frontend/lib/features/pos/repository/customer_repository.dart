import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/models/paginated_response.dart';

class Customer {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double totalPurchases;
  final int visitCount;
  final bool isActive;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.totalPurchases,
    required this.visitCount,
    required this.isActive,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        notes: json['notes'] as String?,
        totalPurchases: double.tryParse('${json['total_purchases']}') ?? 0,
        visitCount: json['visit_count'] as int? ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CustomerRepository {
  final Dio _dio = ApiClient.instance;

  Future<PaginatedResponse<Customer>> getCustomers({
    int page = 1,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _dio.get('/pos/customers/', queryParameters: params);
    return PaginatedResponse.fromJson(response.data, Customer.fromJson);
  }

  Future<Customer> getCustomer(int id) async {
    final response = await _dio.get('/pos/customers/$id/');
    return Customer.fromJson(response.data);
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    final response = await _dio.post('/pos/customers/', data: data);
    return Customer.fromJson(response.data);
  }

  Future<Customer> updateCustomer(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/pos/customers/$id/', data: data);
    return Customer.fromJson(response.data);
  }

  Future<void> deleteCustomer(int id) async {
    await _dio.delete('/pos/customers/$id/');
  }
}
