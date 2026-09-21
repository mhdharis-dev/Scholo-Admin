import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:scholo_admin/models/teacher_model.dart';
import '../../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../../core/constant/firebase_constant.dart';

class TeacherRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<TeacherModel>> getTeachers() {
    return _firestore
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => TeacherModel.fromMap(doc.data()))
        .toList());
  }

  Future<String> addTeacher(TeacherModel teacher) async {
    final docRef = teacher.id.isNotEmpty
        ? _firestore.schoolCollection(FirebaseConstant.teacher).doc(teacher.id)
        : _firestore.schoolCollection(FirebaseConstant.teacher).doc();
    final newTeacher = teacher.copyWith(id: docRef.id);
    await docRef.set(newTeacher.toMap());
    return docRef.id;
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    await _firestore.schoolCollection(FirebaseConstant.teacher).doc(teacher.id).update(teacher.toMap());
  }

  Future<void> deleteTeacher(String id) async {
    await _firestore.schoolCollection(FirebaseConstant.teacher).doc(id).update({'delete': true, "deletedAt": FieldValue.serverTimestamp(),});
  }

  Future<String> uploadImage(File file) async {
    final response = await CloudinaryService.teacherProfile.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: 'teacher_images',resourceType: CloudinaryResourceType.Auto,
      ),
    );
    return response.secureUrl;
  }
}
