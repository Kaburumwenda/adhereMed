import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../models/superadmin_models.dart';

class SuperAdminRepository {
  final Dio _dio = ApiClient.instance;

  // ── Stats ────────────────────────────────────────────────────────────────────

  Future<PlatformStats> getStats() async {
    final res = await _dio.get('/superadmin/stats/');
    return PlatformStats.fromJson(res.data as Map<String, dynamic>);
  }

  // ── Tenants ───────────────────────────────────────────────────────────────────

  Future<List<TenantAdminModel>> getTenants({
    String q = '',
    String type = '',
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['q'] = q;
    if (type.isNotEmpty) params['type'] = type;
    final res = await _dio.get('/superadmin/tenants/', queryParameters: params);
    final data = res.data;
    final list = (data is List) ? data : (data['results'] as List<dynamic>? ?? []);
    return list
        .map((e) => TenantAdminModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TenantAdminModel> getTenant(int id) async {
    final res = await _dio.get('/superadmin/tenants/$id/');
    return TenantAdminModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TenantAdminModel> updateTenant(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/superadmin/tenants/$id/', data: data);
    return TenantAdminModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final res = await _dio.post('/superadmin/tenants/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> toggleTenantActive(int id) async {
    await _dio.post('/superadmin/tenants/$id/toggle-active/');
  }

  Future<Map<String, dynamic>> getTenantStats(int id) async {
    final res = await _dio.get('/superadmin/tenants/$id/stats/');
    return res.data as Map<String, dynamic>;
  }

  // ── Users ─────────────────────────────────────────────────────────────────────

  Future<List<AdminUserModel>> getUsers({
    String q = '',
    String role = '',
    String tenantId = '',
    String isActive = '',
  }) async {
    final params = <String, dynamic>{};
    if (q.isNotEmpty) params['q'] = q;
    if (role.isNotEmpty) params['role'] = role;
    if (tenantId.isNotEmpty) params['tenant_id'] = tenantId;
    if (isActive.isNotEmpty) params['is_active'] = isActive;
    final res = await _dio.get('/superadmin/users/', queryParameters: params);
    final data = res.data;
    final list = (data is List) ? data : (data['results'] as List<dynamic>? ?? []);
    return list
        .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUserModel> getUser(int id) async {
    final res = await _dio.get('/superadmin/users/$id/');
    return AdminUserModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AdminUserModel> updateUser(int id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/superadmin/users/$id/', data: data);
    return AdminUserModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> resetUserPassword(int id, {String? newPassword}) async {
    final data = <String, dynamic>{};
    if (newPassword != null && newPassword.isNotEmpty) {
      data['new_password'] = newPassword;
    }
    final res = await _dio.post('/superadmin/users/$id/reset-password/', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> toggleUserActive(int id) async {
    await _dio.post('/superadmin/users/$id/toggle-active/');
  }

  // ── Seed Data ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSeedCatalog() async {
    final res = await _dio.get('/superadmin/seed/');
    return (res.data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> runSeed({
    required String command,
    int? tenantId,
    bool reset = false,
  }) async {
    final data = <String, dynamic>{
      'command': command,
      'reset': reset,
    };
    if (tenantId != null) data['tenant_id'] = tenantId;
    final res = await _dio.post('/superadmin/seed/run/', data: data);
    return res.data as Map<String, dynamic>;
  }
}
