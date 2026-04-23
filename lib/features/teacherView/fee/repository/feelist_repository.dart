// lib/features/teacherView/fee/repository/feelist_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/teacher_model.dart';

class FeeListRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get teacher as TeacherModel
  Future<TeacherModel?> getTeacher(String teacherId) async {
    final doc = await _db.collection(FirebaseConstant.teacher).doc(teacherId).get();
    if (!doc.exists) return null;
    return TeacherModel.fromMap(doc.data()!);
  }

  /// Stream pending fees as List<FeeModel>
  Stream<List<FeeModel>> getPendingFees(String teacherId) {
    return _db.collection(FirebaseConstant.fees).snapshots().map((snap) {
      final List<FeeModel> list = [];

      for (final doc in snap.docs) {
        final root = doc.data();
        // iterate classNo -> division -> feeData
        root.forEach((classNo, classData) {
          if (classData is Map<String, dynamic>) {
            classData.forEach((division, feeData) {
              if (feeData is Map<String, dynamic>) {
                final teacherMatch = feeData['teacherId']?.toString() ?? '';
                final isDeleted = feeData['delete'] ?? false;
                final isCompleted = feeData['completed'] ?? false;

                if (teacherMatch == teacherId && isDeleted == false && isCompleted == false) {
                  // Build a map that matches FeeModel.fromMap expectations
                  final m = <String, dynamic>{
                    'description': doc.id,
                    'fee': (feeData['fee'] ?? feeData['amount'] ?? 0).toDouble(),
                    'totalAmount': (feeData['totalAmount'] ?? 0).toDouble(),
                    'classNo': int.tryParse(classNo.toString()) ?? classNo,
                    'collectedCount': feeData['collectedCount'] ?? 0,
                    'division': division,
                    'teacherName': feeData['teacherName'] ?? '',
                    'teacherId': feeData['teacherId'] ?? '',
                    'delete': feeData['delete'] ?? false,
                    'completed': feeData['completed'] ?? false,
                    'createdDate': feeData['createdDate'] ?? Timestamp.now(),
                    'students': feeData['students'] ?? [],
                  };

                  list.add(FeeModel.fromMap(m));
                }
              }
            });
          }
        });
      }
      return list;
    });
  }

  /// Stream completed fees as List<FeeModel>
  Stream<List<FeeModel>> getCompletedFees(String teacherId) {
    return _db.collection(FirebaseConstant.fees).snapshots().map((snap) {
      final List<FeeModel> list = [];

      for (final doc in snap.docs) {
        final root = doc.data();
        root.forEach((classNo, classData) {
          if (classData is Map<String, dynamic>) {
            classData.forEach((division, feeData) {
              if (feeData is Map<String, dynamic>) {
                final teacherMatch = feeData['teacherId']?.toString() ?? '';
                final isDeleted = feeData['delete'] ?? false;
                final isCompleted = feeData['completed'] ?? false;

                if (teacherMatch == teacherId && isDeleted == false && isCompleted == true) {
                  final m = <String, dynamic>{
                    'description': doc.id,
                    'fee': (feeData['fee'] ?? feeData['amount'] ?? 0).toDouble(),
                    'totalAmount': (feeData['totalAmount'] ?? 0).toDouble(),
                    'classNo': int.tryParse(classNo.toString()) ?? classNo,
                    'collectedCount': feeData['collectedCount'] ?? 0,
                    'division': division,
                    'teacherName': feeData['teacherName'] ?? '',
                    'teacherId': feeData['teacherId'] ?? '',
                    'delete': feeData['delete'] ?? false,
                    'completed': feeData['completed'] ?? false,
                    'createdDate': feeData['createdDate'] ?? Timestamp.now(),
                    'students': feeData['students'] ?? [],
                  };

                  list.add(FeeModel.fromMap(m));
                }
              }
            });
          }
        });
      }
      return list;
    });
  }

  /// Save a fee (add or update) — we store createdDate as Timestamp
  Future<void> saveFee({
    required FeeModel fee,
  }) async {
    final description = fee.description.trim();
    final classKey = fee.classNo.toString();
    final division = fee.division;

    final feeMap = {
      "fee": fee.fee,
      "totalAmount": fee.totalAmount,
      "collectedCount": fee.collectedCount,
      "teacherName": fee.teacherName,
      "teacherId": fee.teacherId,
      "createdDate": Timestamp.fromDate(fee.createdDate),
      "delete": fee.delete,
      "completed": fee.completed,
      "students": fee.students,
    };

    await _db.collection(FirebaseConstant.fees).doc(description).set({
      classKey: {division: feeMap}
    }, SetOptions(merge: true));
  }

  /// Soft delete
  Future<void> deleteFee(String description, String classNo, String division) async {
    await _db.collection(FirebaseConstant.fees).doc(description).update({
      "$classNo.$division.delete": true,"$classNo.$division.deletedAt": FieldValue.serverTimestamp(),
    });
  }

  /// Count total students for teacher
  Future<int> getTotalStudents(String teacherId) async {
    final snap = await _db
        .collection(FirebaseConstant.student)
        .where("delete", isEqualTo: false)
        .where("teacherId", isEqualTo: teacherId)
        .get();
    return snap.docs.length;
  }

  /// Get student list for teacher (used by bottomsheet)
  Future<List<Map<String, dynamic>>> getStudentsOfTeacher(String teacherId) async {
    final snap = await _db
        .collection(FirebaseConstant.student)
        .where("delete", isEqualTo: false)
        .where("teacherId", isEqualTo: teacherId)
        .get();

    return snap.docs.map((doc) {
      return {
        "name": doc["studentName"],
        "id": doc["studentId"],
        "status": "unpaid",
        "collected": false,
      };
    }).toList();
  }

  /// Get fee descriptions (doc ids) for suggestion list
  Future<List<String>> getFeeDescriptions() async {
    final snap = await _db.collection(FirebaseConstant.fees).get();
    return snap.docs.map((d) => d.id).toList();
  }
}
