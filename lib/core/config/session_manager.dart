import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static String? _schoolId;

  static String get schoolId {
    if (_schoolId == null) {
      return '';
    }
    return _schoolId!;
  }

  static set schoolId(String? value) {
    _schoolId = value;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _schoolId = prefs.getString('schoolId');
  }
}
