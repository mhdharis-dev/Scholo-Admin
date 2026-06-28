import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';

class OtherFilesModel {
  final int classNo;

  final String id;
  final String fileName;
  final String fileUrl;
  final String tittle;
  final String subtitle;
  final String division;

  final DateTime uploadedAt;
  final DateTime? deletedDate;

  final bool delete;
  final String teacherId;
  final String schoolId;

  const OtherFilesModel({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.tittle,
    required this.subtitle,
    required this.uploadedAt,
    required this.delete,
    required this.teacherId,
    this.deletedDate,
    required this.classNo,
    required this.division,
    this.schoolId = '',
  });

  // --------------------------------------------------
  // COPY WITH
  // --------------------------------------------------
  OtherFilesModel copyWith({
    String? id,
    String? fileName,
    String? fileUrl,
    String? tittle,
    String? subtitle,
    DateTime? uploadedAt,
    bool? delete,
    String? teacherId,
    DateTime? deletedDate,
    int? classNo,
    String? division,
    String? schoolId,
  }) {
    return OtherFilesModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      tittle: tittle ?? this.tittle,
      subtitle: subtitle ?? this.subtitle,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      delete: delete ?? this.delete,
      teacherId: teacherId ?? this.teacherId,
      deletedDate: deletedDate ?? this.deletedDate,
      classNo: classNo ?? this.classNo,
      division: division ?? this.division,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  // --------------------------------------------------
  // TO MAP
  // --------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'tittle': tittle,
      'subtitle': subtitle,
      'classNo': classNo,
      'division': division,
      'uploadedAt': Timestamp.fromDate(uploadedAt),

      'delete': delete,

      'deletedDate': deletedDate == null
          ? null
          : Timestamp.fromDate(deletedDate!),

      'teacherId': teacherId,
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,
    };
  }

  // --------------------------------------------------
  // FROM MAP
  // --------------------------------------------------
  factory OtherFilesModel.fromMap(Map<String, dynamic> map) {
    int parsedClassNo = 0;
    if (map['classNo'] != null) {
      if (map['classNo'] is int) {
        parsedClassNo = map['classNo'];
      } else {
        parsedClassNo = int.tryParse(map['classNo'].toString()) ?? 0;
      }
    }

    DateTime uploadedDateTime;
    final uploadedAtVal = map['uploadedAt'];
    if (uploadedAtVal is Timestamp) {
      uploadedDateTime = uploadedAtVal.toDate();
    } else if (uploadedAtVal is String) {
      uploadedDateTime = DateTime.tryParse(uploadedAtVal) ?? DateTime.now();
    } else if (uploadedAtVal is int) {
      uploadedDateTime = DateTime.fromMillisecondsSinceEpoch(uploadedAtVal);
    } else {
      uploadedDateTime = DateTime.now();
    }

    DateTime? deletedDateTime;
    final deletedDateVal = map['deletedDate'];
    if (deletedDateVal is Timestamp) {
      deletedDateTime = deletedDateVal.toDate();
    } else if (deletedDateVal is String) {
      deletedDateTime = DateTime.tryParse(deletedDateVal);
    } else if (deletedDateVal is int) {
      deletedDateTime = DateTime.fromMillisecondsSinceEpoch(deletedDateVal);
    }

    return OtherFilesModel(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      tittle: map['tittle'] ?? map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      delete: map['delete'] ?? false,
      teacherId: map['teacherId'] ?? '',
      classNo: parsedClassNo,
      division: map['division'] ?? '',
      schoolId: map['schoolId'] ?? '',
      uploadedAt: uploadedDateTime,
      deletedDate: deletedDateTime,
    );
  }
}
