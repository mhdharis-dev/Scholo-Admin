import 'package:cloud_firestore/cloud_firestore.dart';
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
    };
  }

  // NOTE: It's usually best to pass the document ID separately when reading from Firestore
  factory TimetableModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TimetableModel(
      timetableName: map['timetableName'] ?? '',
      classTeacherName: map['classTeacherName'] ?? '',
      classTeacherId: map['classTeacherId'] ?? '',
      classNo: map['classNo'] ?? '',
      division: map['division'] ?? '',
      totalPeriods: map['totalPeriods'] ?? 0,
      totalWorkingDays: map['totalWorkingDays'] ?? 0,
      // FIX: Convert Firestore Timestamp back to Dart DateTime
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      delete: map['delete'] ?? false,
      deletedDate: map['deletedDate'] != null ? (map['deletedDate'] as Timestamp).toDate() : null,
      // FIX: Parse the raw Map from Firestore into a Map of DayScheduleModels
      workingDays: (map['workingDays'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, DayScheduleModel.fromMap(value)),
      ) ?? {},
    );
  }
}