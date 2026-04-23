import 'package:cloud_firestore/cloud_firestore.dart';

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
    };
  }

  // --------------------------------------------------
  // FROM MAP
  // --------------------------------------------------
  factory OtherFilesModel.fromMap(Map<String, dynamic> map) {
    return OtherFilesModel(
      id: map['id'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      tittle: map['tittle'] ?? '',
      subtitle: map['subtitle'] ?? '',
      delete: map['delete'] ?? false,
      teacherId: map['teacherId'] ?? '',
      classNo: map['classNo'] ?? 0,
      division: map['division'] ?? '',

      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),

      deletedDate: map['deletedDate'] != null
          ? (map['deletedDate'] as Timestamp).toDate()
          : null,
    );
  }
}
