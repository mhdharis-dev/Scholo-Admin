import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/models/timeTable_model.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/otherFiles_model.dart';

class TimetableAndOtherFilesPageRepository {
  final FirebaseFirestore _firestore;
  TimetableAndOtherFilesPageRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// 🔥 Get otherFiles (Latest First)
  Stream<List<OtherFilesModel>> getOtherFiles(String teacherId) {
    return _firestore
        .schoolCollection(FirebaseConstant.otherFile)
        .where('teacherId', isEqualTo: teacherId)
        .where('delete', isEqualTo: false)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => OtherFilesModel.fromMap(doc.data()))
        .toList());
  }

  /// 🔥 Soft Delete Other Files
  Future<void> softDeleteOtherFiles(String id) async {
    await _firestore
        .schoolCollection(FirebaseConstant.otherFile)
        .doc(id)
        .update({
      'delete': true,
      'deletedDate': Timestamp.now(),
    });
  }

  /// 🔥 Update Title
  Future<void> updateTitleOtherFiles(String id, String newTitle) async {
    await _firestore
        .schoolCollection(FirebaseConstant.otherFile)
        .doc(id)
        .update({
      'tittle': newTitle, // Note: Ensure 'tittle' isn't a typo for 'title' in Firestore
    });
  }

  /// 🔥 Get timetable (Latest First)
  Stream<List<TimetableModel>> getTimeTables(String classNo, String division, String teacherId) {
    return _firestore
        .schoolCollection(FirebaseConstant.timetable)
        .doc(classNo) // Target the document ID directly (e.g., "12")
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];

      final data = doc.data();
      final divisions = data?['divisions'] as Map<String, dynamic>?;

      // Access the specific division (e.g., "G")
      final divisionData = divisions?[division] as Map<String, dynamic>?;
      final timetables = divisionData?['timetables'] as Map<String, dynamic>?;

      List<TimetableModel> result = [];

      if (timetables != null) {
        timetables.forEach((year, val) {
          final map = val as Map<String, dynamic>;

          // Filter by teacherId and ensure 'delete' is false
          if (map['classTeacherId'] == teacherId && map['delete'] != true) {
            result.add(TimetableModel.fromMap(map, doc.id));
          }
        });
      }
      return result;
    });
  }

  /// 🔥 Soft Delete Timetable
  Future<void> softDeleteTimeTables(String id) async {
    await _firestore
        .schoolCollection(FirebaseConstant.timetable)
        .doc(id)
        .update({
      'delete': true,
      'deletedDate': Timestamp.now(),
    });
  }
}

// --- PROVIDERS ---

final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

final timetableAndOtherFilesPageRepositoryProvider = Provider((ref) {
  return TimetableAndOtherFilesPageRepository(
    firestore: ref.watch(firestoreProvider),
  );
});

// StreamProvider for Other Files
final otherFilesStreamProvider = StreamProvider.family<List<OtherFilesModel>, String>((ref, teacherId) {
  final repo = ref.watch(timetableAndOtherFilesPageRepositoryProvider);
  return repo.getOtherFiles(teacherId);
});

// StreamProvider for Timetables
final timetablesListProvider = StreamProvider.family<List<TimetableModel>, Map<String, dynamic>>((ref, params) {
  final repo = ref.watch(timetableAndOtherFilesPageRepositoryProvider);
  return repo.getTimeTables(
      params['classNo'],
      params['division'],
      params['teacherId']
  );
});