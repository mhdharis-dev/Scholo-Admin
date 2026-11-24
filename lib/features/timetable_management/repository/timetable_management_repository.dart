import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constant/firebase_constant.dart';
import '../../../models/timeTable_model.dart';
import '../../../models/daftTimetable_model.dart';

class TimetableManagementRepository {
  final FirebaseFirestore _firestore;

  TimetableManagementRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// 🔥 Stream all real-time active published timetables from Firestore
  Stream<List<TimetableModel>> getRealtimeTimetables() {
    return _firestore
        .schoolCollection(FirebaseConstant.timetable)
        .snapshots()
        .map((snapshot) {
      final List<TimetableModel> timetables = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // 1. Check nested structure: divisions -> <divisionKey> -> timetables -> <ttKey>
        if (data.containsKey('divisions') && data['divisions'] is Map) {
          final divisions = data['divisions'] as Map<String, dynamic>;
          divisions.forEach((divKey, divVal) {
            if (divVal is Map && divVal['timetables'] is Map) {
              final ttMap = divVal['timetables'] as Map<String, dynamic>;
              ttMap.forEach((ttKey, ttVal) {
                if (ttVal is Map<String, dynamic>) {
                  // Only include active timetables (not soft-deleted)
                  if (ttVal['delete'] != true) {
                    try {
                      final model = TimetableModel.fromMap(ttVal, doc.id);
                      timetables.add(model);
                    } catch (e, st) {
                      log('Error parsing timetable "$ttKey" in class "${doc.id}": $e\n$st');
                    }
                  }
                }
              });
            }
          });
        }

        // 2. Fallback check for flat timetable document structure
        if (data.containsKey('timetableName') && data['delete'] != true) {
          try {
            final model = TimetableModel.fromMap(data, doc.id);
            timetables.add(model);
          } catch (e, st) {
            log('Error parsing flat timetable doc "${doc.id}": $e\n$st');
          }
        }
      }

      // Sort by created date descending (newest first)
      timetables.sort((a, b) => b.createdDate.compareTo(a.createdDate));
      return timetables;
    });
  }

  /// 🔥 Stream all real-time draft timetables from Firestore
  Stream<List<DraftTimetableModel>> getRealtimeDrafts() {
    return _firestore
        .schoolCollection(FirebaseConstant.draftTimetable)
        .where('delete', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DraftTimetableModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// 🔥 Soft delete timetable
  Future<void> softDeleteTimetable({
    required String classNo,
    required String division,
    required String timetableName,
  }) async {
    final docRef = _firestore.schoolCollection(FirebaseConstant.timetable).doc(classNo);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data();
    if (data != null && data.containsKey('divisions')) {
      await docRef.update({
        'divisions.$division.timetables.$timetableName.delete': true,
        'divisions.$division.timetables.$timetableName.deletedDate': Timestamp.now(),
      });
    } else {
      // Flat document fallback
      await docRef.update({
        'delete': true,
        'deletedDate': Timestamp.now(),
      });
    }
  }
}

// ── Providers ──
final timetableManagementRepositoryProvider = Provider<TimetableManagementRepository>((ref) {
  return TimetableManagementRepository(firestore: FirebaseFirestore.instance);
});
