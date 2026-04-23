import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:scholo_admin/features/students/repository/student_repository.dart';
import 'package:scholo_admin/models/students_model.dart';

final studentRepositoryProvider = Provider((ref) => StudentRepository());

final studentControllerProvider = StateNotifierProvider<StudentController,
    AsyncValue<List<StudentsModel>>>((ref) {
  return StudentController(ref);
});

class StudentController
    extends StateNotifier<AsyncValue<List<StudentsModel>>> {
  final Ref _ref;

  StudentController(this._ref) : super(const AsyncValue.loading()) {
    _listenStudents();
  }

  void _listenStudents() {
    _ref.read(studentRepositoryProvider).streamStudents().listen((students) {
      state = AsyncValue.data(students);
    });
  }

  Future<List<Map<String, dynamic>>> fetchTeachers() async {
    return _ref.read(studentRepositoryProvider).fetchTeachers();
  }

  Future<String> uploadStudentImage(File file) async {
    return _ref.read(studentRepositoryProvider).uploadStudentImage(file);
  }

  Future<void> saveStudent(StudentsModel model) async {
    await _ref.read(studentRepositoryProvider).saveStudent(model);
  }

  Future<void> deleteStudent(String id) async {
    await _ref.read(studentRepositoryProvider).deleteStudent(id);
  }
}
