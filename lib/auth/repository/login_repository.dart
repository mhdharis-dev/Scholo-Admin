// lib/features/auth/repository/login_repository.dart
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constant/firebase_constant.dart';

class LoginRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Admin login verification
  Future<bool> loginAdmin(String email, String password) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstant.admin)
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'admin');
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
    return prefs.getString('role');
  }
}
