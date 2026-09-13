import 'dart:html' as html;
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

  /// Detects browser and OS details cleanly for device metadata
  static Map<String, String> getDeviceMetadata() {
    String platform = kIsWeb ? 'Web' : defaultTargetPlatform.name;
    String deviceName = 'Admin Device';
    String manufacturer = 'Generic';
    String model = 'Web Browser';
    String osVersion = 'Unknown OS';

    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();
      if (userAgent.contains('chrome')) {
        deviceName = 'Chrome Browser';
        model = 'Chrome';
      } else if (userAgent.contains('firefox')) {
        deviceName = 'Firefox Browser';
        model = 'Firefox';
      } else if (userAgent.contains('safari') && !userAgent.contains('chrome')) {
        deviceName = 'Safari Browser';
        model = 'Safari';
      } else if (userAgent.contains('edg')) {
        deviceName = 'Edge Browser';
        model = 'Edge';
      }

      if (userAgent.contains('windows')) {
        osVersion = 'Windows OS';
        manufacturer = 'Microsoft';
      } else if (userAgent.contains('macintosh') || userAgent.contains('mac os')) {
        osVersion = 'macOS';
        manufacturer = 'Apple';
      } else if (userAgent.contains('android')) {
        osVersion = 'Android';
        manufacturer = 'Android';
      } else if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
        osVersion = 'iOS';
        manufacturer = 'Apple';
      } else if (userAgent.contains('linux')) {
        osVersion = 'Linux OS';
        manufacturer = 'Linux';
      }
    }

    return {
      'platform': platform,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'model': model,
      'osVersion': osVersion,
      'appVersion': '1.0.0+1',
    };
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

      String fcmToken = '';
      bool pushEnabled = false;

      try {
        fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
        pushEnabled = fcmToken.isNotEmpty;
      } catch (e) {
        debugPrint('FCM Token not available on this platform/browser: $e');
      }

      final metadata = getDeviceMetadata();
      final docRef = _firestore.collection('schools').doc(schoolId).collection('adminDevices').doc(deviceId);
      final docSnap = await docRef.get();

      final now = DateTime.now();

      AdminDeviceModel deviceModel;

      if (!docSnap.exists) {
        // Create new device record
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
        // Update existing device record
        final existingMap = docSnap.data() as Map<String, dynamic>;
        final existingModel = AdminDeviceModel.fromMap(existingMap, docId: docSnap.id);

        deviceModel = existingModel.copyWith(
          adminUid: effectiveUid,
          fcmToken: fcmToken.isNotEmpty ? fcmToken : existingModel.fcmToken,
          platform: metadata['platform']!,
          deviceName: metadata['deviceName']!,
          manufacturer: metadata['manufacturer']!,
          model: metadata['model']!,
          osVersion: metadata['osVersion']!,
          appVersion: metadata['appVersion']!,
          lastLoginAt: now,
          lastSeenAt: now,
          logoutAt: null, // Clear logout timestamp on fresh login/session
          isActive: true,
          pushEnabled: pushEnabled || existingModel.pushEnabled,
          updatedAt: now,
        );

        await docRef.update(deviceModel.toMap());
      }

      return deviceModel;
    } catch (e) {
      debugPrint('Error registering admin device: $e');
      return null;
    }
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
      // Sort by lastLoginAt descending
      list.sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
      return list;
    });
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
