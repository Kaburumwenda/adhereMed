import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  static const _storage = FlutterSecureStorage();
  static bool _initialized = false;

  /// Current tenant schema sent with every request.
  static String? _tenantSchema;

  static Dio get instance {
    if (!_initialized) {
      _dio.interceptors.add(_AuthInterceptor());
      _initialized = true;
    }
    return _dio;
  }

  /// Set the active tenant schema (e.g. 'hospital_demo', 'pharmacy_demo').
  static Future<void> setTenantSchema(String? schema) async {
    _tenantSchema = schema;
    if (schema != null) {
      await _storage.write(key: AppConstants.tenantSchemaKey, value: schema);
    } else {
      await _storage.delete(key: AppConstants.tenantSchemaKey);
    }
  }

  /// Get the current tenant schema.
  static String? get tenantSchema => _tenantSchema;

  /// Restore tenant schema from storage (call at startup).
  static Future<void> restoreTenantSchema() async {
    _tenantSchema = await _storage.read(key: AppConstants.tenantSchemaKey);
  }

  static Future<void> setTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  static Future<String?> get accessToken =>
      _storage.read(key: AppConstants.accessTokenKey);

  static Future<String?> get refreshToken =>
      _storage.read(key: AppConstants.refreshTokenKey);

  static Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final data = await _storage.read(key: AppConstants.userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await ApiClient.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    // Attach tenant schema header (skip for public endpoints)
    final path = options.path;
    final isPublicEndpoint = path.contains('/tenants/register') ||
        path.contains('/auth/login') ||
        path.contains('/auth/register/');
    if (!isPublicEndpoint) {
      final schema = ApiClient.tenantSchema;
      if (schema != null) {
        options.headers['X-Tenant-Schema'] = schema;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Auto token-refresh is temporarily disabled.
    // 401s are passed through so screens can show their existing data
    // rather than silently wiping tokens and causing empty states.
    handler.next(err);
  }
}
