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

  /// 🔹 Validate duplicate student records before adding or updating
  Future<void> validateNoDuplicateStudent(StudentsModel student, {required bool isUpdate}) async {
    final snapshot = await _firestore
        .schoolCollection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .get();

    final inputAdmissionNo = student.admissionNo;
    final inputStudentId = student.studentId.trim().toLowerCase();
    final inputEmail = student.email.trim().toLowerCase();
    final inputMobile = student.mobileNo.replaceAll(RegExp(r'\D'), '');
    final inputClassNo = student.classNo;
    final inputDivision = student.division.trim().toLowerCase();
    final inputRollNo = student.rollNo;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingStudentId = doc.id.trim().toLowerCase();
      final existingIdField = (data['studentId'] ?? doc.id).toString().trim().toLowerCase();

      if (isUpdate) {
        if (inputStudentId.isNotEmpty && (existingStudentId == inputStudentId || existingIdField == inputStudentId)) {
          continue; // Skip current student being updated
        }
      }

      final existingAdmissionNo = data['admissionNo'] is int
          ? data['admissionNo'] as int
          : int.tryParse(data['admissionNo']?.toString() ?? '') ?? 0;
      final existingEmail = (data['email'] ?? '').toString().trim().toLowerCase();
      final existingMobile = (data['mobileNo'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      final existingClassNo = data['classNo'] is int
          ? data['classNo'] as int
          : int.tryParse(data['classNo']?.toString() ?? '') ?? 0;
      final existingDivision = (data['division'] ?? '').toString().trim().toLowerCase();
      final existingRollNo = data['rollNo'] is int
          ? data['rollNo'] as int
          : int.tryParse(data['rollNo']?.toString() ?? '') ?? 0;
      final existingName = data['studentName'] ?? 'Existing Student';

      if (inputAdmissionNo != 0 && existingAdmissionNo == inputAdmissionNo) {
        throw 'Admission No. "#$inputAdmissionNo" is already assigned to $existingName.';
      }
      if (inputEmail.isNotEmpty && existingEmail == inputEmail) {
        throw 'Email address "${student.email}" is already registered to $existingName.';
      }
      if (inputMobile.isNotEmpty && existingMobile == inputMobile) {
        throw 'Mobile number "${student.mobileNo}" is already registered to $existingName.';
      }
      if (inputRollNo != 0 &&
          existingClassNo == inputClassNo &&
          existingDivision == inputDivision &&
          existingRollNo == inputRollNo) {
        final classStr = _classNoToString(inputClassNo);
        final divStr = student.division.toUpperCase();
        throw 'Roll No. $inputRollNo in Class $classStr-$divStr is already assigned to $existingName.';
      }
    }
  }

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  /// 🔹 Save or Update Student
  Future<void> saveStudent(StudentsModel model) async {
    await validateNoDuplicateStudent(model, isUpdate: model.studentId.isNotEmpty);
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
