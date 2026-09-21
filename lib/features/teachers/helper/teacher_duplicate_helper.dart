import 'package:flutter/material.dart';
import 'package:scholo_admin/models/teacher_model.dart';

class TeacherDuplicateChecker {
  /// Normalizes a name string by converting to lowercase, removing special symbols, and trimming spaces.
  static String normalizeName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if two teacher names match or overlap (accounting for initials, honorific prefixes, etc.)
  static bool areNamesMatching(String name1, String name2) {
    final norm1 = normalizeName(name1);
    final norm2 = normalizeName(name2);

    if (norm1.isEmpty || norm2.isEmpty) return false;

    // Exact or substring match
    if (norm1 == norm2 || norm1.contains(norm2) || norm2.contains(norm1)) {
      return true;
    }

    final tokens1 = norm1.split(' ').where((t) => t.isNotEmpty).toList();
    final tokens2 = norm2.split(' ').where((t) => t.isNotEmpty).toList();

    // Ignore common prefix honorifics
    final prefixList = {
      'muhammed',
      'mohammed',
      'muhamed',
      'ahammed',
      'ahmed',
      'mr',
      'mrs',
      'dr',
      'prof'
    };

    final mainTokens1 = tokens1.where((t) => !prefixList.contains(t) && t.length > 1).toList();
    final mainTokens2 = tokens2.where((t) => !prefixList.contains(t) && t.length > 1).toList();

    // If main tokens intersect (e.g., "Anas" in both "Anas" and "Anas K")
    for (final t1 in mainTokens1) {
      for (final t2 in mainTokens2) {
        if (t1 == t2 || t1.contains(t2) || t2.contains(t1)) {
          return true;
        }
      }
    }

    // Fallback: check first token match
    if (tokens1.isNotEmpty && tokens2.isNotEmpty) {
      if (tokens1.first == tokens2.first) return true;
    }

    return false;
  }

  /// Extracts digits only from a phone number string.
  static String extractMobileDigits(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    // If phone has country code (e.g. 919544224298), return last 10 digits for standard mobile comparison
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Searches for a duplicate teacher in the existing active teachers list.
  static TeacherModel? findDuplicate({
    required List<TeacherModel> existingTeachers,
    required String newEmployeeId,
    required String newName,
    required String newMobile,
    required DateTime newDob,
    String? currentEditingTeacherId,
  }) {
    final cleanEmpId = newEmployeeId.trim().toLowerCase();
    final cleanMobileDigits = extractMobileDigits(newMobile);

    for (final teacher in existingTeachers) {
      // Ignore self if editing an existing record
      if (currentEditingTeacherId != null &&
          currentEditingTeacherId.isNotEmpty &&
          teacher.id == currentEditingTeacherId) {
        continue;
      }

      // Rule 1: Unique Employee ID Check
      if (cleanEmpId.isNotEmpty &&
          teacher.employeeId.trim().toLowerCase() == cleanEmpId) {
        return teacher;
      }

      // Rule 2 & 3: Mobile Number + DOB + Name Matching
      final existingMobileDigits = extractMobileDigits(teacher.mobileNo);

      final isMobileMatch = cleanMobileDigits.isNotEmpty &&
          existingMobileDigits.isNotEmpty &&
          (cleanMobileDigits == existingMobileDigits ||
              cleanMobileDigits.endsWith(existingMobileDigits) ||
              existingMobileDigits.endsWith(cleanMobileDigits));

      final isDobMatch = teacher.dateOfBirth.year == newDob.year &&
          teacher.dateOfBirth.month == newDob.month &&
          teacher.dateOfBirth.day == newDob.day;

      final isNameMatch = areNamesMatching(newName, teacher.teacherName);

      // Duplicate if Mobile & DOB match AND Name matches/overlaps
      if (isMobileMatch && isDobMatch && isNameMatch) {
        return teacher;
      }

      // Duplicate if Mobile & DOB match exactly
      if (isMobileMatch && isDobMatch) {
        return teacher;
      }

      // Duplicate if Employee ID and Name match
      if (cleanEmpId.isNotEmpty &&
          teacher.employeeId.trim().toLowerCase() == cleanEmpId &&
          isNameMatch) {
        return teacher;
      }
    }

    return null;
  }

  /// Displays a formatted Alert Dialog with the existing teacher's details.
  static Future<void> showDuplicateAlertDialog({
    required BuildContext context,
    required TeacherModel existingTeacher,
  }) async {
    final dobFormatted =
        "${existingTeacher.dateOfBirth.day.toString().padLeft(2, '0')}/${existingTeacher.dateOfBirth.month.toString().padLeft(2, '0')}/${existingTeacher.dateOfBirth.year}";

    final classDivText = (existingTeacher.classNo == 0 || existingTeacher.division == 'Nil')
        ? "Not Assigned"
        : "${existingTeacher.classNo} - ${existingTeacher.division}";

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Warning Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Duplicate Teacher Found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "A teacher record with these details already exists.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Details Card Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _detailRow("Employee ID", existingTeacher.employeeId, isBadge: true),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Teacher Name", existingTeacher.teacherName),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Mobile Number", existingTeacher.mobileNo),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Date of Birth", dobFormatted),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Class & Division", classDivText),
                      if (existingTeacher.subject.isNotEmpty) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _detailRow("Subject", existingTeacher.subject),
                      ],
                      if (existingTeacher.email.isNotEmpty) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _detailRow("Email", existingTeacher.email),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Close Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      "Understand & Close",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _detailRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1193D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1193D4).withValues(alpha: 0.3)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1193D4),
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
