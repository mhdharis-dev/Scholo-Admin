// lib/features/auth/controller/login_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repository/login_repository.dart';
import '../../models/school_model.dart';
import '../../../core/config/session_manager.dart';

final loginRepositoryProvider = Provider<LoginRepository>((ref) {
  return LoginRepository();
});

final schoolStreamProvider = StreamProvider<SchoolModel?>((ref) {
  final schoolId = SessionManager.schoolId;
  if (schoolId.isEmpty) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('schools')
      .doc(schoolId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return SchoolModel.fromMap(snapshot.data()!);
      });
});

final updateSchoolProvider = Provider((ref) {
  return (SchoolModel school) async {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(school.schoolId)
        .update(school.toMap());
  };
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
