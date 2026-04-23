import 'package:cloud_firestore/cloud_firestore.dart';

class OtherTeacherModel {
  final String teacherName;
  final String teacherId;
  final String subject;
  final String imageUrl;

  final String employeeId;
  final int mobileNo;
  final bool isPermanent;
  final String? substitutedBy;
  final DateTime? substitutedDate;

  //<editor-fold desc="Data Methods">
  const OtherTeacherModel({
    required this.teacherName,
    required this.teacherId,
    required this.subject,
    required this.imageUrl,
    required this.employeeId,
    required this.mobileNo,
    required this.isPermanent,
    this.substitutedBy,
    this.substitutedDate,
  });

  OtherTeacherModel copyWith({
    String? teacherName,
    String? teacherId,
    String? subject,
    String? employeeId,
    String? imageUrl,
    int? mobileNo,
    bool? isPermanent,
    String? substitutedBy,
    DateTime? substitutedDate,
  }) {
    return OtherTeacherModel(
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      imageUrl: imageUrl ?? this.imageUrl,
      employeeId: employeeId ?? this.employeeId,
      mobileNo: mobileNo ?? this.mobileNo,
      isPermanent: isPermanent ?? this.isPermanent,
      substitutedBy: substitutedBy ?? this.substitutedBy,
      substitutedDate: substitutedDate ?? this.substitutedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherName': this.teacherName,
      'teacherId': this.teacherId,
      'subject': this.subject,
      'imageUrl': this.imageUrl,
      'employeeId': this.employeeId,
      'mobileNo': this.mobileNo,
      'isPermanent': this.isPermanent,
      'substitutedBy': this.substitutedBy,
      'substitutedDate': this.substitutedDate,
    };
  }

  factory OtherTeacherModel.fromMap(Map<String, dynamic> map) {
    return OtherTeacherModel(
      teacherName: map['teacherName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      subject: map['subject'] ?? '',
      employeeId: map['employeeId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      mobileNo: map['mobileNo'] ?? 0,

      // ✅ FIX HERE
      isPermanent: map['isPermanent'] ?? true,

      substitutedBy: map['substitutedBy'],
      substitutedDate: map['substitutedDate'] != null
          ? (map['substitutedDate'] as Timestamp).toDate()
          : null,
    );
  }
  //</editor-fold>
}