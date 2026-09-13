import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDeviceModel {
  final String deviceId;
  final String adminUid;
  final String fcmToken;
  final String platform;
  final String deviceName;
  final String manufacturer;
  final String model;
  final String osVersion;
  final String appVersion;
  final DateTime firstLoginAt;
  final DateTime lastLoginAt;
  final DateTime lastSeenAt;
  final DateTime? logoutAt;
  final bool isActive;
  final bool pushEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminDeviceModel({
    required this.deviceId,
    required this.adminUid,
    required this.fcmToken,
    required this.platform,
    required this.deviceName,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.appVersion,
    required this.firstLoginAt,
    required this.lastLoginAt,
    required this.lastSeenAt,
    this.logoutAt,
    required this.isActive,
    required this.pushEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminDeviceModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime parseDate(dynamic val, DateTime defaultDate) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return defaultDate;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final now = DateTime.now();

    return AdminDeviceModel(
      deviceId: (map['deviceId'] ?? docId ?? '').toString(),
      adminUid: (map['adminUid'] ?? '').toString(),
      fcmToken: (map['fcmToken'] ?? '').toString(),
      platform: (map['platform'] ?? 'Web').toString(),
      deviceName: (map['deviceName'] ?? 'Unknown Device').toString(),
      manufacturer: (map['manufacturer'] ?? 'Unknown').toString(),
      model: (map['model'] ?? 'Unknown').toString(),
      osVersion: (map['osVersion'] ?? '').toString(),
      appVersion: (map['appVersion'] ?? '1.0.0').toString(),
      firstLoginAt: parseDate(map['firstLoginAt'], now),
      lastLoginAt: parseDate(map['lastLoginAt'], now),
      lastSeenAt: parseDate(map['lastSeenAt'], now),
      logoutAt: parseNullableDate(map['logoutAt']),
      isActive: map['isActive'] ?? true,
      pushEnabled: map['pushEnabled'] ?? true,
      createdAt: parseDate(map['createdAt'], now),
      updatedAt: parseDate(map['updatedAt'], now),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'adminUid': adminUid,
      'fcmToken': fcmToken,
      'platform': platform,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'firstLoginAt': Timestamp.fromDate(firstLoginAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'logoutAt': logoutAt != null ? Timestamp.fromDate(logoutAt!) : null,
      'isActive': isActive,
      'pushEnabled': pushEnabled,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AdminDeviceModel copyWith({
    String? deviceId,
    String? adminUid,
    String? fcmToken,
    String? platform,
    String? deviceName,
    String? manufacturer,
    String? model,
    String? osVersion,
    String? appVersion,
    DateTime? firstLoginAt,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    DateTime? logoutAt,
    bool? isActive,
    bool? pushEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminDeviceModel(
      deviceId: deviceId ?? this.deviceId,
      adminUid: adminUid ?? this.adminUid,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      deviceName: deviceName ?? this.deviceName,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      firstLoginAt: firstLoginAt ?? this.firstLoginAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      logoutAt: logoutAt ?? this.logoutAt,
      isActive: isActive ?? this.isActive,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
