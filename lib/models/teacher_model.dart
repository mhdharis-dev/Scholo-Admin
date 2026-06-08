import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';

import 'otherTeacher_model.dart';

class TeacherModel {
  final int classNo;

  final String employeeId;
  final String mobileNo;
  final String teacherName;
  final String division;
  final String subject;
  final String email;
  final String password;
  final String id;
  final String address;
  final String gender;
  final String imageUrl;
  final String schoolId;

  final bool delete;

  final DateTime createdDate;
  final DateTime dateOfBirth;

  // ✅ NEW
  final DateTime? deletedDate;
  final List<OtherTeacherModel>? otherTeachers;

  const TeacherModel({
    required this.classNo,
    required this.employeeId,
    required this.mobileNo,
    required this.teacherName,
    required this.division,
    required this.subject,
    required this.email,
    required this.password,
    required this.id,
    required this.address,
    required this.gender,
    required this.imageUrl,
    required this.delete,
    required this.createdDate,
    required this.dateOfBirth,
    this.schoolId = '',

    this.otherTeachers,
    this.deletedDate,
  });

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------
  TeacherModel copyWith({
    int? classNo,
    String? employeeId,
    String? mobileNo,
    String? teacherName,
    String? division,
    String? subject,
    String? email,
    String? password,
    String? id,
    String? address,
    String? gender,
    String? imageUrl,
    String? schoolId,
    bool? delete,
    DateTime? createdDate,
    DateTime? dateOfBirth,
    DateTime? deletedDate,
    List<OtherTeacherModel>? otherTeachers,

  }) {
    return TeacherModel(
      classNo: classNo ?? this.classNo,
      employeeId: employeeId ?? this.employeeId,
      mobileNo: mobileNo ?? this.mobileNo,
      teacherName: teacherName ?? this.teacherName,
      division: division ?? this.division,
      subject: subject ?? this.subject,
      email: email ?? this.email,
      password: password ?? this.password,
      id: id ?? this.id,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      imageUrl: imageUrl ?? this.imageUrl,
      schoolId: schoolId ?? this.schoolId,
      delete: delete ?? this.delete,
      createdDate: createdDate ?? this.createdDate,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      deletedDate: deletedDate ?? this.deletedDate,
      otherTeachers: otherTeachers ?? this.otherTeachers,
    );
  }

  // --------------------------------------------------
  // TO MAP
  // --------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'classNo': classNo,
      'employeeId': employeeId,
      'mobileNo': mobileNo,
      'teacherName': teacherName,
      'division': division,
      'subject': subject,
      'email': email,
      'password': password,
      'id': id,
      'address': address,
      'gender': gender,
      'imageUrl': imageUrl,
      'delete': delete,
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,

      'createdDate': Timestamp.fromDate(createdDate),

      'deletedDate': deletedDate == null
          ? null
          : Timestamp.fromDate(deletedDate!),

      'dateOfBirth': Timestamp.fromDate(dateOfBirth),

      'otherTeachers': otherTeachers?.map((e) => e.toMap()).toList(),

    };
  }

  // --------------------------------------------------
  // FROM MAP
  // --------------------------------------------------
  factory TeacherModel.fromMap(Map<String, dynamic> map) {
    return TeacherModel(
      classNo: map['classNo'] ?? 0,
      employeeId: map['employeeId'] ?? '',
      mobileNo: map['mobileNo'] ?? '',
      teacherName: map['teacherName'] ?? '',
      division: map['division'] ?? '',
      subject: map['subject'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      id: map['id'] ?? '',
      address: map['address'] ?? '',
      gender: map['gender'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      delete: map['delete'] ?? false,
      schoolId: map['schoolId'] ?? '',

      createdDate: (map['createdDate'] as Timestamp).toDate(),

      deletedDate: map['deletedDate'] != null
          ? (map['deletedDate'] as Timestamp).toDate()
          : null,

      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),

      otherTeachers: map['otherTeachers'] != null
          ? List<OtherTeacherModel>.from(
        (map['otherTeachers'] as List)
            .map((e) => OtherTeacherModel.fromMap(e)),
      )
          : null,

    );
  }
}
