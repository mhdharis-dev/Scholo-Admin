
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';

final monthWiseReportRepositoryProvider =
Provider((ref) => MonthWiseReportRepository(FirebaseFirestore.instance));

class MonthWiseReportRepository {
  final FirebaseFirestore _firestore;

  MonthWiseReportRepository(this._firestore);

  // 🔹 Teacher
  Future<TeacherModel> fetchTeacher(String teacherId) async {
    final snap = await _firestore
        .schoolCollection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();

    if (!snap.exists) throw Exception('Teacher not found');
    return TeacherModel.fromMap(snap.data()!);
  }

  // 🔹 Month Attendance (REAL STRUCTURE)
  Future<List<Map<String, dynamic>>> fetchMonthAttendance({
    required String teacherId,
    required String monthKey,
  }) async
  {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final snap = await _firestore.schoolCollection(FirebaseConstant.attendance).get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final raw = doc.data();

      // 📌 Extract date from doc ID
      final idParts = doc.id.split('-'); // [dd,mm,yyyy]
      final extractedDate = DateTime(
        int.parse(idParts[2]),
        int.parse(idParts[1]),
        int.parse(idParts[0]),
      );

      if (extractedDate.year != year || extractedDate.month != month) {
        continue;
      }

      final Map<String, dynamic> filteredData = {};

      raw.forEach((classKey, divisions) {
        if (divisions is Map<String, dynamic>) {
          divisions.forEach((divKey, students) {
            if (students is List) {
              final matching = students
                  .where((s) =>
              s is Map<String, dynamic> &&
                  s['teacherId'] == teacherId)
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList();

              if (matching.isNotEmpty) {
                filteredData.putIfAbsent(classKey, () => {});
                filteredData[classKey][divKey] = matching;
              }
            }
          });
        }
      });

      if (filteredData.isNotEmpty) {
        result.add({
          'date': extractedDate,
          'data': filteredData,
        });
      }
    }

    result.sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    return result;
  }



  // 🔒 Web-safe deep conversion
  Map<String, dynamic> _deepConvertMap(Map<String, dynamic> input) {
    final Map<String, dynamic> result = {};
    input.forEach((k, v) {
      if (v is Map) {
        result[k.toString()] =
            _deepConvertMap(Map<String, dynamic>.from(v));
      } else if (v is List) {
        result[k.toString()] = v.map((e) {
          if (e is Map) {
            return _deepConvertMap(Map<String, dynamic>.from(e));
          }
          return e;
        }).toList();
      } else {
        result[k.toString()] = v;
      }
    });
    return result;
  }
}
