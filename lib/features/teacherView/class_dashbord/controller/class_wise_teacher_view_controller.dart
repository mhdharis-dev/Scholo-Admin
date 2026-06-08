// lib/features/teacherView/class_dashbord/controller/classwiseteacherview_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repository/class_wise_teacher_view_repository.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/class_model.dart';

/// Repository provider
final classWiseTeacherRepoProvider = Provider((ref) {
  return ClassWiseTeacherViewRepository(FirebaseFirestore.instance);
});

/// Fetch all teachers
/// 🔥 Real-time teachers provider
final teachersProvider = StreamProvider<List<TeacherModel>>((ref) {
  final repo = ref.read(classWiseTeacherRepoProvider);
  return repo.watchAllTeachers();
});

/// Fetch teacher by ID
final teacherDetailsProvider =
FutureProvider.family<TeacherModel?, String>((ref, teacherId) async {
  final repo = ref.read(classWiseTeacherRepoProvider);
  return repo.getTeacher(teacherId);
});

/// Fetch all classes
final classesStreamProvider = StreamProvider<List<ClassModel>>((ref) {
  final repo = ref.read(classWiseTeacherRepoProvider);
  return repo.watchAllClasses();
});
