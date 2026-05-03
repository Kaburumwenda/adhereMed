import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/auth_state.dart';

class AuthRepository {
  final Dio _dio = ApiClient.instance;

  Future<({User user, AuthTokens tokens})> login(LoginRequest request) async {
    final response = await _dio.post('/auth/login/', data: request.toJson());
    final data = response.data as Map<String, dynamic>;
    final user = User.fromJson(data['user']);
    final tokens = AuthTokens.fromJson(data['tokens']);

    await ApiClient.setTokens(access: tokens.access, refresh: tokens.refresh);
    await ApiClient.saveUser(data['user']);

    // Set tenant schema from user's tenant so API calls target the right schema
    if (user.tenantSchema != null) {
      await ApiClient.setTenantSchema(user.tenantSchema!);
    }

    return (user: user, tokens: tokens);
  }

  Future<({User user, AuthTokens tokens})> register(
      RegisterRequest request) async {
    final response =
        await _dio.post('/auth/register/', data: request.toJson());
    final data = response.data as Map<String, dynamic>;
    final user = User.fromJson(data['user']);
    final tokens = AuthTokens.fromJson(data['tokens']);

    await ApiClient.setTokens(access: tokens.access, refresh: tokens.refresh);
    await ApiClient.saveUser(data['user']);
    return (user: user, tokens: tokens);
  }

  Future<User> getMe() async {
    final response = await _dio.get('/auth/me/');
    return User.fromJson(response.data);
  }

  Future<void> logout() async {
    try {
      final refreshToken = await ApiClient.refreshToken;
      if (refreshToken != null) {
        await _dio.post('/auth/logout/', data: {'refresh': refreshToken});
      }
    } catch (_) {
      // Even if logout API fails, clear local tokens
    } finally {
      await ApiClient.clearTokens();
    }
  }

  Future<User?> tryRestoreSession() async {
    final token = await ApiClient.accessToken;
    if (token == null) return null;
    try {
      return await getMe();
    } catch (_) {
      await ApiClient.clearTokens();
      return null;
    }
  }
}
