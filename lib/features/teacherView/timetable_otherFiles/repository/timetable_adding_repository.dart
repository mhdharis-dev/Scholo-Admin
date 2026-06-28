import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/timeTable_model.dart';
import '../../../../models/daftTimetable_model.dart';

class TimetableRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream teacher data
  Stream<TeacherModel> getTeacher(String teacherId) {
    return _firestore
        .schoolCollection(FirebaseConstant.teacher)
        .doc(teacherId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return TeacherModel.fromMap(snapshot.data()!);
      }
      throw Exception("Teacher not found");
    });
  }

  // Publish final timetable
  Future<void> publishTimetable({
    required String classNo,
    required String division,
    required String timetableName,
    required TimetableModel model,
  }) async {
    await _firestore.schoolCollection(FirebaseConstant.timetable).doc(classNo).set({
      'divisions': {
        division: {
          'timetables': {
            timetableName: model.toMap(),
          }
        }
      }
    }, SetOptions(merge: true));
  }

  // Save or Update Draft
  Future<String> saveDraft(DraftTimetableModel model, {String? draftId}) async {
    if (draftId != null) {
      await _firestore
          .schoolCollection(FirebaseConstant.draftTimetable)
          .doc(draftId)
          .set(model.toMap());
      return draftId;
    } else {
      final doc = await _firestore
          .schoolCollection(FirebaseConstant.draftTimetable)
          .add(model.toMap());
      return doc.id;
    }
  }

  // Delete Draft
  Future<void> deleteDraft(String draftId) async {
    await _firestore
        .schoolCollection(FirebaseConstant.draftTimetable)
        .doc(draftId)
        .delete();
  }

  // Delete Draft by name and teacherId
  Future<void> deleteDraftByName({
    required String teacherId,
    required String timetableName,
  }) async {
    final querySnapshot = await _firestore
        .schoolCollection(FirebaseConstant.draftTimetable)
        .where('teacherId', isEqualTo: teacherId)
        .where('timetableName', isEqualTo: timetableName)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }
}

// Providers
final timetableRepositoryProvider = Provider((ref) => TimetableRepository());

final teacherStreamProvider = StreamProvider.family<TeacherModel, String>((ref, id) {
  return ref.watch(timetableRepositoryProvider).getTeacher(id);
});