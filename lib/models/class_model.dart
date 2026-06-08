import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';

class ClassStudentModel {
  final String studentId;
  final String studentName;
  final String imageUrl;
  final int rollNo;

  const ClassStudentModel({
    required this.studentId,
    required this.studentName,
    required this.imageUrl,
    required this.rollNo,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'imageUrl': imageUrl,
      'rollNo': rollNo,
    };
  }

  factory ClassStudentModel.fromMap(Map<String, dynamic> map) {
    return ClassStudentModel(
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      rollNo: map['rollNo'] ?? 0,
    );
  }
}

class ClassModel {
  final String? classId;
  final String classNo;
  final String division;
  final String className;
  final String schoolId;
  final bool delete;
  final DateTime createdDate;
  
  // New fields according to the drawing
  final String teacherName;
  final String teacherId;
  final int totalStudents;
  final Map<String, ClassStudentModel> students;

  const ClassModel({
    this.classId,
    required this.classNo,
    required this.division,
    required this.className,
    this.schoolId = '',
    required this.delete,
    required this.createdDate,
    this.teacherName = '',
    this.teacherId = '',
    this.totalStudents = 0,
    this.students = const {},
  });

  ClassModel copyWith({
    String? classId,
    String? classNo,
    String? division,
    String? className,
    String? schoolId,
    bool? delete,
    DateTime? createdDate,
    String? teacherName,
    String? teacherId,
    int? totalStudents,
    Map<String, ClassStudentModel>? students,
  }) {
    return ClassModel(
      classId: classId ?? this.classId,
      classNo: classNo ?? this.classNo,
      division: division ?? this.division,
      className: className ?? this.className,
      schoolId: schoolId ?? this.schoolId,
      delete: delete ?? this.delete,
      createdDate: createdDate ?? this.createdDate,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      totalStudents: totalStudents ?? this.totalStudents,
      students: students ?? this.students,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classNo': classNo,
      'division': division,
      'className': className.isEmpty ? 'Class $classNo' : className,
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,
      'delete': delete,
      'create': Timestamp.fromDate(createdDate),
      'teacherName': teacherName,
      'teacherId': teacherId,
      'totalStudents': totalStudents,
      'students': students.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory ClassModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawStudents = map['students'] as Map<String, dynamic>? ?? {};
    final parsedStudents = rawStudents.map((key, value) {
      return MapEntry(
        key,
        ClassStudentModel.fromMap(Map<String, dynamic>.from(value as Map)),
      );
    });

    return ClassModel(
      classId: docId,
      classNo: map['classNo']?.toString() ?? '',
      division: map['division']?.toString() ?? '',
      className: map['className']?.toString() ?? '',
      schoolId: map['schoolId'] ?? '',
      delete: map['delete'] ?? false,
      createdDate: map['create'] != null
          ? (map['create'] as Timestamp).toDate()
          : map['createdDate'] != null
              ? (map['createdDate'] as Timestamp).toDate()
              : DateTime.now(),
      teacherName: map['teacherName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      totalStudents: map['totalStudents'] ?? 0,
      students: parsedStudents,
    );
  }
}
