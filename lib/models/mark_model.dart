import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';
import 'package:scholo_admin/models/studentMark_model.dart';

class MarkModel {
  final int classNo;

  final String examName;
  final String teacherName;
  final String teacherId;
  final String division;
  final String markType;
  final String schoolId;


  final DateTime uploadedAt;

  final bool delete;

  // ✅ ADDED
  final DateTime? deletedAt;

  final List<StudentMarkModel> studentsMark;

  const MarkModel({
    required this.classNo,
    required this.examName,
    required this.teacherName,
    required this.teacherId,
    required this.markType,
    required this.division,
    required this.uploadedAt,
    required this.delete,
    required this.studentsMark,
    this.schoolId = '',

    // ✅ ADDED
    this.deletedAt,
  });

  MarkModel copyWith({
    int? classNo,
    String? examName,
    String? teacherName,
    String? teacherId,
    String? division,
    String? markType,
    DateTime? uploadedAt,
    bool? delete,
    List<StudentMarkModel>? studentsMark,
    String? schoolId,

    // ✅ ADDED
    DateTime? deletedAt,
  }) {
    return MarkModel(
      classNo: classNo ?? this.classNo,
      examName: examName ?? this.examName,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      division: division ?? this.division,
      markType: markType ?? this.markType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      delete: delete ?? this.delete,
      studentsMark: studentsMark ?? this.studentsMark,
      schoolId: schoolId ?? this.schoolId,

      // ✅ ADDED
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classNo': classNo,
      'examName': examName,
      'teacherName': teacherName,
      'teacherId': teacherId,
      'division': division,
      'markType': markType,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'delete': delete,
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,

      // ✅ ADDED
      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(deletedAt!),

      "studentsMark": studentsMark.map((e) => e.toMap()).toList(),
    };
  }

  factory MarkModel.fromMap(Map<String, dynamic> map) {
    return MarkModel(
      classNo: map['classNo'] ?? 0,
      examName: map['examName'] ?? '',
      teacherName: map['teacherName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      division: map['division'] ?? '',
      markType: map['markType'] ?? '',
      schoolId: map['schoolId'] ?? '',

      uploadedAt: (map['uploadedAt'] is Timestamp)
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),

      delete: map['delete'] ?? false,

      // ✅ ADDED
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,

      studentsMark: (map['studentsMark'] as List<dynamic>? ?? [])
          .map((e) => StudentMarkModel.fromMap(e))
          .toList(),
    );
  }
}