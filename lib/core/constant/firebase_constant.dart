import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/session_manager.dart';

class FirebaseConstant {
  static const String teacher = 'teacher';
  static const String admin = 'admin';
  static const String student = 'students';
  static const String attendance = 'attendance';
  static const String timetable = 'timetable';
  static const String notes = 'notes';
  static const String studentsMark = 'studentsMark';
  static const String fees = 'fees';
  static const String events = 'events';
  static const String classes = "Classes";
  static const String draftTimetable = "draft-timetable";
  static const String helpAndSupport = "help&support";
  static const String notifications = "notifications";
}

extension SchoolFirestoreExtension on FirebaseFirestore {
  CollectionReference<Map<String, dynamic>> schoolCollection(String collectionPath) {
    final schoolId = SessionManager.schoolId;
    if (schoolId.isEmpty) {
      throw Exception('School ID not initialized');
    }
    return collection('schools')
        .doc(schoolId)
        .collection(collectionPath);
  }
}
