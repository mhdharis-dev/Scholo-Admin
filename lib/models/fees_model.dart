import 'package:cloud_firestore/cloud_firestore.dart';

class FeeModel {
  final String description; // docId
  final double fee;
  final double totalAmount;
  final int classNo;
  final int collectedCount;
  final String division;
  final String teacherName;
  final String teacherId;
  final bool delete;
  final bool completed;
  final DateTime createdDate;

  // ✅ ADDED
  final DateTime? deletedAt;

  final List<Map<String, dynamic>> students;

  const FeeModel({
    required this.description,
    required this.fee,
    required this.totalAmount,
    required this.classNo,
    required this.collectedCount,
    required this.division,
    required this.teacherName,
    required this.teacherId,
    required this.delete,
    required this.completed,
    required this.createdDate,

    // ✅ ADDED
    this.deletedAt,

    required this.students,
  });

  FeeModel copyWith({
    String? description,
    double? fee,
    double? totalAmount,
    int? classNo,
    int? collectedCount,
    String? division,
    String? teacherName,
    String? teacherId,
    bool? delete,
    bool? completed,
    DateTime? createdDate,

    // ✅ ADDED
    DateTime? deletedAt,

    List<Map<String, dynamic>>? students,
  }) {
    return FeeModel(
      description: description ?? this.description,
      fee: fee ?? this.fee,
      totalAmount: totalAmount ?? this.totalAmount,
      classNo: classNo ?? this.classNo,
      collectedCount: collectedCount ?? this.collectedCount,
      division: division ?? this.division,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      delete: delete ?? this.delete,
      completed: completed ?? this.completed,
      createdDate: createdDate ?? this.createdDate,

      // ✅ ADDED
      deletedAt: deletedAt ?? this.deletedAt,

      students: students ?? this.students,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'fee': fee,
      'totalAmount': totalAmount,
      'classNo': classNo,
      'collectedCount': collectedCount,
      'division': division,
      'teacherName': teacherName,
      'teacherId': teacherId,
      'delete': delete,
      'completed': completed,
      'createdDate': Timestamp.fromDate(createdDate),

      // ✅ ADDED
      'deletedAt':
      deletedAt == null ? null : Timestamp.fromDate(deletedAt!),

      'students': students,
    };
  }

  factory FeeModel.fromMap(Map<String, dynamic> map) {
    return FeeModel(
      description: map['description'] ?? '',
      fee: (map['fee'] as num).toDouble(),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      classNo: map['classNo'] ?? 0,
      collectedCount: map['collectedCount'] ?? 0,
      division: map['division'] ?? '',
      teacherName: map['teacherName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      delete: map['delete'] ?? false,
      completed: map['completed'] ?? false,

      createdDate: (map['createdDate'] is Timestamp)
          ? (map['createdDate'] as Timestamp).toDate()
          : DateTime.now(),

      // ✅ ADDED
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,

      students: List<Map<String, dynamic>>.from(
        map['students'] ?? [],
      ),
    );
  }
}