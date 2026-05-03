import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repository/auth_repository.dart';
import '../models/auth_state.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  late final AuthRepository _repo;

  @override
  Future<User?> build() async {
    _repo = ref.read(authRepositoryProvider);
    return _repo.tryRestoreSession();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repo.login(LoginRequest(
        email: email,
        password: password,
      ));
      return result.user;
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final result = await _repo.register(RegisterRequest(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      ));
      return result.user;
    });
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(null);
  }
}
