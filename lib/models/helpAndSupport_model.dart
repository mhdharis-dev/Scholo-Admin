import 'package:cloud_firestore/cloud_firestore.dart';

class HelpAndSupportModel {
  final String id;
  final String name;
  final String schoolName;
  final String officialEmail;
  final String message;
  final DateTime createdAt;
  final String status;
  final String schoolId;

  HelpAndSupportModel({
    required this.id,
    required this.name,
    required this.schoolName,
    required this.officialEmail,
    required this.message,
    required this.createdAt,
    this.status = 'Pending',
    required this.schoolId,
  });

  HelpAndSupportModel copyWith({
    String? id,
    String? name,
    String? schoolName,
    String? officialEmail,
    String? message,
    DateTime? createdAt,
    String? status,
    String? schoolId,
  }) {
    return HelpAndSupportModel(
      id: id ?? this.id,
      name: name ?? this.name,
      schoolName: schoolName ?? this.schoolName,
      officialEmail: officialEmail ?? this.officialEmail,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'schoolName': schoolName,
      'officialEmail': officialEmail,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'schoolId': schoolId,
    };
  }

  factory HelpAndSupportModel.fromMap(Map<String, dynamic> map) {
    DateTime createdDateTime;
    final createdVal = map['createdAt'];
    if (createdVal is Timestamp) {
      createdDateTime = createdVal.toDate();
    } else if (createdVal is String) {
      createdDateTime = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else if (createdVal is int) {
      createdDateTime = DateTime.fromMillisecondsSinceEpoch(createdVal);
    } else {
      createdDateTime = DateTime.now();
    }

    return HelpAndSupportModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      schoolName: map['schoolName'] ?? '',
      officialEmail: map['officialEmail'] ?? '',
      message: map['message'] ?? '',
      createdAt: createdDateTime,
      status: map['status'] ?? 'Pending',
      schoolId: map['schoolId'] ?? '',
    );
  }
}
