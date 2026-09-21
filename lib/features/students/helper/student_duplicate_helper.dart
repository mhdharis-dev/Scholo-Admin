import 'package:flutter/material.dart';
import 'package:scholo_admin/models/students_model.dart';

class StudentDuplicateChecker {
  /// Normalizes a name string by converting to lowercase, removing special symbols, and trimming spaces.
  static String normalizeName(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Checks if two student names match or overlap (accounting for initials, honorific prefixes, etc.)
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

    // Ignore common prefix honorifics / names
    final prefixList = {
      'muhammed',
      'mohammed',
      'muhamed',
      'ahammed',
      'ahmed',
      'mr',
      'mrs',
      'master',
      'baby'
    };

    final mainTokens1 = tokens1.where((t) => !prefixList.contains(t) && t.length > 1).toList();
    final mainTokens2 = tokens2.where((t) => !prefixList.contains(t) && t.length > 1).toList();

    // If main tokens intersect (e.g., "Haris" in both "Haris" and "Haris K")
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
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Searches for a duplicate student in the existing active students list.
  static StudentsModel? findDuplicate({
    required List<StudentsModel> existingStudents,
    required int newAdmissionNo,
    required String newName,
    required String newMobile,
    required DateTime newDob,
    String? currentEditingStudentId,
  }) {
    final cleanMobileDigits = extractMobileDigits(newMobile);

    for (final student in existingStudents) {
      // Ignore self if editing an existing record
      if (currentEditingStudentId != null &&
          currentEditingStudentId.isNotEmpty &&
          student.studentId == currentEditingStudentId) {
        continue;
      }

      // Rule 1: Unique Admission Number Check
      if (newAdmissionNo > 0 && student.admissionNo == newAdmissionNo) {
        return student;
      }

      // Rule 2 & 3: Mobile Number + DOB + Name Matching
      final existingMobileDigits = extractMobileDigits(student.mobileNo);

      final isMobileMatch = cleanMobileDigits.isNotEmpty &&
          existingMobileDigits.isNotEmpty &&
          (cleanMobileDigits == existingMobileDigits ||
              cleanMobileDigits.endsWith(existingMobileDigits) ||
              existingMobileDigits.endsWith(cleanMobileDigits));

      final isDobMatch = student.dateOfBirth.year == newDob.year &&
          student.dateOfBirth.month == newDob.month &&
          student.dateOfBirth.day == newDob.day;

      final isNameMatch = areNamesMatching(newName, student.studentName);

      // Duplicate if Mobile & DOB match AND Name matches/overlaps
      if (isMobileMatch && isDobMatch && isNameMatch) {
        return student;
      }

      // Duplicate if Mobile & DOB match exactly
      if (isMobileMatch && isDobMatch) {
        return student;
      }

      // Duplicate if Admission No and Name match
      if (newAdmissionNo > 0 &&
          student.admissionNo == newAdmissionNo &&
          isNameMatch) {
        return student;
      }
    }

    return null;
  }

  /// Displays a formatted Alert Dialog with the existing student's details.
  static Future<void> showDuplicateAlertDialog({
    required BuildContext context,
    required StudentsModel existingStudent,
  }) async {
    final dobFormatted =
        "${existingStudent.dateOfBirth.day.toString().padLeft(2, '0')}/${existingStudent.dateOfBirth.month.toString().padLeft(2, '0')}/${existingStudent.dateOfBirth.year}";

    final classNoStr = existingStudent.classNo == -2
        ? 'LKG'
        : (existingStudent.classNo == -1
            ? 'UKG'
            : (existingStudent.classNo == 0 ? 'Not Assigned' : existingStudent.classNo.toString()));
    final classDivText = "$classNoStr - ${existingStudent.division}";

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
                            "Duplicate Student Found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "A student record with these details already exists.",
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
                      _detailRow("Admission No", existingStudent.admissionNo.toString(), isBadge: true),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Student Name", existingStudent.studentName),
                      if (existingStudent.parentName.isNotEmpty) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _detailRow("Parent / Guardian", existingStudent.parentName),
                      ],
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Mobile Number", existingStudent.mobileNo),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Date of Birth", dobFormatted),
                      const Divider(height: 16, color: Color(0xFFF1F5F9)),
                      _detailRow("Class & Division", classDivText),
                      if (existingStudent.email.isNotEmpty) ...[
                        const Divider(height: 16, color: Color(0xFFF1F5F9)),
                        _detailRow("Email", existingStudent.email),
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
