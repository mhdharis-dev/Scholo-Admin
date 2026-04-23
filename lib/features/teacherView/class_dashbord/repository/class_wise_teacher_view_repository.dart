// lib/features/teacherView/class_dashbord/repository/classwiseteacherview_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';

class ClassWiseTeacherViewRepository {
  final FirebaseFirestore _db;

  ClassWiseTeacherViewRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  /// 🔹 Get all teachers
  /// 🔥 Real-time stream of all teachers
  Stream<List<TeacherModel>> watchAllTeachers() {
    return _db
        .collection(FirebaseConstant.teacher)
        .where("delete", isEqualTo: false)
        .orderBy("classNo")
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => TeacherModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// 🔹 Get teacher by id
  Future<TeacherModel?> getTeacher(String teacherId) async {
    final doc = await _db
        .collection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();

    if (!doc.exists) return null;
    return TeacherModel.fromMap(doc.data()!);
  }
}
