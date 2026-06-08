// fee_collection_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/teacher_model.dart';
import '../repository/fee_collection_repository.dart';
import '../../../../core/constant/firebase_constant.dart';

final feeCollectionRepositoryProvider = Provider<FeeCollectionRepository>((ref) {
  return FeeCollectionRepository();
});

/// teacher details provider (reuse)
final teacherDetailsProvider = FutureProvider.family<TeacherModel?, String>((ref, teacherId) async {
  final doc = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .doc(teacherId)
      .get();
  if (!doc.exists) return null;
  return TeacherModel.fromMap(doc.data()!);
});

/// Stream of flattened fees for a teacher
final feesProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) {
  final repo = ref.watch(feeCollectionRepositoryProvider);
  return repo.streamFeesByTeacher(teacherId);
});

/// Save a fee (returns future)
final saveFeeProvider = Provider((ref) {
  final repo = ref.read(feeCollectionRepositoryProvider);
  return (FeeModel fee) async {
    await repo.saveFee(fee);
  };
});

/// Update student collected/uncollected
final updateStudentCollectedProvider = Provider((ref) {
  final repo = ref.read(feeCollectionRepositoryProvider);
  return ({
    required String description,
    required String classNo,
    required String division,
    required int studentIndex,
    required bool collected,
    required int perStudentAmount,
  }) async {
    await repo.updateStudentCollected(
      description: description,
      classNo: classNo,
      division: division,
      studentIndex: studentIndex,
      collected: collected,
      perStudentAmount: perStudentAmount,
    );
  };
});

/// Fee descriptions for suggestions
final feeDescriptionsProvider = FutureProvider<List<String>>((ref) {
  final repo = ref.read(feeCollectionRepositoryProvider);
  return repo.getFeeDescriptions();
});

/// Fee doc fetch by description (for auto-fill)
final feeDetailsProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, description) {
  final repo = ref.read(feeCollectionRepositoryProvider);
  return repo.getFeeByDescription(description);
});

final toggleCompletedProvider = Provider((ref) {
  final repo = ref.read(feeCollectionRepositoryProvider);

  return ({
    required String description,
    required int classNo,
    required String division,
    required bool currentValue,
  }) async {
    await repo.setFeeCompleted(
      description: description,
      classNo: classNo,
      division: division,
      completed: !currentValue,
    );
  };
});
