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

  Stream<List<QueryDocumentSnapshot>> getFirebaseExams(String teacherId) {
    return _firestore
        .collection(FirebaseConstant.studentsMark)
        .where("teacherId", isEqualTo: teacherId)
        .where("delete", isEqualTo: false)
        .orderBy("uploadedAt", descending: true) // ✅ added
        .snapshots()
        .map((e) => e.docs);
  }

  Future<void> softDeleteExam(String docId) async {
    await _firestore
        .collection(FirebaseConstant.studentsMark)
        .doc(docId)
        .update({
      "delete": true,
      "deletedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> getExamNamesOnce(String teacherId) async {
    final snap = await _firestore
        .collection(FirebaseConstant.studentsMark)
        .where("teacherId", isEqualTo: teacherId)
        .where("delete", isEqualTo: false)
        .orderBy("uploadedAt", descending: true) // ✅ added
        .get();

    return snap.docs.map((e) => e.id).toList();
  }}
