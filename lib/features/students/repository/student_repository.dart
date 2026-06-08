import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:scholo_admin/models/students_model.dart';
import '../../../../core/cloudinaryServies/cloudinary_service.dart';

class StudentRepository {
  final _firestore = FirebaseFirestore.instance;

  /// 🔹 Stream all students (excluding deleted)
  Stream<List<StudentsModel>> streamStudents() {
    return _firestore
        .schoolCollection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => StudentsModel.fromMap(doc.data()))
        .toList());
  }

  /// 🔹 Fetch all teachers for dropdown
  Future<List<Map<String, dynamic>>> fetchTeachers() async {
    final snapshot = await _firestore
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['teacherName']})
        .toList();
  }

  /// 🔹 Upload student image to Cloudinary
  Future<String> uploadStudentImage(File file) async {
    final response = await CloudinaryService.studentProfile.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: 'student_images'),
    );
    return response.secureUrl;
  }

  /// 🔹 Save or Update Student
  Future<void> saveStudent(StudentsModel model) async {
    final ref = _firestore.schoolCollection(FirebaseConstant.student);

    if (model.studentId.isEmpty) {
      final doc = await ref.add(model.toMap());
      await doc.update({'studentId': doc.id});
    } else {
      await ref.doc(model.studentId).update(model.toMap());
    }
  }

  /// 🔹 Soft Delete
  Future<void> deleteStudent(String id) async {
    await _firestore
        .schoolCollection(FirebaseConstant.student)
        .doc(id)
        .update({'delete': true, "deletedAt": FieldValue.serverTimestamp(),});
  }
}
