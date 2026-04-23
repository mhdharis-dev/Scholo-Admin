import 'package:cloud_firestore/cloud_firestore.dart';

class StudentsModel {
  final int admissionNo;
  final int classNo;
  final int rollNo;

  final String mobileNo;
  final String studentName;
  final String division;
  final String teacherName;
  final String email;
  final String password;
  final String studentId;
  final String teacherId;
  final String imageUrl;
  final String parentName;
  final String address;
  final String gender;

  final bool delete;

  final DateTime createdDate;
  final DateTime dateOfBirth;

  // ✅ NEW FIELD
  final DateTime? deletedDate;

  const StudentsModel({
    required this.admissionNo,
    required this.mobileNo,
    required this.studentName,
    required this.classNo,
    required this.division,
    required this.teacherName,
    required this.email,
    required this.password,
    required this.rollNo,
    required this.studentId,
    required this.teacherId,
    required this.delete,
    required this.createdDate,
    required this.imageUrl,
    required this.address,
    required this.gender,
    required this.dateOfBirth,
    required this.parentName,
    this.deletedDate,
  });

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------
  StudentsModel copyWith({
    int? admissionNo,
    int? classNo,
    int? rollNo,
    String? mobileNo,
    String? studentName,
    String? division,
    String? teacherName,
    String? email,
    String? password,
    String? studentId,
    String? teacherId,
    String? imageUrl,
    String? parentName,
    String? address,
    String? gender,
    bool? delete,
    DateTime? createdDate,
    DateTime? dateOfBirth,
    DateTime? deletedDate,
  }) {
    return StudentsModel(
      admissionNo: admissionNo ?? this.admissionNo,
      mobileNo: mobileNo ?? this.mobileNo,
      studentName: studentName ?? this.studentName,
      classNo: classNo ?? this.classNo,
      division: division ?? this.division,
      teacherName: teacherName ?? this.teacherName,
      email: email ?? this.email,
      password: password ?? this.password,
      rollNo: rollNo ?? this.rollNo,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      delete: delete ?? this.delete,
      createdDate: createdDate ?? this.createdDate,
      imageUrl: imageUrl ?? this.imageUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      parentName: parentName ?? this.parentName,
      gender: gender ?? this.gender,
      deletedDate: deletedDate ?? this.deletedDate,
    );
  }

  // --------------------------------------------------
  // TO MAP (Firestore)
  // --------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'admissionNo': admissionNo,
      'mobileNo': mobileNo,
      'studentName': studentName,
      'classNo': classNo,
      'division': division,
      'teacherName': teacherName,
      'email': email,
      'password': password,
      'rollNo': rollNo,
      'studentId': studentId,
      'teacherId': teacherId,
      'delete': delete,

      'createdDate': Timestamp.fromDate(createdDate),

      'deletedDate': deletedDate == null
          ? null
          : Timestamp.fromDate(deletedDate!),

      'imageUrl': imageUrl,
      'gender': gender,
      'parentName': parentName,
      'address': address,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
    };
  }

  // --------------------------------------------------
  // FROM MAP (Firestore)
  // --------------------------------------------------
  factory StudentsModel.fromMap(Map<String, dynamic> map) {
    return StudentsModel(
      admissionNo: map['admissionNo'] ?? 0,
      mobileNo: map['mobileNo'] ?? '',
      studentName: map['studentName'] ?? '',
      classNo: map['classNo'] ?? 0,
      division: map['division'] ?? '',
      teacherName: map['teacherName'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      rollNo: map['rollNo'] ?? 0,
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      gender: map['gender'] ?? '',
      address: map['address'] ?? '',
      parentName: map['parentName'] ?? '',
      delete: map['delete'] ?? false,

      createdDate:
      (map['createdDate'] as Timestamp).toDate(),

      deletedDate: map['deletedDate'] != null
          ? (map['deletedDate'] as Timestamp).toDate()
          : null,

      dateOfBirth:
      (map['dateOfBirth'] as Timestamp).toDate(),
    );
  }
}