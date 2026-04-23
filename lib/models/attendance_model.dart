import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final int classNo;
  final int rollNo;

  final String studentId;
  final String division;
  final String studentName;
  final String teacherName;
  final String status;
  final String presentDetail;
  final String teacherId;

  final DateTime date;

  //<editor-fold desc="Data Methods">
  const AttendanceModel({
    required this.classNo,
    required this.rollNo,
    required this.studentId,
    required this.division,
    required this.studentName,
    required this.teacherName,
    required this.status,
    required this.presentDetail,
    required this.teacherId,
    required this.date,
  });

  AttendanceModel copyWith({
    int? classNo,
    int? rollNo,
    String? studentId,
    String? division,
    String? studentName,
    String? teacherName,
    String? status,
    String? presentDetail,
    String? teacherId,
    DateTime? date,
  }) {
    return AttendanceModel(
      classNo: classNo ?? this.classNo,
      rollNo: rollNo ?? this.rollNo,
      studentId: studentId ?? this.studentId,
      division: division ?? this.division,
      studentName: studentName ?? this.studentName,
      teacherName: teacherName ?? this.teacherName,
      status: status ?? this.status,
      presentDetail: presentDetail ?? this.presentDetail,
      teacherId: teacherId ?? this.teacherId,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classNo': this.classNo,
      'rollNo': this.rollNo,
      'studentId': this.studentId,
      'division': this.division,
      'studentName': this.studentName,
      'teacherName': this.teacherName,
      'status': this.status,
      'presentDetail': this.presentDetail,
      'teacherId': this.teacherId,
      'date': this.date,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      classNo: map['classNo'] as int,
      rollNo: map['rollNo'] as int,
      studentId: map['studentId'] as String,
      division: map['division'] as String,
      studentName: map['studentName'] as String,
      teacherName: map['teacherName'] as String,
      status: map['status'] as String,
      presentDetail: map['presentDetail'] as String,
      teacherId: map['teacherId'] as String,
      date: (map['date'] as Timestamp).toDate(),
    );
  }

  //</editor-fold>
}
