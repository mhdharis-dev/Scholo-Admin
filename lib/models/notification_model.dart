import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationAttachmentItem {
  final String url;
  final String type; // 'image', 'pdf', 'link'
  final String name;

  const NotificationAttachmentItem({
    required this.url,
    required this.type,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'name': name,
    };
  }

  factory NotificationAttachmentItem.fromMap(Map<String, dynamic> map) {
    return NotificationAttachmentItem(
      url: map['url'] ?? '',
      type: map['type'] ?? 'none',
      name: map['name'] ?? '',
    );
  }
}

class NotificationModel {
  final String id; // e.g. "notification@001"
  final String title;
  final String body;
  final String category; // 'General', 'Urgent', 'Event', 'Exam', 'Fee'
  final String audienceType; // 'All School', 'All Teachers', 'All Parents', 'All Students', 'Specific Class', 'Specific Teacher(s)', 'Specific Student(s)', 'Custom (Multiple Targets)'

  final List<String> targetAudienceLabels;
  final List<String> targetTeacherIds;
  final List<String> targetTeacherNames;
  final List<String> targetStudentIds;
  final List<String> targetStudentNames;
  final String targetClass; // e.g. "10A" or "12 Arabic"
  final List<String> targetFcmTokens; // Collected recipient FCM tokens ("not shared" if absent)

  // 🔹 Multi-Attachment Support (Multiple PDFs, Multiple Images, Multiple Links, Mixed)
  final List<NotificationAttachmentItem> attachments;

  // Backward compatibility legacy fields
  final String attachmentUrl;
  final String attachmentType;
  final String attachmentName;

  final DateTime createdAt;
  final String senderName;
  final String senderId;
  final String senderRole; // 'Admin', 'Teacher'
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'General',
    this.audienceType = 'All School',
    this.targetAudienceLabels = const [],
    this.targetTeacherIds = const [],
    this.targetTeacherNames = const [],
    this.targetStudentIds = const [],
    this.targetStudentNames = const [],
    this.targetClass = '',
    this.targetFcmTokens = const [],
    this.attachments = const [],
    this.attachmentUrl = '',
    this.attachmentType = 'none',
    this.attachmentName = '',
    required this.createdAt,
    this.senderName = 'Admin',
    this.senderId = '',
    this.senderRole = 'Admin',
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? category,
    String? audienceType,
    List<String>? targetAudienceLabels,
    List<String>? targetTeacherIds,
    List<String>? targetTeacherNames,
    List<String>? targetStudentIds,
    List<String>? targetStudentNames,
    String? targetClass,
    List<String>? targetFcmTokens,
    List<NotificationAttachmentItem>? attachments,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    DateTime? createdAt,
    String? senderName,
    String? senderId,
    String? senderRole,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      audienceType: audienceType ?? this.audienceType,
      targetAudienceLabels: targetAudienceLabels ?? this.targetAudienceLabels,
      targetTeacherIds: targetTeacherIds ?? this.targetTeacherIds,
      targetTeacherNames: targetTeacherNames ?? this.targetTeacherNames,
      targetStudentIds: targetStudentIds ?? this.targetStudentIds,
      targetStudentNames: targetStudentNames ?? this.targetStudentNames,
      targetClass: targetClass ?? this.targetClass,
      targetFcmTokens: targetFcmTokens ?? this.targetFcmTokens,
      attachments: attachments ?? this.attachments,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'audienceType': audienceType,
      'targetAudienceLabels': targetAudienceLabels,
      'targetTeacherIds': targetTeacherIds,
      'targetTeacherNames': targetTeacherNames,
      'targetStudentIds': targetStudentIds,
      'targetStudentNames': targetStudentNames,
      'targetClass': targetClass,
      'targetFcmTokens': targetFcmTokens,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'attachmentName': attachmentName,
      'createdAt': Timestamp.fromDate(createdAt),
      'senderName': senderName,
      'senderId': senderId,
      'senderRole': senderRole,
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    List<NotificationAttachmentItem> list = [];
    if (map['attachments'] is List) {
      list = (map['attachments'] as List)
          .map((item) => NotificationAttachmentItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    final legacyUrl = map['attachmentUrl'] ?? '';
    final legacyType = map['attachmentType'] ?? 'none';
    final legacyName = map['attachmentName'] ?? '';

    if (list.isEmpty && legacyUrl.toString().isNotEmpty && legacyType != 'none') {
      list.add(NotificationAttachmentItem(
        url: legacyUrl,
        type: legacyType,
        name: legacyName,
      ));
    }

    return NotificationModel(
      id: map['id'] ?? docId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      category: map['category'] ?? 'General',
      audienceType: map['audienceType'] ?? 'All School',
      targetAudienceLabels: List<String>.from(map['targetAudienceLabels'] ?? []),
      targetTeacherIds: List<String>.from(map['targetTeacherIds'] ?? []),
      targetTeacherNames: List<String>.from(map['targetTeacherNames'] ?? []),
      targetStudentIds: List<String>.from(map['targetStudentIds'] ?? []),
      targetStudentNames: List<String>.from(map['targetStudentNames'] ?? []),
      targetClass: map['targetClass'] ?? '',
      targetFcmTokens: List<String>.from(map['targetFcmTokens'] ?? []),
      attachments: list,
      attachmentUrl: legacyUrl,
      attachmentType: legacyType,
      attachmentName: legacyName,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] is String
              ? (DateTime.tryParse(map['createdAt']) ?? DateTime.now())
              : DateTime.now()),
      senderName: map['senderName'] ?? 'Admin',
      senderId: map['senderId'] ?? '',
      senderRole: map['senderRole'] ?? 'Admin',
      isRead: map['isRead'] ?? false,
    );
  }
}
