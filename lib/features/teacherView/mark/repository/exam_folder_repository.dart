import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constant/firebase_constant.dart';

class ExamFolderRepository {
  final FirebaseFirestore _firestore;

  ExamFolderRepository(this._firestore);

  /// ================================
  /// 🔹 TEMP EXAMS (SharedPrefs)
  /// ================================

  String _tempKey(String teacherId) => "temp_exam_$teacherId";

  Future<List<String>> loadTempExams(String teacherId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_tempKey(teacherId)) ?? [];
  }

  Future<void> addTempExam(String teacherId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_tempKey(teacherId)) ?? [];

    if (!current.contains(name)) {
      current.add(name);
      await prefs.setStringList(_tempKey(teacherId), current);
    }
  }

  Future<void> removeTempExam(String teacherId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_tempKey(teacherId)) ?? [];

    current.remove(name);
    await prefs.setStringList(_tempKey(teacherId), current);
  }

  /// ================================
  /// 🔹 FIREBASE EXAMS
  /// ================================

  Stream<List<QueryDocumentSnapshot>> getFirebaseExams() {
    return _firestore
        .schoolCollection(FirebaseConstant.studentsMark)
        .snapshots()
        .map((e) => e.docs);
  }

  Future<void> softDeleteExam({
    required String examName,
    required String classNo,
    required String division,
  }) async {
    final docRef = _firestore
        .schoolCollection(FirebaseConstant.studentsMark)
        .doc(examName);

    final docSnap = await docRef.get();
    String targetClassKey = classNo;
    String targetDivKey = division;

    if (docSnap.exists) {
      final docData = docSnap.data();
      if (docData != null) {
        final matchedClassKey = docData.keys.firstWhere(
          (k) => k.trim() == targetClassKey,
          orElse: () => '',
        );
        if (matchedClassKey.isNotEmpty) {
          targetClassKey = matchedClassKey;
          final classMap = docData[targetClassKey];
          if (classMap is Map<String, dynamic>) {
            final matchedDivKey = classMap.keys.firstWhere(
              (k) => k.trim().toLowerCase() == targetDivKey.trim().toLowerCase(),
              orElse: () => '',
            );
            if (matchedDivKey.isNotEmpty) {
              targetDivKey = matchedDivKey;
            }
          }
        }
      }
    }

    await docRef.update({
      "$targetClassKey.$targetDivKey.delete": true,
      "$targetClassKey.$targetDivKey.deletedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> getExamNamesOnce() async {
    final snap = await _firestore
        .schoolCollection(FirebaseConstant.studentsMark)
        .get();

    return snap.docs.map((e) => e.id).toList();
  }}
