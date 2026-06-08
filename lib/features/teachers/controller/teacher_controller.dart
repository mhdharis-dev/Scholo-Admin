import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:scholo_admin/models/teacher_model.dart';
import '../repository/teacher_repository.dart';

final teacherRepositoryProvider = Provider<TeacherRepository>((ref) => TeacherRepository());

final teacherControllerProvider =
StateNotifierProvider<TeacherController, AsyncValue<List<TeacherModel>>>((ref) {
  final repo = ref.watch(teacherRepositoryProvider);
  return TeacherController(repo);
});

class TeacherController extends StateNotifier<AsyncValue<List<TeacherModel>>> {
  final TeacherRepository _repository;

  TeacherController(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _repository.getTeachers().listen((teachers) {
      state = AsyncValue.data(teachers);
    });
  }

  Future<String?> addTeacher(TeacherModel teacher) async {
    try {
      return await _repository.addTeacher(teacher);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    try {
      await _repository.updateTeacher(teacher);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTeacher(String id) async {
    try {
      await _repository.deleteTeacher(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> uploadImage(File file) async {
    return _repository.uploadImage(file);
  }
}
