// lib/features/auth/controller/login_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../repository/login_repository.dart';

final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepository();
});

/// Controls login process
final loginControllerProvider =
StateNotifierProvider<LoginController, AsyncValue<void>>((ref) {
  final repo = ref.read(loginRepositoryProvider);
  return LoginController(repo);
});

class LoginController extends StateNotifier<AsyncValue<void>> {
  final LoginRepository _repository;

  LoginController(this._repository) : super(const AsyncData(null));

  Future<bool> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final success = await _repository.loginAdmin(email, password);
      state = const AsyncData(null);
      return success;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<String?> restoreSession() async {
    return await _repository.getSavedRole();
  }
}
