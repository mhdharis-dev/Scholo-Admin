import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/session_manager.dart';

class EventModel {
  final String title; // Used as Firestore document ID
  final String description;
  final String color;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final List<String> classes;
  final DateTime createdAt;
  final bool delete;
  final String schoolId;

  // ✅ ADDED
  final DateTime? deletedAt;

  const EventModel({
    required this.title,
    required this.description,
    required this.color,
    required this.startDateTime,
    required this.endDateTime,
    required this.classes,
    required this.createdAt,
    required this.delete,
    this.schoolId = '',

    // ✅ ADDED
    this.deletedAt,
  });

  EventModel copyWith({
    String? title,
    String? description,
    String? color,
    DateTime? startDateTime,
    DateTime? endDateTime,
    List<String>? classes,
    DateTime? createdAt,
    bool? delete,
    String? schoolId,

    // ✅ ADDED
    DateTime? deletedAt,
  }) {
    return EventModel(
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      classes: classes ?? this.classes,
      createdAt: createdAt ?? this.createdAt,
      delete: delete ?? this.delete,
      schoolId: schoolId ?? this.schoolId,

      // ✅ ADDED
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'color': color,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'classes': classes,
      'createdAt': Timestamp.fromDate(createdAt),
      'delete': delete,
      'schoolId': schoolId.isEmpty ? SessionManager.schoolId : schoolId,

      // ✅ ADDED
      'deletedAt':
      deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      title: map['title'] as String,
      description: map['description'] as String,
      color: map['color'] as String,
      startDateTime: (map['startDateTime'] as Timestamp).toDate(),
      endDateTime: (map['endDateTime'] as Timestamp).toDate(),
      classes: List<String>.from(map['classes'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      delete: map['delete'] ?? false,
      schoolId: map['schoolId'] ?? '',

      // ✅ ADDED
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
    );
  }
}