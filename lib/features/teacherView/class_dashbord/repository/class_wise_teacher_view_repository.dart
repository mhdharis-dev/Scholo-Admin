// lib/features/teacherView/class_dashbord/repository/classwiseteacherview_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/class_model.dart';

class ClassWiseTeacherViewRepository {
  final FirebaseFirestore _db;

  ClassWiseTeacherViewRepository([FirebaseFirestore? firestore])
      : _db = firestore ?? FirebaseFirestore.instance;

  /// 🔹 Get all teachers
  /// 🔥 Real-time stream of all teachers
  Stream<List<TeacherModel>> watchAllTeachers() {
    return _db
        .schoolCollection(FirebaseConstant.teacher)
        .where("delete", isEqualTo: false)
        .orderBy("classNo")
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => TeacherModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// 🔹 Get teacher by id
  Future<TeacherModel?> getTeacher(String teacherId) async {
    final doc = await _db
        .schoolCollection(FirebaseConstant.teacher)
        .doc(teacherId)
        .get();

    if (!doc.exists) return null;
    return TeacherModel.fromMap(doc.data()!);
  }

  /// 🔹 Get all classes
  Stream<List<ClassModel>> watchAllClasses() {
    return _db
        .schoolCollection(FirebaseConstant.classes)
        .where("delete", isEqualTo: false)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => ClassModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// 🔹 Add class
  Future<void> addClass(ClassModel classModel) async {
    final name = classModel.className.isEmpty ? "Class ${classModel.classNo}" : classModel.className;
    final docId = "$name - ${classModel.division}";
    final docRef = _db
        .schoolCollection(FirebaseConstant.classes)
        .doc(docId);
    await docRef.set(classModel.copyWith(classId: docId, className: name).toMap());
  }

  /// 🔹 Update class
  Future<void> updateClass(ClassModel classModel) async {
    if (classModel.classId == null) return;
    
    final name = classModel.className.isEmpty ? "Class ${classModel.classNo}" : classModel.className;
    final newDocId = "$name - ${classModel.division}";
    
    if (classModel.classId != newDocId) {
      final newDocRef = _db.schoolCollection(FirebaseConstant.classes).doc(newDocId);
      await newDocRef.set(classModel.copyWith(classId: newDocId, className: name).toMap());
      await _db.schoolCollection(FirebaseConstant.classes).doc(classModel.classId).delete();
    } else {
      await _db
          .schoolCollection(FirebaseConstant.classes)
          .doc(classModel.classId)
          .update(classModel.toMap());
    }
  }

  /// 🔹 Delete class (Soft delete)
  Future<void> deleteClass(String classId) async {
    await _db
        .schoolCollection(FirebaseConstant.classes)
        .doc(classId)
        .update({'delete': true});
  }

  /// 🔹 Sync student details to Classes collection
  Future<void> syncStudentToClass({
    String? oldClassNo,
    String? oldDivision,
    String? newClassNo,
    String? newDivision,
    required String studentId,
    required String studentName,
    required String imageUrl,
    required int rollNo,
    bool isDeleted = false,
  }) async {
    // 1. Remove from old class if class/division changed or deleted
    if (isDeleted || (oldClassNo != null && oldDivision != null && (oldClassNo != newClassNo || oldDivision != newDivision))) {
      final oldClassSnap = await _db
          .schoolCollection(FirebaseConstant.classes)
          .where('classNo', isEqualTo: oldClassNo)
          .where('division', isEqualTo: oldDivision)
          .where('delete', isEqualTo: false)
          .limit(1)
          .get();
      
      if (oldClassSnap.docs.isNotEmpty) {
        final oldClassRef = oldClassSnap.docs.first.reference;
        await _db.runTransaction((transaction) async {
          final doc = await transaction.get(oldClassRef);
          if (doc.exists) {
            final data = doc.data()!;
            final studentsMap = Map<String, dynamic>.from(data['students'] ?? {});
            if (studentsMap.containsKey(studentId)) {
              studentsMap.remove(studentId);
              final newTotal = studentsMap.length;
              transaction.update(oldClassRef, {
                'students': studentsMap,
                'totalStudents': newTotal,
              });
            }
          }
        });
      }
    }

    // 2. Add/Update in new class if not deleted
    if (!isDeleted && newClassNo != null && newDivision != null && newClassNo.isNotEmpty && newDivision.isNotEmpty && newDivision != 'Nil' && newDivision != 'Not') {
      final newClassSnap = await _db
          .schoolCollection(FirebaseConstant.classes)
          .where('classNo', isEqualTo: newClassNo)
          .where('division', isEqualTo: newDivision)
          .where('delete', isEqualTo: false)
          .limit(1)
          .get();

      DocumentReference<Map<String, dynamic>> newClassRef;
      String currentClassName = 'Class $newClassNo';

      if (newClassSnap.docs.isNotEmpty) {
        newClassRef = newClassSnap.docs.first.reference;
        currentClassName = newClassSnap.docs.first.data()['className'] ?? 'Class $newClassNo';
      } else {
        final newClassDocId = "$currentClassName - $newDivision";
        newClassRef = _db.schoolCollection(FirebaseConstant.classes).doc(newClassDocId);
      }

      await _db.runTransaction((transaction) async {
        final doc = await transaction.get(newClassRef);
        final Map<String, dynamic> studentData = {
          'studentId': studentId,
          'studentName': studentName,
          'imageUrl': imageUrl,
          'rollNo': rollNo,
        };

        if (doc.exists) {
          final data = doc.data()!;
          final studentsMap = Map<String, dynamic>.from(data['students'] ?? {});
          studentsMap[studentId] = studentData;
          final newTotal = studentsMap.length;
          transaction.update(newClassRef, {
            'students': studentsMap,
            'totalStudents': newTotal,
          });
        } else {
          transaction.set(newClassRef, {
            'classNo': newClassNo,
            'division': newDivision,
            'className': currentClassName,
            'schoolId': '',
            'delete': false,
            'create': Timestamp.now(),
            'teacherName': '',
            'teacherId': '',
            'totalStudents': 1,
            'students': {studentId: studentData},
          });
        }
      });
    }
  }

  int _classNoToInt(String classNoStr) {
    if (classNoStr == 'LKG') return -2;
    if (classNoStr == 'UKG') return -1;
    return int.tryParse(classNoStr) ?? 0;
  }

  /// 🔹 Sync teacher details to Classes collection and update all student documents in that class
  Future<void> syncTeacherToClass({
    String? oldClassNo,
    String? oldDivision,
    String? newClassNo,
    String? newDivision,
    required String teacherId,
    required String teacherName,
  }) async {
    // 1. Clear old class teacher assignment
    if (oldClassNo != null && oldDivision != null && (oldClassNo != newClassNo || oldDivision != newDivision)) {
      final oldClassSnap = await _db
          .schoolCollection(FirebaseConstant.classes)
          .where('classNo', isEqualTo: oldClassNo)
          .where('division', isEqualTo: oldDivision)
          .where('delete', isEqualTo: false)
          .limit(1)
          .get();

      if (oldClassSnap.docs.isNotEmpty) {
        await oldClassSnap.docs.first.reference.update({
          'teacherId': '',
          'teacherName': '',
        });
      }

      // Clear old class students' teacher details
      final oldClassNoInt = _classNoToInt(oldClassNo);
      final oldStudentsSnap = await _db
          .schoolCollection(FirebaseConstant.student)
          .where('classNo', isEqualTo: oldClassNoInt)
          .where('division', isEqualTo: oldDivision)
          .where('delete', isEqualTo: false)
          .get();

      if (oldStudentsSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in oldStudentsSnap.docs) {
          batch.update(doc.reference, {
            'teacherId': '',
            'teacherName': '',
          });
        }
        await batch.commit();
      }
    }

    // 2. Set new class teacher assignment
    if (newClassNo != null && newDivision != null && newClassNo.isNotEmpty && newDivision.isNotEmpty && newDivision != 'Nil') {
      final newClassSnap = await _db
          .schoolCollection(FirebaseConstant.classes)
          .where('classNo', isEqualTo: newClassNo)
          .where('division', isEqualTo: newDivision)
          .where('delete', isEqualTo: false)
          .limit(1)
          .get();

      if (newClassSnap.docs.isNotEmpty) {
        await newClassSnap.docs.first.reference.update({
          'teacherId': teacherId,
          'teacherName': teacherName,
        });
      } else {
        final newClassName = "Class $newClassNo";
        final newDocId = "$newClassName - $newDivision";
        final ref = _db.schoolCollection(FirebaseConstant.classes).doc(newDocId);
        await ref.set({
          'classNo': newClassNo,
          'division': newDivision,
          'className': newClassName,
          'schoolId': '',
          'delete': false,
          'create': Timestamp.now(),
          'teacherName': teacherName,
          'teacherId': teacherId,
          'totalStudents': 0,
          'students': {},
        });
      }

      // Update new class students' teacher details
      final newClassNoInt = _classNoToInt(newClassNo);
      final newStudentsSnap = await _db
          .schoolCollection(FirebaseConstant.student)
          .where('classNo', isEqualTo: newClassNoInt)
          .where('division', isEqualTo: newDivision)
          .where('delete', isEqualTo: false)
          .get();

      if (newStudentsSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (var doc in newStudentsSnap.docs) {
          batch.update(doc.reference, {
            'teacherId': teacherId,
            'teacherName': teacherName,
          });
        }
        await batch.commit();
      }
    }
  }
}
