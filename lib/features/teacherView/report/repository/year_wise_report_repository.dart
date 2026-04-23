import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';

final yearWiseReportRepositoryProvider =
Provider<YearWiseReportRepository>((ref) {
  return YearWiseReportRepository();
});

class YearWiseReportRepository {
  /// Fetch teacher details by ID
  Future<TeacherModel?> fetchTeacherById(String teacherId) async {
    final doc = await FirebaseFirestore.instance
        .collection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();

    if (!doc.exists) return null;
    final data = doc.data()!;
    return TeacherModel.fromMap(data);
  }

  /// Fetch attendance for this teacher and group by month "YYYY-MM"
  ///
  /// Returns:
  /// {
  ///   "2025-11": [
  ///      { "date": "15-11-2025", "data": {...filtered nested map...} },
  ///      ...
  ///   ],
  ///   "2025-10": [...],
  /// }
  Future<Map<String, List<Map<String, dynamic>>>> fetchYearWiseReport(
      String teacherId,
      ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(FirebaseConstant.attendance)
        .get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final doc in snapshot.docs) {
      final String docId = doc.id; // "15-11-2025"
      final String? monthKey = _monthKeyFromDocId(docId); // "2025-11"
      if (monthKey == null) continue;

      final raw = doc.data() as Map<String, dynamic>;
      final Map<String, dynamic> filtered = {};

      // Filter nested structure by teacherId
      raw.forEach((classKey, divisionMap) {
        if (divisionMap is Map<String, dynamic>) {
          final Map<String, dynamic> filteredDivisions = {};

          divisionMap.forEach((divisionKey, students) {
            if (students is List) {
              final filteredStudents = students.where((s) {
                if (s is! Map<String, dynamic>) return false;
                final tId = (s['teacherId'] ?? '').toString();
                return tId == teacherId;
              }).toList();

              if (filteredStudents.isNotEmpty) {
                filteredDivisions[divisionKey] = filteredStudents;
              }
            }
          });

          if (filteredDivisions.isNotEmpty) {
            filtered[classKey] = filteredDivisions;
          }
        }
      });

      if (filtered.isNotEmpty) {
        grouped.putIfAbsent(monthKey, () => []);
        grouped[monthKey]!.add({
          'date': docId, // keep "15-11-2025"
          'data': filtered,
        });
      }
    }

    // Sort dates in each month
    grouped.forEach((key, list) {
      list.sort((a, b) {
        final da = a['date'] as String;
        final db = b['date'] as String;
        return _compareDDMMYYYY(da, db);
      });
    });

    return grouped;
  }

  /// "15-11-2025" -> "2025-11"
  String? _monthKeyFromDocId(String id) {
    try {
      final parts = id.split('-'); // [DD, MM, YYYY]
      if (parts.length != 3) return null;
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      final _ = day;
      return '$year-$month';
    } catch (_) {
      return null;
    }
  }

  int _compareDDMMYYYY(String a, String b) {
    try {
      final pa = a.split('-'); // [DD, MM, YYYY]
      final pb = b.split('-');
      final da = DateTime(
        int.parse(pa[2]),
        int.parse(pa[1]),
        int.parse(pa[0]),
      );
      final db = DateTime(
        int.parse(pb[2]),
        int.parse(pb[1]),
        int.parse(pb[0]),
      );
      return da.compareTo(db);
    } catch (_) {
      return a.compareTo(b);
    }
  }
}
