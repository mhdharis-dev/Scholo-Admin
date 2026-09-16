import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scholo_admin/core/config/session_manager.dart';
import 'package:scholo_admin/models/admin_device_model.dart';

final adminDeviceRepositoryProvider = Provider<AdminDeviceRepository>((ref) {
  return AdminDeviceRepository();
});

final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  return AdminDeviceRepository.getOrCreateDeviceId();
});

final adminDevicesStreamProvider = StreamProvider.autoDispose<List<AdminDeviceModel>>((ref) {
  final repo = ref.watch(adminDeviceRepositoryProvider);
  final schoolId = SessionManager.schoolId;
  if (schoolId.isEmpty) return Stream.value([]);
  return repo.getAdminDevicesStream(schoolId);
});

class AdminDeviceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _deviceIdPrefKey = 'scholo_admin_device_id_v1';
  StreamSubscription<String>? _tokenRefreshSub;

  /// Retrieves or creates a unique persistent Device ID for the current browser/device.
  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdPrefKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';
      await prefs.setString(_deviceIdPrefKey, deviceId);
    }
    return deviceId;
  }

  /// Detects browser and OS details cleanly for device metadata without dart:html
  static Map<String, String> getDeviceMetadata() {
    String platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    String deviceName = kIsWeb ? 'Web Browser' : 'Admin Device';
    String manufacturer = kIsWeb ? 'Browser Client' : 'Generic';
    String model = kIsWeb ? 'Web Console' : defaultTargetPlatform.name;
    String osVersion = defaultTargetPlatform.name;

    return {
      'platform': platform,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'appVersion': '1.0.0+1',
    };
  }

  /// Requests Notification Permission and retrieves real FCM token
  Future<String> requestAndSaveFcmToken({required String schoolId, String? deviceId}) async {
    if (schoolId.isEmpty) return '';
    final targetDeviceId = deviceId ?? await getOrCreateDeviceId();

    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('FCM Notification Authorization Status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          debugPrint('Obtained Real FCM Token: $token');
          await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('adminDevices')
              .doc(targetDeviceId)
              .set({
            'fcmToken': token,
            'pushEnabled': true,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));

          _setupTokenRefreshListener(schoolId, targetDeviceId);
          return token;
        }
      }
    } catch (e) {
      debugPrint('Error requesting/saving FCM Token: $e');
    }
    return '';
  }

  /// Listens to token refresh events
  void _setupTokenRefreshListener(String schoolId, String deviceId) {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken.isNotEmpty && schoolId.isNotEmpty && deviceId.isNotEmpty) {
        debugPrint('FCM Token Refreshed: $newToken');
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('adminDevices')
            .doc(deviceId)
            .set({
          'fcmToken': newToken,
          'pushEnabled': true,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
      }
    });
  }

  /// Registers or updates current device details under `schools/{schoolId}/adminDevices/{deviceId}`
  Future<AdminDeviceModel?> registerOrUpdateCurrentDevice({
    required String schoolId,
    String? adminUid,
  }) async {
    if (schoolId.isEmpty) return null;

    try {
      final deviceId = await getOrCreateDeviceId();
      final effectiveUid = (adminUid != null && adminUid.isNotEmpty) ? adminUid : schoolId;

      final metadata = getDeviceMetadata();
      final docRef = _firestore.collection('schools').doc(schoolId).collection('adminDevices').doc(deviceId);
      final docSnap = await docRef.get();

      final now = DateTime.now();
      String fcmToken = '';
      bool pushEnabled = false;

      // Try silently fetching existing token without forcing popup prompt immediately
      try {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
        pushEnabled = fcmToken.isNotEmpty;
      } catch (e) {
        debugPrint('Silent FCM token fetch info: $e');
      }

      AdminDeviceModel deviceModel;

      if (!docSnap.exists) {
        deviceModel = AdminDeviceModel(
          deviceId: deviceId,
          adminUid: effectiveUid,
          fcmToken: fcmToken,
          platform: metadata['platform']!,
          deviceName: metadata['deviceName']!,
          manufacturer: metadata['manufacturer']!,
          model: metadata['model']!,
          osVersion: metadata['osVersion']!,
          appVersion: metadata['appVersion']!,
          firstLoginAt: now,
          lastLoginAt: now,
          lastSeenAt: now,
          logoutAt: null,
          isActive: true,
          pushEnabled: pushEnabled,
          createdAt: now,
          updatedAt: now,
        );

        await docRef.set(deviceModel.toMap());
      } else {
        final existingMap = docSnap.data() as Map<String, dynamic>;
        final existingModel = AdminDeviceModel.fromMap(existingMap, docId: docSnap.id);

        final tokenToUse = fcmToken.isNotEmpty ? fcmToken : existingModel.fcmToken;

        deviceModel = existingModel.copyWith(
          adminUid: effectiveUid,
          fcmToken: tokenToUse,
          platform: metadata['platform']!,
          deviceName: metadata['deviceName']!,
          manufacturer: metadata['manufacturer']!,
          model: metadata['model']!,
          osVersion: metadata['osVersion']!,
          appVersion: metadata['appVersion']!,
          lastLoginAt: now,
          lastSeenAt: now,
          logoutAt: null, // Reset logout timestamp on active login session
          isActive: true,
          pushEnabled: tokenToUse.isNotEmpty || existingModel.pushEnabled,
          updatedAt: now,
        );

        await docRef.update(deviceModel.toMap());
      }

      _setupTokenRefreshListener(schoolId, deviceId);
      return deviceModel;
    } catch (e) {
      debugPrint('Error registering admin device: $e');
      return null;
    }
  }

  /// Stream of current device session status (active vs revoked)
  Stream<bool> listenToCurrentDeviceSession(String schoolId, String deviceId) {
    if (schoolId.isEmpty || deviceId.isEmpty) return Stream.value(true);
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('adminDevices')
        .doc(deviceId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return true; // Keep active if not yet registered
      final data = doc.data();
      return data?['isActive'] ?? true;
    });
  }

  /// Stream of all registered admin devices for a school
  Stream<List<AdminDeviceModel>> getAdminDevicesStream(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('adminDevices')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => AdminDeviceModel.fromMap(doc.data(), docId: doc.id)).toList();
      list.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      return list;
    });
  }

  /// Logout current device locally & update Firestore active flag
  Future<void> logoutCurrentDevice(String schoolId) async {
    try {
      final deviceId = await getOrCreateDeviceId();
      if (schoolId.isNotEmpty) {
        final now = DateTime.now();
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('adminDevices')
            .doc(deviceId)
            .update({
          'isActive': false,
          'logoutAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    } catch (e) {
      debugPrint('Error marking current device logged out: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdPrefKey);
      await prefs.clear();
      if (deviceId != null && deviceId.isNotEmpty) {
        await prefs.setString(_deviceIdPrefKey, deviceId);
      }
      SessionManager.schoolId = null;
    }
  }

  /// Logout specific device remotely
  Future<void> logoutDevice(String schoolId, String deviceId) async {
    final now = DateTime.now();
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('adminDevices')
        .doc(deviceId)
        .update({
      'isActive': false,
      'logoutAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  /// Logout all other devices except current device
  Future<void> logoutAllOtherDevices(String schoolId, String currentDeviceId) async {
    final snapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('adminDevices')
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      if (doc.id != currentDeviceId) {
        batch.update(doc.reference, {
          'isActive': false,
          'logoutAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    }

    await batch.commit();
  }

  /// Heartbeat last seen update
  Future<void> updateLastSeen(String schoolId, String deviceId) async {
    final now = DateTime.now();
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('adminDevices')
        .doc(deviceId)
        .update({
      'lastSeenAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
  }
}

