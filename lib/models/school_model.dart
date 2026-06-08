import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolModel {
  final String schoolId;
  final String schoolName;
  final String schoolCode;
  final String schoolAddress;
  final String principalName;
  final String gender;
  final String phoneNumber;
  final String officialEmail;
  final String subscriptionPlan;
  final String status; // Active / Inactive
  final String environment; // prod / test
  final String imageUrl; // school logo
  final String email; // admin email
  final String password; // admin password
  final bool isDeleted;
  final DateTime createdAt;

  SchoolModel({
    required this.schoolId,
    required this.schoolName,
    required this.schoolCode,
    required this.schoolAddress,
    required this.principalName,
    required this.gender,
    required this.phoneNumber,
    required this.officialEmail,
    required this.subscriptionPlan,
    required this.status,
    required this.environment,
    required this.imageUrl,
    required this.email,
    required this.password,
    required this.isDeleted,
    required this.createdAt,
  });

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    return SchoolModel(
      schoolId: map['schoolId'] ?? '',
      schoolName: map['schoolName'] ?? '',
      schoolCode: map['schoolCode'] ?? '',
      schoolAddress: map['schoolAddress'] ?? '',
      principalName: map['principalName'] ?? '',
      gender: map['gender'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      officialEmail: map['officialEmail'] ?? '',
      subscriptionPlan: map['subscriptionPlan'] ?? '',
      status: map['status'] ?? 'Active',
      environment: map['environment'] ?? 'test',
      imageUrl: map['imageUrl'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      isDeleted: map['isDeleted'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'schoolName': schoolName,
      'schoolCode': schoolCode,
      'schoolAddress': schoolAddress,
      'principalName': principalName,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'officialEmail': officialEmail,
      'subscriptionPlan': subscriptionPlan,
      'status': status,
      'environment': environment,
      'imageUrl': imageUrl,
      'email': email,
      'password': password,
      'isDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SchoolModel copyWith({
    String? schoolId,
    String? schoolName,
    String? schoolCode,
    String? schoolAddress,
    String? principalName,
    String? gender,
    String? phoneNumber,
    String? officialEmail,
    String? subscriptionPlan,
    String? status,
    String? environment,
    String? imageUrl,
    String? email,
    String? password,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return SchoolModel(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      schoolCode: schoolCode ?? this.schoolCode,
      schoolAddress: schoolAddress ?? this.schoolAddress,
      principalName: principalName ?? this.principalName,
      gender: gender ?? this.gender,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      officialEmail: officialEmail ?? this.officialEmail,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      status: status ?? this.status,
      environment: environment ?? this.environment,
      imageUrl: imageUrl ?? this.imageUrl,
      email: email ?? this.email,
      password: password ?? this.password,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
