// fee_collection_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/fees_model.dart';

class FeeCollectionRepository {
  final FirebaseFirestore _firestore;

  FeeCollectionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream all fee entries for a teacher (flattened list with classNo & division)
  Stream<List<Map<String, dynamic>>> streamFeesByTeacher(String teacherId) {
    return _firestore.schoolCollection(FirebaseConstant.fees).snapshots().map((snap) {
      final List<Map<String, dynamic>> result = [];

      for (final doc in snap.docs) {
        final data = doc.data();
        data.forEach((classNo, classMap) {
          if (classMap is Map<String, dynamic>) {
            classMap.forEach((division, feeData) {
              if (feeData is Map<String, dynamic>) {
                if (feeData["teacherId"] == teacherId && feeData["delete"] == false) {
                  result.add({
                    "description": doc.id,
                    "classNo": classNo,
                    "division": division,
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

  /// Get a single fee document map by description (doc id)
  Future<Map<String, dynamic>?> getFeeDoc(String description) async {
    final doc = await _firestore.schoolCollection(FirebaseConstant.fees).doc(description).get();
    return doc.exists ? doc.data() : null;
  }

  /// Save fee using FeeModel (creates/merges into document)
  Future<void> saveFee(FeeModel fee) async {
    await _firestore
        .schoolCollection(FirebaseConstant.fees)
        .doc(fee.description)
        .set({
      fee.classNo.toString(): {
        fee.division: fee.toMap(),
      }
    }, SetOptions(merge: true));
  }

  /// Mark a specific student collected/uncollected inside the doc
  Future<void> updateStudentCollected({
    required String description,
    required String classNo,
    required String division,
    required int studentIndex,
    required bool collected,
    required int perStudentAmount,
  }) async {
    final docRef = _firestore.schoolCollection(FirebaseConstant.fees).doc(description);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final classMap = data[classNo];
    if (classMap == null) return;
    final Map<String, dynamic> feeMap = Map<String, dynamic>.from(classMap[division] ?? {});

    final List<dynamic> studentsRaw = List<dynamic>.from(feeMap["students"] ?? []);
    final students = studentsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    if (studentIndex < 0 || studentIndex >= students.length) return;

    students[studentIndex]["collected"] = collected;
    students[studentIndex]["status"] = collected ? "paid" : "unpaid";

    final collectedCount = students.where((s) => s["collected"] == true).length;
    final collectedAmount = collectedCount * perStudentAmount;
    final completed = collectedCount == students.length;

    // Prepare update map path
    final basePath = "$classNo.$division";
    await docRef.update({
      "$basePath.students": students,
      "$basePath.collectedCount": collectedCount,
      "$basePath.totalAmount": collectedAmount,
      "$basePath.completed": completed,
    });
  }

  /// Get all fee descriptions for suggestion list
  Future<List<String>> getFeeDescriptions() async {
    final snap = await _firestore.schoolCollection(FirebaseConstant.fees).get();
    return snap.docs.map((d) => d.id).toList();
  }

  /// Get fee map by description
  Future<Map<String, dynamic>?> getFeeByDescription(String description) async {
    final doc = await _firestore.schoolCollection(FirebaseConstant.fees).doc(description).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> setFeeCompleted({
    required String description,
    required int classNo,
    required String division,
    required bool completed,
  }) async {
    await _firestore
        .schoolCollection(FirebaseConstant.fees)
        .doc(description)
        .update({
      "$classNo.$division.completed": completed,
    });
  }

}
