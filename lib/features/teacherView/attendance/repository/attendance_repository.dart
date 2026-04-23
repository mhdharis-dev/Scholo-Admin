import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/students_model.dart';
import '../../../../models/attendance_model.dart';

class AttendanceRepository {
  final FirebaseFirestore _fire;

  AttendanceRepository({FirebaseFirestore? firestore})
      : _fire = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get firestore => _fire;

  // -----------------------------------------------------
  // FETCH TEACHER DETAILS
  // -----------------------------------------------------
  Future<TeacherModel> fetchTeacher(String teacherId) async {
    final doc =
    await _fire.collection(FirebaseConstant.teacher).doc(teacherId).get();

    if (!doc.exists) {
      throw Exception("Teacher not found");
    }

    return TeacherModel.fromMap(doc.data()!);
  }

  // -----------------------------------------------------
  // FETCH STUDENTS OF TEACHER'S CLASS/DIVISION
  // -----------------------------------------------------
  Future<List<StudentsModel>> fetchStudents(TeacherModel teacher) async {
    final snap = await _fire
        .collection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .where('classNo', isEqualTo: teacher.classNo)
        .where('division', isEqualTo: teacher.division.toUpperCase())
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      data['studentId'] = doc.id;
      return StudentsModel.fromMap(data);
    }).toList();
  }

  // -----------------------------------------------------
  // FETCH EXISTING ATTENDANCE FOR A DATE + HALF
  // -----------------------------------------------------
  Future<Map<String, AttendanceModel>> fetchExistingAttendance({
    required DateTime date,
    required TeacherModel teacher,
  }) async {
    final dateId =
        " ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

    final doc =
    await _fire.collection(FirebaseConstant.attendance).doc(dateId).get();

    if (!doc.exists) return {};

    final allData = doc.data()!;
    final classKey = teacher.classNo.toString();
    final classDiv = teacher.division.toUpperCase();

    if (allData[classKey] == null ||
        allData[classKey][classDiv] == null ||
        allData[classKey][classDiv] is! List) {
      return {};
    }

    final List list = allData[classKey][classDiv];

    final mapped = <String, AttendanceModel>{
      for (var e in list)
        e["studentId"]: AttendanceModel.fromMap(Map<String, dynamic>.from(e)),
    };

    return mapped;
  }

  // -----------------------------------------------------
  // SAVE FINAL ATTENDANCE
  // -----------------------------------------------------
  Future<void> saveAttendanceToFirestore({
    required DateTime date,
    required TeacherModel teacher,
    required List<AttendanceModel> finalList,
  }) async {
    final dateId =
        " ${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";

    final classKey = teacher.classNo.toString();
    final classDiv = teacher.division.toUpperCase();

    final payload = {
      classKey: {classDiv: finalList.map((e) => e.toMap()).toList()}
    };

    await _fire
        .collection(FirebaseConstant.attendance)
        .doc(dateId)
        .set(payload, SetOptions(merge: true));
  }

  // -----------------------------------------------------
  // PREFERENCES FOR LOCAL CACHE
  // -----------------------------------------------------
  static const _kStatus = "attendance_status";
  static const _kHalf = "attendance_half";
  static const _kDate = "attendance_date";

  Future<void> saveCache({
    required Map<String, bool?> status,
    required String half,
    required DateTime date,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kStatus, jsonEncode(status));
    await prefs.setString(_kHalf, half);
    await prefs.setString(_kDate, date.toIso8601String());
  }

  Future<Map<String, dynamic>> loadCache() async {
    final prefs = await SharedPreferences.getInstance();

    final map = <String, bool?>{};
    final jsonStr = prefs.getString(_kStatus);

    if (jsonStr != null) {
      final decoded = jsonDecode(jsonStr);
      decoded.forEach((key, value) => map[key] = value as bool?);
    }

    final half = prefs.getString(_kHalf) ?? "Morning";
    final dateIso = prefs.getString(_kDate);

    return {
      "status": map,
      "half": half,
      "date": dateIso != null ? DateTime.parse(dateIso) : DateTime.now(),
    };
  }
}

// Provider
final attendanceRepositoryProvider = Provider((ref) {
  return AttendanceRepository();
});
