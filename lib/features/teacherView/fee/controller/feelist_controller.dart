// lib/features/teacherView/fee/controller/feelist_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/teacher_model.dart';
import '../repository/feelist_repository.dart';

final feeListRepositoryProvider = Provider((ref) => FeeListRepository());

/// Teacher provider (TeacherModel)
final teacherProvider = FutureProvider.family<TeacherModel?, String>((ref, teacherId) async {
  final repo = ref.read(feeListRepositoryProvider);
  return await repo.getTeacher(teacherId);
});

/// Pending fees as FeeModel list
final pendingFeesProvider = StreamProvider.family<List<FeeModel>, String>((ref, teacherId) {
  final repo = ref.read(feeListRepositoryProvider);
  return repo.getPendingFees(teacherId);
});

/// Completed fees as FeeModel list
final completedFeesProvider = StreamProvider.family<List<FeeModel>, String>((ref, teacherId) {
  final repo = ref.read(feeListRepositoryProvider);
  return repo.getCompletedFees(teacherId);
});

/// Total students count
final totalStudentsProvider = FutureProvider.family<int, String>((ref, teacherId) {
  final repo = ref.read(feeListRepositoryProvider);
  return repo.getTotalStudents(teacherId);
});

/// Fee description suggestions
final feeDescriptionsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.read(feeListRepositoryProvider);
  return repo.getFeeDescriptions();
});

/// Students list for teacher (bottom sheet)
final studentsOfTeacherProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) {
  final repo = ref.read(feeListRepositoryProvider);
  return repo.getStudentsOfTeacher(teacherId);
});

/// Save fee action -> returns a function to call
final saveFeeProvider = Provider<Future<void> Function(FeeModel)>((ref) {
  final repo = ref.read(feeListRepositoryProvider);
  return (FeeModel fee) async {
    await repo.saveFee(fee: fee);
  };
});

/// Delete fee action -> returns a function to call
final deleteFeeProvider = Provider<Future<void> Function(String, String, String)>((ref) {
  final repo = ref.read(feeListRepositoryProvider);
  return (String description, String classNo, String division) async {
    await repo.deleteFee(description, classNo, division);
  };
});
