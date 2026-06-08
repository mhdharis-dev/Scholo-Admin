// lib/features/auth/repository/login_repository.dart
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/session_manager.dart';

class LoginRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Admin login verification
  Future<bool> loginAdmin(String email, String password) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        // Check isDeleted in-memory to avoid query mismatch for missing fields
        if (data['isDeleted'] == true) {
          return false;
        }
        
        final schoolId = data['schoolId'] ?? doc.id;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'admin');
        await prefs.setString('schoolId', schoolId);
        await prefs.setString('admin_name', data['principalName'] ?? 'Administrator');
        await prefs.setString('admin_school_name', data['schoolName'] ?? 'ABC Public School');
        await prefs.setString('admin_gender', data['gender'] ?? 'Male');
        await prefs.setString('admin_mobile', data['phoneNumber'] ?? '+919876543210');
        
        SessionManager.schoolId = schoolId;
        return true;
      } else {
        return false;
      }
    } catch (e) {
      log('Login error: $e');
      rethrow;
    }
  }

  /// ✅ Restore saved session
  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role == 'admin') {
      final schoolId = prefs.getString('schoolId');
      if (schoolId != null) {
        SessionManager.schoolId = schoolId;
      }
    }
    return role;
  }
}
