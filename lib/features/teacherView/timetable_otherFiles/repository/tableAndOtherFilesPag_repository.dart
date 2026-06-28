import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/models/timeTable_model.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/otherFiles_model.dart';

class TimetableAndOtherFilesPageRepository {
  final FirebaseFirestore _firestore;
  TimetableAndOtherFilesPageRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Future<void> _updateNoteField(String id, Map<String, dynamic> updates) async {
    // 1. Update flat documents matching 'id' field
    final flatQuery = await _firestore
        .schoolCollection(FirebaseConstant.notes)
        .where('id', isEqualTo: id)
        .get();
    for (var doc in flatQuery.docs) {
      await doc.reference.update(updates);
    }

    // 2. Search and update nested structures
    final snapshot = await _firestore.schoolCollection(FirebaseConstant.notes).get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('teacherId')) {
        // It's a nested document
        String? foundDivision;
        String? foundTitle;
        data.forEach((divisionKey, divisionVal) {
          if (divisionVal is Map<String, dynamic>) {
            divisionVal.forEach((noteTitle, noteData) {
              if (noteData is Map<String, dynamic> && noteData['id'] == id) {
                foundDivision = divisionKey;
                foundTitle = noteTitle;
              }
            });
          }
        });

        if (foundDivision != null && foundTitle != null) {
          // Construct the nested updates map
          final Map<String, dynamic> nestedUpdates = {};
          updates.forEach((key, value) {
            nestedUpdates['$foundDivision.$foundTitle.$key'] = value;
          });
          await doc.reference.update(nestedUpdates);
        }
      }
    }
  }

  /// 🔥 Get otherFiles (Latest First)
  Stream<List<OtherFilesModel>> getOtherFiles(String teacherId) {
    return _firestore
        .schoolCollection(FirebaseConstant.notes)
        .snapshots()
        .map((snapshot) {
      final List<OtherFilesModel> list = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('teacherId')) {
          final isDeleted = data['delete'] == true;
          if (data['teacherId'] == teacherId && !isDeleted) {
            final map = Map<String, dynamic>.from(data);
            if (map['tittle'] == null) {
              map['tittle'] = map['title'] ?? '';
            }
            if (map['uploadedAt'] == null) {
              final idStr = map['id']?.toString() ?? '';
              final ms = int.tryParse(idStr);
              if (ms != null && ms > 1000000000000) {
                map['uploadedAt'] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(ms));
              } else {
                map['uploadedAt'] = Timestamp.now();
              }
            }
            list.add(OtherFilesModel.fromMap(map));
          }
        } else {
          // Nested structure: document ID is classNo, fields are division maps
          data.forEach((divisionKey, divisionVal) {
            if (divisionVal is Map<String, dynamic>) {
              divisionVal.forEach((noteTitle, noteData) {
                if (noteData is Map<String, dynamic>) {
                  final isDeleted = noteData['delete'] == true;
                  if (noteData['teacherId'] == teacherId && !isDeleted) {
                    final map = Map<String, dynamic>.from(noteData);
                    if (map['tittle'] == null || map['tittle'].toString().isEmpty) {
                      map['tittle'] = map['title'] ?? noteTitle;
                    }
                    if (map['classNo'] == null) {
                      map['classNo'] = int.tryParse(doc.id) ?? 0;
                    }
                    if (map['division'] == null || map['division'].toString().isEmpty) {
                      map['division'] = divisionKey;
                    }
                    final idStr = map['id']?.toString() ?? '';
                    final ms = int.tryParse(idStr);
                    if (ms != null && ms > 1000000000000) {
                      map['uploadedAt'] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(ms));
                    } else {
                      map['uploadedAt'] = Timestamp.now();
                    }
                    list.add(OtherFilesModel.fromMap(map));
                  }
                }
              });
            }
          });
        }
      }
      final seenIds = <String>{};
      final List<OtherFilesModel> uniqueList = [];
      for (var note in list) {
        if (note.id.isNotEmpty && !seenIds.contains(note.id)) {
          seenIds.add(note.id);
          uniqueList.add(note);
        }
      }
      uniqueList.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return uniqueList;
    });
  }

  /// 🔥 Soft Delete Other Files
  Future<void> softDeleteOtherFiles(String id) async {
    await _updateNoteField(id, {
      'delete': true,
      'deletedDate': Timestamp.now(),
    });
  }

  /// 🔥 Update Title
  Future<void> updateTitleOtherFiles(String id, String newTitle) async {
    await _updateNoteField(id, {
      'tittle': newTitle,
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
  Future<void> softDeleteTimeTables({
    required String classNo,
    required String division,
    required String timetableName,
  }) async {
    await _firestore
        .schoolCollection(FirebaseConstant.timetable)
        .doc(classNo)
        .update({
      'divisions.$division.timetables.$timetableName.delete': true,
      'divisions.$division.timetables.$timetableName.deletedDate': Timestamp.now(),
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

class TimetableQueryParams {
  final String classNo;
  final String division;
  final String teacherId;

  const TimetableQueryParams({
    required this.classNo,
    required this.division,
    required this.teacherId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimetableQueryParams &&
          runtimeType == other.runtimeType &&
          classNo == other.classNo &&
          division == other.division &&
          teacherId == other.teacherId;

  @override
  int get hashCode => Object.hash(classNo, division, teacherId);
}

// StreamProvider for Timetables
final timetablesListProvider = StreamProvider.family<List<TimetableModel>, TimetableQueryParams>((ref, params) {
  final repo = ref.watch(timetableAndOtherFilesPageRepositoryProvider);
  return repo.getTimeTables(
      params.classNo,
      params.division,
      params.teacherId
  );
});