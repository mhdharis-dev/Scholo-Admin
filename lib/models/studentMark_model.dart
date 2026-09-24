import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scholo_admin/models/subjectMark_model.dart';

class StudentMarkModel {
  final String studentName;
  final String studentId;
  final String markType;

  final bool delete;

  // ✅ nullable
  final DateTime? deletedAt;

  final int ceTotalMark;
  final int ceObtainedMark;

  /// 🔹 list of subject + mark
  final List<SubjectMarkModel> marks;

  const StudentMarkModel({
    required this.studentName,
    required this.studentId,
    required this.markType,
    required this.delete,
    this.deletedAt,
    this.ceTotalMark = 0,
    this.ceObtainedMark = 0,
    required this.marks,
  });

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------
  StudentMarkModel copyWith({
    String? studentName,
    String? markType,
    bool? delete,
    DateTime? deletedAt,
    String? studentId,
    int? ceTotalMark,
    int? ceObtainedMark,
    List<SubjectMarkModel>? marks,
  }) {
    return StudentMarkModel(
      studentName: studentName ?? this.studentName,
      delete: delete ?? this.delete,
      studentId: studentId ?? this.studentId,
      marks: marks ?? this.marks,
      markType: markType ?? this.markType,
      deletedAt: deletedAt ?? this.deletedAt,
      ceTotalMark: ceTotalMark ?? this.ceTotalMark,
      ceObtainedMark: ceObtainedMark ?? this.ceObtainedMark,
    );
  }

  // --------------------------------------------------
  // TO MAP (Firestore)
  // --------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'studentName': studentName,
      'studentId': studentId,
      'markType': markType,
      'delete': delete,

      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(deletedAt!),

      'ceTotal': ceTotalMark,
      'ceObtained': ceObtainedMark,

      'marks': marks.map((e) => e.toMap()).toList(),
    };
  }

  // --------------------------------------------------
  // FROM MAP (Firestore)
  // --------------------------------------------------
  factory StudentMarkModel.fromMap(Map<String, dynamic> map) {
    return StudentMarkModel(
      studentName: map['studentName'] ?? '',
      studentId: map['studentId'] ?? '',
      markType: map['markType'] ?? '',
      delete: map['delete'] ?? false,

      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,

      ceTotalMark: (map['ceTotal'] as num?)?.toInt() ?? (map['ceTotalMark'] as num?)?.toInt() ?? 0,
      ceObtainedMark: (map['ceObtained'] as num?)?.toInt() ?? (map['ceObtainedMark'] as num?)?.toInt() ?? 0,

      marks: (map['marks'] as List<dynamic>? ?? [])
          .map((e) => SubjectMarkModel.fromMap(e))
          .toList(),
    );
  }
}