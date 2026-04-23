// lib/features/teacherView/class_dashbord/repository/teacherdashbord_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/otherTeacher_model.dart';
import '../../../../models/teacher_model.dart';

class TeacherDashbordRepository {
  final FirebaseFirestore _db;
  TeacherDashbordRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  /// Get teacher by id
  Future<TeacherModel?> getTeacher(String teacherId) async {
    final doc = await _db
        .collection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();
    if (!doc.exists) return null;
    return TeacherModel.fromMap(doc.data()!);
  }

  /// Count total students for a teacher
  Future<int> getTotalStudents(String teacherId) async {
    final snap = await _db
        .collection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .where('teacherId', isEqualTo: teacherId)
        .get();
    return snap.docs.length;
  }

  /// Stream fees for this teacher (flattened)
  Stream<List<Map<String, dynamic>>> getFees(String teacherId) {
    return _db.collection(FirebaseConstant.fees).snapshots().map((snap) {
      final List<Map<String, dynamic>> result = [];
      for (final doc in snap.docs) {
        final root = doc.data();
        root.forEach((classNo, classData) {
          if (classData is Map<String, dynamic>) {
            classData.forEach((division, feeData) {
              if (feeData is Map<String, dynamic>) {
                if (feeData['teacherId'] == teacherId &&
                    (feeData['delete'] == false) &&
                    (feeData['completed'] == false)) {
                  result.add({
                    'description': doc.id,
                    'classNo': classNo,
                    'division': division,
                    ...feeData,
                  });
                }
              }
            });
          }
        });
      }
      return result;
    });
  }

  /// Get fee descriptions (doc ids) for suggestions
  Future<List<String>> getFeeDescriptions() async {
    final snap = await _db.collection(FirebaseConstant.fees).get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Compute present/absent counts for today for this teacher,
  /// following your rules around morning/evening windows.
  ///
  /// Returns: { 'present': int, 'absent': int }
  Future<Map<String, int>> getTodayAttendanceCounts(String teacherId) async {
    // 1) get teacher (to obtain classNo + division)
    final teacherDoc = await _db
        .collection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();
    if (!teacherDoc.exists) {
      return {'present': 0, 'absent': 0};
    }
    final teacher = TeacherModel.fromMap(teacherDoc.data()!);
    final classKey = teacher.classNo.toString();
    final divisionKey = teacher.division.toString();

    // 2) date id
    final dateId = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final doc = await _db
        .collection(FirebaseConstant.attendance)
        .doc(dateId)
        .get();
    if (!doc.exists) return {'present': 0, 'absent': 0};

    final data = doc.data();
    if (data == null ||
        data[classKey] == null ||
        data[classKey][divisionKey] == null) {
      return {'present': 0, 'absent': 0};
    }

    // 3) Convert attendance node to iterable list
    final dynamic rawNode = data[classKey][divisionKey];

    // rawNode may be List or Map with numeric keys (0,1,2) — handle both
    final List<dynamic> entries = [];
    if (rawNode is List) {
      entries.addAll(rawNode);
    } else if (rawNode is Map<String, dynamic>) {
      // map of index -> object
      entries.addAll(rawNode.values);
    } else {
      // unknown shape
      return {'present': 0, 'absent': 0};
    }

    // 4) Determine current session (morning/evening/outside)
    final now = DateTime.now();
    final int hour = now.hour;
    final int minute = now.minute;

    bool isMorningWindow =
        (hour == 9 && minute <= 30) ||
        (hour >= 9 && hour < 10 && minute >= 0 && minute <= 59 && hour == 9);
    // keep strict: morning window 9:00-9:30
    isMorningWindow = (hour == 9 && minute <= 30);

    bool isEveningWindow = (hour == 14 && minute <= 30);

    int present = 0;
    int absent = 0;

    for (final e in entries) {
      if (e == null) continue;
      final status = (e['status'] ?? '').toString();
      // treat missing explicit status as Absent (you can change)
      if (status.toLowerCase() == 'absent') {
        absent++;
        continue;
      }

      if (isMorningWindow) {
        // present only if Morning Half or Morning & Evening
        if (status == 'Morning Half' || status == 'Morning & Evening') {
          present++;
        } else {
          absent++;
        }
      } else if (isEveningWindow) {
        // present only if Evening Half or Morning & Evening
        if (status == 'Evening Half' || status == 'Morning & Evening') {
          present++;
        } else {
          absent++;
        }
      } else {
        // outside both windows: count any non-"Absent" as present
        present++;
      }
    }

    return {'present': present, 'absent': absent};
  }

  /// Save Fee using FeeModel
  Future<void> saveFee(FeeModel fee) async {
    await _db.collection(FirebaseConstant.fees).doc(fee.description).set({
      fee.classNo.toString(): {fee.division: fee.toMap()},
    }, SetOptions(merge: true));
  }

  /// ✅ Stream Other Teachers List
  /// ✅ Stream Other Teachers List
  Stream<List<OtherTeacherModel>> streamOtherTeachers(String teacherId) {
    return _db
        .collection(FirebaseConstant.teacher)
        .doc(teacherId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];

      final teacher = TeacherModel.fromMap(doc.data()!);

      return teacher.otherTeachers ?? [];
    });
  }


}
