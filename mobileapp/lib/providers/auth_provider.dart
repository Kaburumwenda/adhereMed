import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api.dart';
import '../models/user.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final User? user;
  final bool loading;
  final bool initialized;
  final String? error;

  const AuthState({this.user, this.loading = false, this.initialized = false, this.error});

  bool get isLoggedIn => user != null;
  String get role => user?.role ?? '';
  String get tenantType => user?.tenantType ?? '';
  String get tenantSchema => user?.tenantSchema ?? '';

  AuthState copyWith({User? user, bool? loading, bool? initialized, String? error, bool clearUser = false, bool clearError = false}) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      loading: loading ?? this.loading,
      initialized: initialized ?? this.initialized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState()) {
    restore();
  }

  Future<void> restore() async {
    final storage = _ref.read(secureStorageProvider);
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      state = state.copyWith(initialized: true);
      return;
    }
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get('/auth/me/');
      final user = User.fromJson(res.data);
      state = state.copyWith(user: user, initialized: true);
    } catch (_) {
      await storage.deleteAll();
      state = state.copyWith(initialized: true, clearUser: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.post('/auth/login/', data: {'email': email, 'password': password});
      final data = res.data;
      final user = User.fromJson(data['user']);
      final tokens = data['tokens'];

      final storage = _ref.read(secureStorageProvider);
      await storage.write(key: 'access_token', value: tokens['access']);
      await storage.write(key: 'refresh_token', value: tokens['refresh']);
      if (user.tenantSchema != null) {
        await storage.write(key: 'tenant_schema', value: user.tenantSchema!);
      }

      state = state.copyWith(user: user, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final storage = _ref.read(secureStorageProvider);
      final refresh = await storage.read(key: 'refresh_token');
      if (refresh != null) {
        final dio = _ref.read(dioProvider);
        await dio.post('/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {}
    final storage = _ref.read(secureStorageProvider);
    await storage.deleteAll();
    state = const AuthState(initialized: true);
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/auth/change-password/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
      return true;
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
      return false;
    }
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) {
          return data['detail'] ?? data['message'] ?? data.values.first.toString();
        }
        if (data is String) return data;
      } catch (_) {}
    }
    return 'Something went wrong. Please try again.';
  }
}
