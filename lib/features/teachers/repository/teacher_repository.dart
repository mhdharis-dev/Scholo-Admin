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

  Future<void> _validateNoDuplicateTeacher(TeacherModel teacher, {required bool isUpdate}) async {
    final snapshot = await _firestore
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    final inputEmpId = teacher.employeeId.trim().toLowerCase();
    final inputDocId = teacher.id.trim().toLowerCase();
    final inputEmail = teacher.email.trim().toLowerCase();
    final inputMobile = teacher.mobileNo.replaceAll(RegExp(r'\D'), '');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingDocId = doc.id.trim().toLowerCase();
      final existingEmpId = (data['employeeId'] ?? doc.id).toString().trim().toLowerCase();

      if (isUpdate) {
        if (inputDocId.isNotEmpty && (existingDocId == inputDocId || existingEmpId == inputEmpId)) {
          continue; // Skip current teacher being updated
        }
      }

      final existingEmail = (data['email'] ?? '').toString().trim().toLowerCase();
      final existingMobile = (data['mobileNo'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      final existingName = data['teacherName'] ?? 'Existing Teacher';

      if (inputEmpId.isNotEmpty && (existingEmpId == inputEmpId || existingDocId == inputEmpId)) {
        throw 'Teacher ID "${teacher.employeeId}" is already assigned to $existingName.';
      }
      if (inputEmail.isNotEmpty && existingEmail == inputEmail) {
        throw 'Email address "${teacher.email}" is already registered to $existingName.';
      }
      if (inputMobile.isNotEmpty && existingMobile == inputMobile) {
        throw 'Mobile number "${teacher.mobileNo}" is already registered to $existingName.';
      }
    }
  }

  Future<String> addTeacher(TeacherModel teacher) async {
    await _validateNoDuplicateTeacher(teacher, isUpdate: false);
    final docRef = teacher.id.isNotEmpty
        ? _firestore.schoolCollection(FirebaseConstant.teacher).doc(teacher.id)
        : _firestore.schoolCollection(FirebaseConstant.teacher).doc();
    final newTeacher = teacher.copyWith(id: docRef.id);
    await docRef.set(newTeacher.toMap());
    return docRef.id;
  }

  Future<void> updateTeacher(TeacherModel teacher) async {
    await _validateNoDuplicateTeacher(teacher, isUpdate: true);
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
