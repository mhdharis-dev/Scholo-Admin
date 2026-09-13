import 'package:cloud_firestore/cloud_firestore.dart';

class OtherTeacherModel {
  final String teacherName;
  final String teacherId;
  final String subject;
  final String imageUrl;
  final String email;

  final String employeeId;
  final int mobileNo;

  final bool isPermanent;
  final String? substitutedBy;
  final String? substitutedId;
  final String? substitutedImageUrl;
  final int? substitutedMobileNo;
  final DateTime? substitutedDate;
  final bool isLanguageTeacher;

  //<editor-fold desc="Data Methods">
  const OtherTeacherModel({
    required this.teacherName,
    required this.teacherId,
    required this.subject,
    required this.imageUrl,
    required this.employeeId,
    required this.mobileNo,
    required this.isPermanent,
    this.isLanguageTeacher = false,
    this.substitutedBy,
    this.substitutedDate,
    this.substitutedId,
    this.substitutedImageUrl,
    this.substitutedMobileNo,
    required this.email,
  });

  OtherTeacherModel copyWith({
    String? teacherName,
    String? teacherId,
    String? subject,
    String? employeeId,
    String? imageUrl,
    int? mobileNo,
    bool? isPermanent,
    bool? isLanguageTeacher,
    String? substitutedBy,
    DateTime? substitutedDate,
    String? substitutedId,
    String? substitutedImageUrl,
    int? substitutedMobileNo,
    String? email,
  }) {
    return OtherTeacherModel(
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      imageUrl: imageUrl ?? this.imageUrl,
      employeeId: employeeId ?? this.employeeId,
      mobileNo: mobileNo ?? this.mobileNo,
      isPermanent: isPermanent ?? this.isPermanent,
      isLanguageTeacher: isLanguageTeacher ?? this.isLanguageTeacher,
      substitutedBy: substitutedBy ?? this.substitutedBy,
      substitutedDate: substitutedDate ?? this.substitutedDate,
      substitutedId: substitutedId ?? this.substitutedId,
      substitutedImageUrl: substitutedImageUrl ?? this.substitutedImageUrl,
      substitutedMobileNo: substitutedMobileNo ?? this.substitutedMobileNo,
      email: email ?? this.email,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherName': teacherName,
      'teacherId': teacherId,
      'subject': subject,
      'imageUrl': imageUrl,
      'employeeId': employeeId,
      'mobileNo': mobileNo,
      'isPermanent': isPermanent,
      'isLanguageTeacher': isLanguageTeacher,
      'substitutedBy': substitutedBy,
      'substitutedDate': substitutedDate,
      'substitutedId': substitutedId,
      'substitutedImageUrl': substitutedImageUrl,
      'substitutedMobileNo': substitutedMobileNo,
      'email': email,
    };
  }

  factory OtherTeacherModel.fromMap(Map<String, dynamic> map) {
    return OtherTeacherModel(
      teacherName: map['teacherName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      email: map['email'] ?? '',
      employeeId: map['employeeId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      mobileNo: map['mobileNo'] ?? 0,

      // ✅ FIX HERE
      isPermanent: map['isPermanent'] ?? true,
      isLanguageTeacher: map['isLanguageTeacher'] ?? false,

      substitutedBy: map['substitutedBy'],
      substitutedDate: map['substitutedDate'] != null
          ? (map['substitutedDate'] as Timestamp).toDate()
          : null,
      substitutedId: map['substitutedId'],
      substitutedImageUrl: map['substitutedImageUrl'],
      substitutedMobileNo: map['substitutedMobileNo'],
    );
  }
//</editor-fold>
}