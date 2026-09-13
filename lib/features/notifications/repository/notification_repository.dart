import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:scholo_admin/core/config/session_manager.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:scholo_admin/models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<NotificationModel>> streamNotifications() {
    return _firestore
        .schoolCollection(FirebaseConstant.notifications)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Auto-generates sequential ID format "notification@001", "notification@002"
  Future<String> _generateSequentialNotificationId() async {
    final collectionRef = _firestore.schoolCollection(FirebaseConstant.notifications);
    final snapshot = await collectionRef.get();

    int count = snapshot.docs.length + 1;
    String candidateId = "notification@${count.toString().padLeft(3, '0')}";

    while ((await collectionRef.doc(candidateId).get()).exists) {
      count++;
      candidateId = "notification@${count.toString().padLeft(3, '0')}";
    }

    return candidateId;
  }

  /// Comprehensive Audience-based FCM Token Harvesting Algorithm
  Future<List<String>> _harvestTargetFcmTokens(NotificationModel notification) async {
    final Set<String> tokensSet = {};
    final String schoolId = SessionManager.schoolId;

    if (schoolId.isEmpty) return ["not shared"];

    final schoolRef = _firestore.collection('schools').doc(schoolId);

    // Helper: Collect tokens from teacher documents
    Future<void> collectTeacherTokens(List<DocumentSnapshot> teacherDocs) async {
      for (final teacherDoc in teacherDocs) {
        try {
          final devicesSnap = await teacherDoc.reference
              .collection('devices')
              .where('isActive', isEqualTo: true)
              .get();

          for (final deviceDoc in devicesSnap.docs) {
            final token = deviceDoc.data()['fcmToken'];
            if (token != null && token.toString().trim().isNotEmpty) {
              tokensSet.add(token.toString().trim());
            }
          }
        } catch (_) {}
      }
    }

    // Helper: Collect tokens from student/parent documents
    Future<void> collectStudentTokens(List<DocumentSnapshot> studentDocs) async {
      for (final studentDoc in studentDocs) {
        try {
          final devicesSnap = await studentDoc.reference
              .collection('devices')
              .where('isActive', isEqualTo: true)
              .get();

          for (final deviceDoc in devicesSnap.docs) {
            final token = deviceDoc.data()['fcmToken'];
            if (token != null && token.toString().trim().isNotEmpty) {
              tokensSet.add(token.toString().trim());
            }
          }
        } catch (_) {}
      }
    }

    final mode = notification.audienceType;

    try {
      // 1. SELECT ALL SCHOOL (All Teachers + All Students/Parents)
      if (mode == 'All School') {
        final teachersSnap = await schoolRef.collection('teachers').where('delete', isEqualTo: false).get();
        final studentsSnap = await schoolRef.collection('students').where('delete', isEqualTo: false).get();

        await collectTeacherTokens(teachersSnap.docs);
        await collectStudentTokens(studentsSnap.docs);
      }

      // 2. SELECT ALL TEACHERS
      if (mode == 'All Teachers' || notification.targetAudienceLabels.contains('All Teachers')) {
        final teachersSnap = await schoolRef.collection('teachers').where('delete', isEqualTo: false).get();
        await collectTeacherTokens(teachersSnap.docs);
      }

      // 3. SELECT ALL STUDENTS / ALL PARENTS
      if (mode == 'All Students' || mode == 'All Parents' || notification.targetAudienceLabels.contains('All Students') || notification.targetAudienceLabels.contains('All Parents')) {
        final studentsSnap = await schoolRef.collection('students').where('delete', isEqualTo: false).get();
        await collectStudentTokens(studentsSnap.docs);
      }

      // 4. SELECT SPECIFIC CLASS (Specific Class Teachers + Class Students)
      if (mode == 'Specific Class' || notification.targetClass.isNotEmpty) {
        final targetClass = notification.targetClass;
        if (targetClass.isNotEmpty) {
          // Class Students
          final studentsSnap = await schoolRef.collection('students').where('delete', isEqualTo: false).get();
          final matchingStudents = studentsSnap.docs.where((doc) {
            final data = doc.data();
            final classNo = (data['classNo'] ?? '').toString();
            final div = (data['division'] ?? '').toString();
            final fullClass = "$classNo$div";
            return fullClass.toLowerCase() == targetClass.toLowerCase() || classNo.toLowerCase() == targetClass.toLowerCase();
          }).toList();

          await collectStudentTokens(matchingStudents);

          // Class Teachers
          final teachersSnap = await schoolRef.collection('teachers').where('delete', isEqualTo: false).get();
          final matchingTeachers = teachersSnap.docs.where((doc) {
            final data = doc.data();
            final teacherClass = (data['classTeacher'] ?? data['classNo'] ?? '').toString();
            return teacherClass.toLowerCase().contains(targetClass.toLowerCase());
          }).toList();

          await collectTeacherTokens(matchingTeachers);
        }
      }

      // 5. SELECT SPECIFIC TEACHERS
      if (mode == 'Specific Teacher(s)' || notification.targetTeacherIds.isNotEmpty) {
        for (final teacherId in notification.targetTeacherIds) {
          final doc = await schoolRef.collection('teachers').doc(teacherId).get();
          if (doc.exists) {
            await collectTeacherTokens([doc]);
          }
        }
      }

      // 6. SELECT SPECIFIC STUDENTS
      if (mode == 'Specific Student(s)' || notification.targetStudentIds.isNotEmpty) {
        for (final studentId in notification.targetStudentIds) {
          final doc = await schoolRef.collection('students').doc(studentId).get();
          if (doc.exists) {
            await collectStudentTokens([doc]);
          }
        }
      }
    } catch (e) {
      debugPrint('Error harvesting FCM tokens: $e');
    }

    final resultList = tokensSet.toList();
    if (resultList.isEmpty) {
      return ["not shared"];
    }

    return resultList;
  }

  Future<void> sendNotification(NotificationModel notification) async {
    final String generatedId = notification.id.isNotEmpty && notification.id.startsWith('notification@')
        ? notification.id
        : await _generateSequentialNotificationId();

    final harvestedTokens = await _harvestTargetFcmTokens(notification);

    final finalNotification = notification.copyWith(
      id: generatedId,
      targetFcmTokens: harvestedTokens,
    );

    await _firestore
        .schoolCollection(FirebaseConstant.notifications)
        .doc(generatedId)
        .set(finalNotification.toMap());
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .schoolCollection(FirebaseConstant.notifications)
        .doc(notificationId)
        .delete();
  }

  Future<void> updateNotification(NotificationModel notification) async {
    final harvestedTokens = await _harvestTargetFcmTokens(notification);
    final updated = notification.copyWith(targetFcmTokens: harvestedTokens);

    await _firestore
        .schoolCollection(FirebaseConstant.notifications)
        .doc(notification.id)
        .update(updated.toMap());
  }
}
