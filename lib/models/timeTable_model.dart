import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';
import 'dayShedule_model.dart';

class TimetableModel {
  final String timetableName;
  final String classTeacherId;
  final String classTeacherName;
  final String classNo;
  final String division;
  final int totalPeriods;
  final int totalWorkingDays;
  final DateTime createdDate;
  final bool delete;
  final DateTime? deletedDate;
  final Map<String, DayScheduleModel> workingDays;
  final String schoolId;

  const TimetableModel({
    required this.timetableName,
    required this.classTeacherId,
    required this.classTeacherName,
    required this.classNo,
    required this.division,
    required this.totalPeriods,
    required this.totalWorkingDays,
    required this.createdDate,
    required this.delete,
    this.deletedDate,
    required this.workingDays,
    this.schoolId = '',
  });

  TimetableModel copyWith({
    String? timetableName,
    String? classTeacherId,
    String? classTeacherName,
    String? classNo,
    String? division,
    int? totalPeriods,
    int? totalWorkingDays,
    DateTime? createdDate,
    bool? delete,
    DateTime? deletedDate,
    Map<String, DayScheduleModel>? workingDays,
    String? schoolId,
  }) {
    return TimetableModel(
      timetableName: timetableName ?? this.timetableName,
      classTeacherId: classTeacherId ?? this.classTeacherId,
      classTeacherName: classTeacherName ?? this.classTeacherName,
      classNo: classNo ?? this.classNo,
      division: division ?? this.division,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      totalWorkingDays: totalWorkingDays ?? this.totalWorkingDays,
      createdDate: createdDate ?? this.createdDate,
      delete: delete ?? this.delete,
      deletedDate: deletedDate ?? this.deletedDate,
      workingDays: workingDays ?? this.workingDays,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timetableName': timetableName,
      'classTeacherId': classTeacherId,
      'classTeacherName': classTeacherName,
      'classNo': classNo,
      'division': division,
      'totalPeriods': totalPeriods,
      'totalWorkingDays': totalWorkingDays,
      // FIX: Convert DateTime to Firestore Timestamp
      'createdDate': Timestamp.fromDate(createdDate),
      'delete': delete,
      // FIX: Only convert if it's not null
      'deletedDate': deletedDate != null ? Timestamp.fromDate(deletedDate!) : null,
      // FIX: Convert the map of custom models into a map of JSON maps
      'workingDays': workingDays.map((key, value) => MapEntry(key, value.toMap())),
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,
    };
  }

  // NOTE: It's usually best to pass the document ID separately when reading from Firestore
  factory TimetableModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedCreatedDate;
    if (map['createdDate'] is Timestamp) {
      parsedCreatedDate = (map['createdDate'] as Timestamp).toDate();
    } else if (map['createdDate'] is DateTime) {
      parsedCreatedDate = map['createdDate'];
    } else if (map['createdDate'] is String) {
      parsedCreatedDate = DateTime.tryParse(map['createdDate']) ?? DateTime.now();
    } else if (map['createdDate'] is int) {
      parsedCreatedDate = DateTime.fromMillisecondsSinceEpoch(map['createdDate']);
    } else {
      parsedCreatedDate = DateTime.now();
    }

    DateTime? parsedDeletedDate;
    if (map['deletedDate'] is Timestamp) {
      parsedDeletedDate = (map['deletedDate'] as Timestamp).toDate();
    } else if (map['deletedDate'] is DateTime) {
      parsedDeletedDate = map['deletedDate'];
    } else if (map['deletedDate'] is String) {
      parsedDeletedDate = DateTime.tryParse(map['deletedDate']);
    } else if (map['deletedDate'] is int) {
      parsedDeletedDate = DateTime.fromMillisecondsSinceEpoch(map['deletedDate']);
    }

    return TimetableModel(
      timetableName: map['timetableName']?.toString() ?? '',
      classTeacherName: map['classTeacherName']?.toString() ?? '',
      classTeacherId: map['classTeacherId']?.toString() ?? '',
      classNo: map['classNo']?.toString() ?? documentId,
      division: map['division']?.toString() ?? '',
      totalPeriods: int.tryParse(map['totalPeriods']?.toString() ?? '0') ?? 0,
      totalWorkingDays: int.tryParse(map['totalWorkingDays']?.toString() ?? '0') ?? 0,
      createdDate: parsedCreatedDate,
      delete: map['delete'] == true,
      deletedDate: parsedDeletedDate,
      // FIX: Parse the raw Map from Firestore into a Map of DayScheduleModels
      workingDays: (map['workingDays'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key.toString(), DayScheduleModel.fromMap(Map<String, dynamic>.from(value))),
      ) ?? {},
      schoolId: map['schoolId']?.toString() ?? '',
    );
  }
}