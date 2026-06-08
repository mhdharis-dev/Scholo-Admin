// lib/features/teacherView/class_dashbord/controller/teacherdashbord_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/otherTeacher_model.dart';
import '../repository/teacherdashbord_repository.dart';
import '../../../../models/teacher_model.dart';

final teacherDashbordRepositoryProvider = Provider((ref) => TeacherDashbordRepository());

/// Teacher details
final teacherDetailsProvider = FutureProvider.family<TeacherModel?, String>((ref, teacherId) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getTeacher(teacherId);
});

/// Total students
final totalStudentsProvider = FutureProvider.family<int, String>((ref, teacherId) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getTotalStudents(teacherId);
});

/// Fees stream (re-usable)
final feesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getFees(teacherId);
});

/// Fee descriptions suggestions
final feeDescriptionsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getFeeDescriptions();
});

/// Today attendance counts provider (present/absent)
final todayAttendanceProvider = FutureProvider.family<Map<String, int>, String>((ref, teacherId) async {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getTodayAttendanceCounts(teacherId);
});

final saveFeeProvider = Provider((ref) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return (FeeModel fee) => repo.saveFee(fee);
});

/// ✅ Other Teachers Provider

final otherTeachersProvider =
StreamProvider.family<List<OtherTeacherModel>, String>((ref, teacherId) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.streamOtherTeachers(teacherId);
});

/// ✅ Single Teacher Provider (by ID)
final singleTeacherProvider =
FutureProvider.family<TeacherModel?, String>((ref, teacherId) {
  final repo = ref.read(teacherDashbordRepositoryProvider);
  return repo.getTeacher(teacherId);
});

