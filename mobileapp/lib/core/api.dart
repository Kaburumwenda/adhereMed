import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// const kApiBase = 'http://10.0.2.2:8000/api'; // Android emulator → host localhost
const kApiBase = 'https://adheremedapi.tiktek-ex.com/api';

final secureStorageProvider = Provider((_) => const FlutterSecureStorage());

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final dio = Dio(BaseOptions(
    baseUrl: kApiBase,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'access_token');
      final schema = await storage.read(key: 'tenant_schema');
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      if (schema != null) options.headers['X-Tenant-Schema'] = schema;
      handler.next(options);
    },
    onError: (e, handler) async {
      if (e.response?.statusCode == 401) {
        // Token expired — could implement refresh here
      }
      handler.next(e);
    },
  ));

  return dio;
});
