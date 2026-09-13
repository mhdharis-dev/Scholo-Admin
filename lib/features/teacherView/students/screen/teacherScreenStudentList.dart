import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_svg/svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/features/teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';

import '../../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../core/config/session_manager.dart';
import '../../../../core/constant/image_constant.dart';
import '../../../../models/students_model.dart';
import '../../../../models/teacher_model.dart';
import 'package:alert_info/alert_info.dart';

class AssignedClass {
  final int classNo;
  final String division;
  final bool isClassTeacher;
  final String? label;

  AssignedClass({
    required this.classNo,
    required this.division,
    required this.isClassTeacher,
    this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignedClass &&
          runtimeType == other.runtimeType &&
          classNo == other.classNo &&
          division == other.division &&
          label == other.label;

  @override
  int get hashCode => classNo.hashCode ^ division.hashCode ^ (label?.hashCode ?? 0);
}

class TeacherScreenStudentList extends ConsumerStatefulWidget {
  final String teacherId; // ✅ TeacherId from previous page

  const TeacherScreenStudentList({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherScreenStudentList> createState() =>
      _TeacherScreenStudentListState();
}

class _TeacherScreenStudentListState extends ConsumerState<TeacherScreenStudentList> {
  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollController = TextEditingController();
  final _admissionController = TextEditingController();
  final _parentController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _languageController = TextEditingController();
  final _clubsController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _searchController = TextEditingController();

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  String? _selectedGender;
  String? _selectedTeacherName;
  String? _classNo;
  String? _division;

  // Class Selection states
  List<AssignedClass> _assignedClasses = [];
  AssignedClass? _selectedClassItem;
  bool _isClassTeacher = true;
  final Map<String, String> _classTeacherNames = {};

  StudentsModel? editingStudent;

  // New State variables for redesign
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All'; // 'All', 'Present', 'Absent'
  bool _isLanguageTeacher = false;
  String _teacherSubject = '';
  String _selectedClassFilter = 'All';
  String _selectedLanguageFilter = 'All';
  String _selectedClubFilter = 'All';
  String _selectedGenderFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
    _nameController.addListener(_updateStudentCredentials);
    _admissionController.addListener(_updateStudentCredentials);
  }

  void _updateStudentCredentials() {
    if (editingStudent == null) {
      final name = _nameController.text.trim();
      final id = _admissionController.text.trim();
      if (name.isNotEmpty && id.isNotEmpty) {
        final firstName = name.split(' ').first.toLowerCase();
        _emailController.text = "$firstName$id@scholo.com";
        _passwordController.text = "$firstName@$id";
      } else {
        _emailController.clear();
        _passwordController.clear();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _rollController.dispose();
    _admissionController.dispose();
    _parentController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 🔹 Fetch Teachers List & Assigned Classes
  Future<void> _fetchTeachers() async {
    final doc = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .doc(widget.teacherId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final mainTeacher = TeacherModel.fromMap(data);

      final List<AssignedClass> classesList = [];
      final isLang = mainTeacher.isLanguageTeacher;
      final subj = mainTeacher.subject;

      final allTeachersSnapshot = await FirebaseFirestore.instance
          .schoolCollection(FirebaseConstant.teacher)
          .where("delete", isEqualTo: false)
          .get();

      final Map<String, String> classTeacherMap = {};
      for (var teacherDoc in allTeachersSnapshot.docs) {
        final tData = teacherDoc.data();
        final cNo = tData['classNo'] as int? ?? 0;
        final div = tData['division'] as String? ?? '';
        final tName = tData['teacherName'] as String? ?? '';
        if (cNo != 0 && div.isNotEmpty) {
          classTeacherMap["$cNo-$div"] = tName;
        }
      }

      if (isLang) {
        final langLabel = subj.isNotEmpty ? subj : "Language";
        classesList.add(AssignedClass(
          classNo: 999,
          division: 'All',
          isClassTeacher: mainTeacher.classNo != 0,
          label: "All Classes ($langLabel)",
        ));

        for (int c = 1; c <= 12; c++) {
          classesList.add(AssignedClass(
            classNo: c,
            division: 'All',
            isClassTeacher: false,
            label: "Class $c ($langLabel)",
          ));
        }

        if (mainTeacher.classNo != 0 &&
            mainTeacher.division.isNotEmpty &&
            mainTeacher.division != 'Nil' &&
            mainTeacher.division != 'Not') {
          final ctClass = AssignedClass(
            classNo: mainTeacher.classNo,
            division: mainTeacher.division,
            isClassTeacher: true,
            label: "Class ${mainTeacher.classNo}-${mainTeacher.division} (Class Teacher)",
          );
          if (!classesList.contains(ctClass)) {
            classesList.add(ctClass);
          }
        }
      } else {
        // 1. Add Class Teacher class if assigned
        if (mainTeacher.classNo != 0 &&
            mainTeacher.division.isNotEmpty &&
            mainTeacher.division != 'Nil' &&
            mainTeacher.division != 'Not') {
          classesList.add(AssignedClass(
            classNo: mainTeacher.classNo,
            division: mainTeacher.division,
            isClassTeacher: true,
          ));
        }

        // 2. Fetch all teachers to check otherTeachers lists for subject classes
        for (var teacherDoc in allTeachersSnapshot.docs) {
          final tData = teacherDoc.data();
          final otherTeachersRaw = tData['otherTeachers'] as List<dynamic>?;
          if (otherTeachersRaw != null) {
            final hasSubjectAssignment =
                otherTeachersRaw.any((item) => item['teacherId'] == widget.teacherId);
            if (hasSubjectAssignment) {
              final classNo = tData['classNo'] as int? ?? 0;
              final division = tData['division'] as String? ?? '';
              if (classNo != 0 && division.isNotEmpty && division != 'Nil') {
                final newClass = AssignedClass(
                  classNo: classNo,
                  division: division,
                  isClassTeacher: false,
                );
                if (!classesList.contains(newClass)) {
                  classesList.add(newClass);
                }
              }
            }
          }
        }
      }

      setState(() {
        _isLanguageTeacher = isLang;
        _teacherSubject = subj;
        _selectedTeacherName = mainTeacher.teacherName;
        _assignedClasses = classesList;
        _classTeacherNames.clear();
        _classTeacherNames.addAll(classTeacherMap);
        if (classesList.isNotEmpty) {
          _selectedClassItem = classesList.first;
          _classNo = _selectedClassItem!.classNo.toString();
          _division = _selectedClassItem!.division;
          _isClassTeacher = _selectedClassItem!.isClassTeacher;
        } else {
          _selectedClassItem = null;
          _classNo = null;
          _division = null;
          _isClassTeacher = false;
        }
      });
    }
  }

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  Future<String> _uploadToCloudinary(File file) async {
    final response = await CloudinaryService.studentProfile.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: 'student_images'),
    );
    return response.secureUrl;
  }

  /// 🔹 Pick Image
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  /// 🔹 Email Validation
  bool _isEmailValid(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  /// 🔹 Password Validation
  bool _isPasswordValid(String password) => password.length >= 6;

  /// 🔹 Validated Field
  Widget _buildValidatedField(
    TextEditingController controller,
    String label, {
    bool isEmail = false,
    bool isPassword = false,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    bool isValid = true;

    return StatefulBuilder(
      builder: (context, setStateField) {
        return TextField(
          controller: controller,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onChanged: (v) {
            setStateField(() {
              if (isEmail) isValid = _isEmailValid(v);
              if (isPassword) isValid = _isPasswordValid(v);
            });
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: (isEmail || isPassword)
                ? (controller.text.isEmpty
                      ? null
                      : Icon(
                          isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isValid ? Colors.green : Colors.red,
                        ))
                : null,
          ),
        );
      },
    );
  }

  /// 🔹 Phone Field
  Widget _buildPhoneField() {
    return CountryPhoneField(
      controller: _mobileController,
      labelText: 'Mobile No',
    );
  }

  /// 🔹 Gender Dropdown
  Widget _buildDropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) {
        return DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)));
      }).toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<String?> _showAddNewDialog({
    required BuildContext context,
    required String title,
    required String hint,
  }) {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1193D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, textController.text),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  /// 🔹 Language Dropdown Field with '+ Add new'
  Widget _buildLanguageDropdownField({
    required BuildContext context,
    required TextEditingController controller,
    required void Function(void Function()) setSheetState,
  }) {
    final baseLanguages = ['Arabic', 'Malayalam', 'Hindi', 'English', 'Sanskrit', 'Urdu'];
    final dynamicLanguages = <String>[...baseLanguages];

    final currentVal = controller.text.trim();
    if (currentVal.isNotEmpty && !dynamicLanguages.contains(currentVal)) {
      dynamicLanguages.add(currentVal);
    }

    const addNewKey = '__ADD_NEW__';

    final items = <DropdownMenuItem<String>>[
      ...dynamicLanguages.map((lang) {
        return DropdownMenuItem<String>(
          value: lang,
          child: Text(lang, style: const TextStyle(fontSize: 14)),
        );
      }),
      const DropdownMenuItem<String>(
        value: addNewKey,
        child: Row(
          children: [
            Icon(Icons.add, size: 18, color: Color(0xff1193D4)),
            SizedBox(width: 6),
            Text("Add new", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xff1193D4))),
          ],
        ),
      ),
    ];

    String? selectedValue = dynamicLanguages.contains(currentVal) ? currentVal : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      hint: Text("Second / Third Language", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      decoration: InputDecoration(
        labelText: 'Second / Third Language',
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: (val) async {
        if (val == addNewKey) {
          final customLang = await _showAddNewDialog(
            context: context,
            title: "Add New Language",
            hint: "e.g. French, German, Spanish...",
          );
          if (customLang != null && customLang.trim().isNotEmpty) {
            final trimmed = customLang.trim();
            controller.text = trimmed;
            setSheetState(() {});
          }
        } else if (val != null) {
          controller.text = val;
          setSheetState(() {});
        }
      },
    );
  }

  /// 🔹 Clubs / NSS / NCC Dropdown Field with '+ Add new'
  Widget _buildClubsDropdownField({
    required BuildContext context,
    required TextEditingController controller,
    required void Function(void Function()) setSheetState,
  }) {
    final baseClubs = ['NSS', 'NCC', 'Computer Science Club', 'Maths Club'];
    final dynamicClubs = <String>[...baseClubs];

    final currentVal = controller.text.trim();
    if (currentVal.isNotEmpty && !dynamicClubs.contains(currentVal)) {
      dynamicClubs.add(currentVal);
    }

    const addNewKey = '__ADD_NEW__';

    final items = <DropdownMenuItem<String>>[
      ...dynamicClubs.map((club) {
        return DropdownMenuItem<String>(
          value: club,
          child: Text(club, style: const TextStyle(fontSize: 14)),
        );
      }),
      const DropdownMenuItem<String>(
        value: addNewKey,
        child: Row(
          children: [
            Icon(Icons.add, size: 18, color: Color(0xff1193D4)),
            SizedBox(width: 6),
            Text("Add new", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xff1193D4))),
          ],
        ),
      ),
    ];

    String? selectedValue = dynamicClubs.contains(currentVal) ? currentVal : null;

    return DropdownButtonFormField<String>(
      value: selectedValue,
      hint: Text("Clubs / NSS / NCC", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
      decoration: InputDecoration(
        labelText: 'Clubs / NSS / NCC',
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: (val) async {
        if (val == addNewKey) {
          final customClub = await _showAddNewDialog(
            context: context,
            title: "Add New Club / Activity",
            hint: "e.g. Robotics Club, Arts Club...",
          );
          if (customClub != null && customClub.trim().isNotEmpty) {
            final trimmed = customClub.trim();
            controller.text = trimmed;
            setSheetState(() {});
          }
        } else if (val != null) {
          controller.text = val;
          setSheetState(() {});
        }
      },
    );
  }

  Widget _buildDateOfBirthField({
    BuildContext? context,
    void Function(void Function())? setSheetState,
  }) {
    final days = List.generate(31, (i) => (i + 1).toString().padLeft(2, '0'));
    final months = [
      {'val': '01', 'name': '01 - Jan'},
      {'val': '02', 'name': '02 - Feb'},
      {'val': '03', 'name': '03 - Mar'},
      {'val': '04', 'name': '04 - Apr'},
      {'val': '05', 'name': '05 - May'},
      {'val': '06', 'name': '06 - Jun'},
      {'val': '07', 'name': '07 - Jul'},
      {'val': '08', 'name': '08 - Aug'},
      {'val': '09', 'name': '09 - Sep'},
      {'val': '10', 'name': '10 - Oct'},
      {'val': '11', 'name': '11 - Nov'},
      {'val': '12', 'name': '12 - Dec'},
    ];
    final currentYear = DateTime.now().year;
    final years = List.generate(80, (i) => (currentYear - i).toString());

    String? currentDay = days.contains(_dayController.text.padLeft(2, '0'))
        ? _dayController.text.padLeft(2, '0')
        : null;
    String? currentMonth = months.any((m) => m['val'] == _monthController.text.padLeft(2, '0'))
        ? _monthController.text.padLeft(2, '0')
        : null;
    String? currentYearVal = years.contains(_yearController.text)
        ? _yearController.text
        : null;

    void updateState() {
      if (setSheetState != null) {
        setSheetState(() {});
      } else {
        setState(() {});
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Day Dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentDay,
                hint: const Text("DD", style: TextStyle(fontSize: 13, color: Colors.grey)),
                isExpanded: true,
                items: days.map((d) {
                  return DropdownMenuItem<String>(
                    value: d,
                    child: Text(d, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _dayController.text = val;
                    updateState();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text("/", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          // Month Dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentMonth,
                hint: const Text("MM", style: TextStyle(fontSize: 13, color: Colors.grey)),
                isExpanded: true,
                items: months.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['val'],
                    child: Text(m['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _monthController.text = val;
                    updateState();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text("/", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          // Year Dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentYearVal,
                hint: const Text("YYYY", style: TextStyle(fontSize: 13, color: Colors.grey)),
                isExpanded: true,
                items: years.map((y) {
                  return DropdownMenuItem<String>(
                    value: y,
                    child: Text(y, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    _yearController.text = val;
                    updateState();
                  }
                },
              ),
            ),
          ),
          if (context != null) ...[
            const SizedBox(width: 8),
            // Calendar Icon DatePicker Button
            InkWell(
              onTap: () async {
                int initYear = int.tryParse(_yearController.text) ?? (currentYear - 10);
                int initMonth = int.tryParse(_monthController.text) ?? 1;
                int initDay = int.tryParse(_dayController.text) ?? 1;
                if (initYear < 1950 || initYear > currentYear) initYear = currentYear - 10;
                if (initMonth < 1 || initMonth > 12) initMonth = 1;
                if (initDay < 1 || initDay > 31) initDay = 1;

                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(initYear, initMonth, initDay),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );

                if (picked != null) {
                  _dayController.text = picked.day.toString().padLeft(2, '0');
                  _monthController.text = picked.month.toString().padLeft(2, '0');
                  _yearController.text = picked.year.toString();
                  updateState();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff1193D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: Color(0xff1193D4), size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openStudentDialog([StudentsModel? student]) {
    if (student != null) {
      editingStudent = student;
      _nameController.text = student.studentName;
      _emailController.text = student.email;
      _passwordController.text = student.password;
      _rollController.text = student.rollNo.toString();
      _admissionController.text = student.admissionNo.toString();
      _mobileController.text = student.mobileNo;
      _parentController.text = student.parentName;
      _addressController.text = student.address;
      _languageController.text = student.language;
      _clubsController.text = student.clubs_nss_ncc;
      _selectedGender = student.gender;
      _classNo = student.classNo.toString();
      _division = student.division;
      _selectedTeacherName = student.teacherName;
      _uploadedImageUrl = student.imageUrl;
      _dayController.text = student.dateOfBirth.day.toString();
      _monthController.text = student.dateOfBirth.month.toString();
      _yearController.text = student.dateOfBirth.year.toString();
    } else {
      editingStudent = null;
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _rollController.clear();
      _admissionController.clear();
      _mobileController.clear();
      _parentController.clear();
      _addressController.clear();
      _languageController.clear();
      _clubsController.clear();
      _dayController.clear();
      _monthController.clear();
      _yearController.clear();
      _selectedGender = null;
      _uploadedImageUrl = null;
      _selectedFile = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          width: 600,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    editingStudent == null ? 'Add New Student' : 'Edit Student Profile',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Image
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _selectedFile != null
                            ? FileImage(_selectedFile!)
                            : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                                  ? NetworkImage(_uploadedImageUrl!)
                                  : const AssetImage(ImageConstant.temporaryStudentImage)
                                as ImageProvider),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xff1193D4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildValidatedField(_admissionController, "Admission No", inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ]),
                const SizedBox(height: 14),
                _buildValidatedField(_nameController, "Name", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                _buildValidatedField(_rollController, "Roll No", inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ]),
                const SizedBox(height: 14),
                _buildPhoneField(),
                const SizedBox(height: 14),
                _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) => setState(() => _selectedGender = v)),
                const SizedBox(height: 14),
                _buildDateOfBirthField(context: context),
                const SizedBox(height: 14),
                _buildValidatedField(_parentController, "Parent Name", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                _buildValidatedField(_addressController, "Address", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                const SizedBox(height: 14),
                _buildLanguageDropdownField(
                  context: context,
                  controller: _languageController,
                  setSheetState: setState,
                ),
                const SizedBox(height: 14),
                _buildClubsDropdownField(
                  context: context,
                  controller: _clubsController,
                  setSheetState: setState,
                ),
                const SizedBox(height: 14),
                _buildValidatedField(_emailController, "Email", isEmail: true, readOnly: true),
                const SizedBox(height: 14),
                _buildValidatedField(_passwordController, "Password", isPassword: true, readOnly: true),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1193D4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isUploading
                        ? null
                        : () async {
                      final admissionNo = _admissionController.text.trim();
                      final rollNo = _rollController.text.trim();
                      final name = _nameController.text.trim();
                      final mobile = _mobileController.text.trim();
                      final parent = _parentController.text.trim();
                      final address = _addressController.text.trim();
                      final email = _emailController.text.trim();
                      final password = _passwordController.text.trim();
                      final day = _dayController.text.trim();
                      final month = _monthController.text.trim();
                      final year = _yearController.text.trim();

                      if (admissionNo.isEmpty || admissionNo.length != 6) {
                        AlertInfo.show(
                          context: context,
                          text: 'Admission number must be exactly 6 digits',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (name.isEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: 'Name cannot be empty',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (rollNo.isEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: 'Roll number cannot be empty',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      final phoneError = getPhoneValidationErrorMessage(mobile);
                      if (phoneError.isNotEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: phoneError,
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (_selectedGender == null || _selectedGender!.isEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: 'Please select a gender',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (_classNo == null || _division == null) {
                        AlertInfo.show(
                          context: context,
                          text: 'Teacher data not loaded',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      final dayVal = int.tryParse(day);
                      final monthVal = int.tryParse(month);
                      final yearVal = int.tryParse(year);
                      if (dayVal == null || dayVal < 1 || dayVal > 31 ||
                          monthVal == null || monthVal < 1 || monthVal > 12 ||
                          yearVal == null || yearVal < 1900 || yearVal > DateTime.now().year) {
                        AlertInfo.show(
                          context: context,
                          text: 'Please enter a valid Date of Birth (DD/MM/YYYY)',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (parent.isEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: 'Parent name cannot be empty',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (address.isEmpty) {
                        AlertInfo.show(
                          context: context,
                          text: 'Address cannot be empty',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (!_isEmailValid(email)) {
                        AlertInfo.show(
                          context: context,
                          text: 'Please enter a valid Email',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }
                      if (!_isPasswordValid(password)) {
                        AlertInfo.show(
                          context: context,
                          text: 'Password must be at least 6 characters',
                          typeInfo: TypeInfo.error,
                          iconColor: Colors.white,
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          position: MessagePosition.top,
                        );
                        return;
                      }

                      setState(() => _isUploading = true);
                      try {
                        if (_selectedFile != null) {
                          _uploadedImageUrl = await _uploadToCloudinary(_selectedFile!);
                        }

                        final dob = DateTime(
                          int.parse(_yearController.text),
                          int.parse(_monthController.text),
                          int.parse(_dayController.text),
                        );

                        final newStudent = StudentsModel(
                          studentId: editingStudent?.studentId ?? '',
                          admissionNo: int.parse(_admissionController.text),
                          rollNo: int.parse(_rollController.text),
                          studentName: _nameController.text,
                          mobileNo: _mobileController.text,
                          email: _emailController.text,
                          password: _passwordController.text,
                          address: _addressController.text,
                          parentName: _parentController.text,
                          classNo: int.parse(_classNo ?? '0'),
                          division: _division ?? 'Not',
                          teacherName: _selectedTeacherName ?? '',
                          teacherId: widget.teacherId,
                          gender: _selectedGender ?? '',
                          delete: false,
                          imageUrl: _uploadedImageUrl ?? '',
                          dateOfBirth: dob,
                          createdDate: editingStudent?.createdDate ?? DateTime.now(),
                          schoolId: SessionManager.schoolId,
                          language: _languageController.text.trim(),
                          clubs_nss_ncc: _clubsController.text.trim(),
                        );

                        final studentCollectionRef = FirebaseFirestore.instance.schoolCollection(FirebaseConstant.student);
                        final classRepo = ref.read(classWiseTeacherRepoProvider);
                        String studentId = '';
                        if (editingStudent != null) {
                          studentId = editingStudent!.studentId;
                          await studentCollectionRef.doc(studentId).update(newStudent.toMap());

                          await classRepo.syncStudentToClass(
                            oldClassNo: _classNoToString(editingStudent!.classNo),
                            oldDivision: editingStudent!.division,
                            newClassNo: _classNoToString(newStudent.classNo),
                            newDivision: newStudent.division,
                            studentId: studentId,
                            studentName: newStudent.studentName,
                            imageUrl: newStudent.imageUrl,
                            rollNo: newStudent.rollNo,
                          );
                        } else {
                          final doc = await studentCollectionRef.add(newStudent.toMap());
                          studentId = doc.id;
                          await doc.update({'studentId': studentId});

                          await classRepo.syncStudentToClass(
                            newClassNo: _classNoToString(newStudent.classNo),
                            newDivision: newStudent.division,
                            studentId: studentId,
                            studentName: newStudent.studentName,
                            imageUrl: newStudent.imageUrl,
                            rollNo: newStudent.rollNo,
                          );
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          AlertInfo.show(
                            context: context,
                            text: editingStudent != null ? 'Student updated successfully' : 'Student added successfully',
                            typeInfo: TypeInfo.success,
                            iconColor: Colors.white,
                            backgroundColor: const Color(0xFF27AE60),
                            textColor: Colors.white,
                            position: MessagePosition.top,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AlertInfo.show(
                            context: context,
                            text: "Error: $e",
                            typeInfo: TypeInfo.error,
                            iconColor: Colors.white,
                            backgroundColor: Colors.redAccent,
                            textColor: Colors.white,
                            position: MessagePosition.top,
                          );
                        }
                      } finally {
                        setState(() => _isUploading = false);
                      }
                    },
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      editingStudent != null ? "Update Student" : "Add Student",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showStudentDetailsModal(BuildContext context, StudentsModel student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 580,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Student Profile",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Profile Picture + Name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xff1193D4).withValues(alpha: 0.2), width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: student.imageUrl.isNotEmpty
                                  ? NetworkImage(student.imageUrl)
                                  : const AssetImage(ImageConstant.temporaryStudentImage)
                              as ImageProvider,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Admission No: ${student.admissionNo}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_isClassTeacher) ...[
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Future.delayed(Duration.zero, () {
                                      _openStudentDialog(student);
                                    });
                                  },
                                  child: SvgPicture.asset(
                                    ImageConstant.editIcon,
                                    fit: BoxFit.contain,
                                    color: const Color(0xff1193D4),
                                    height: 18,
                                    width: 18,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Info Container
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          _infoRow("Admission No", "#${student.admissionNo}"),
                          _infoRow("Name", student.studentName),
                          _infoRow("Roll No", student.rollNo.toString()),
                          _infoRow("Gender", student.gender),
                          _infoRow("Class", student.classNo.toString()),
                          _infoRow("Division", student.division),
                          _infoRow("Teacher", student.teacherName),
                          _infoRow("Mobile", student.mobileNo),
                          _infoRow("Parent Name", student.parentName),
                          _infoRow("Address", student.address),
                          _infoRow("Language", student.language.isNotEmpty ? student.language : "-"),
                          _infoRow("Clubs / NSS / NCC", student.clubs_nss_ncc.isNotEmpty ? student.clubs_nss_ncc : "-"),
                          _infoRow(
                            "Date of Birth",
                            "${student.dateOfBirth.day}/${student.dateOfBirth.month}/${student.dateOfBirth.year}",
                          ),
                          _infoRow("Email", student.email),
                          _infoRow("Password", student.password),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Reusable Info Row Widget
  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "-",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Soft Delete Dialog & Function
  void _deleteStudent(BuildContext context, StudentsModel student) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Student"),
        content: Text("Are you sure you want to delete ${student.studentName}? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                // 1. Soft delete in student collection
                await FirebaseFirestore.instance
                    .schoolCollection(FirebaseConstant.student)
                    .doc(student.studentId)
                    .update({
                      'delete': true,
                      'deletedAt': FieldValue.serverTimestamp(),
                    });

                // 2. Sync to Classes collection (which decrements count)
                final classRepo = ref.read(classWiseTeacherRepoProvider);
                await classRepo.syncStudentToClass(
                  oldClassNo: _classNoToString(student.classNo),
                  oldDivision: student.division,
                  studentId: student.studentId,
                  studentName: student.studentName,
                  imageUrl: student.imageUrl,
                  rollNo: student.rollNo,
                  isDeleted: true,
                );

                if (context.mounted) {
                  AlertInfo.show(
                    context: context,
                    text: "Student deleted successfully",
                    typeInfo: TypeInfo.success,
                    iconColor: Colors.white,
                    backgroundColor: const Color(0xFF27AE60),
                    textColor: Colors.white,
                    position: MessagePosition.top,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AlertInfo.show(
                    context: context,
                    text: "Error deleting student: $e",
                    typeInfo: TypeInfo.error,
                    iconColor: Colors.white,
                    backgroundColor: Colors.redAccent,
                    textColor: Colors.white,
                    position: MessagePosition.top,
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Attendance Toggle Cycle: Unmarked (Absent/null) -> Present -> Absent -> Unmarked
  Future<void> _toggleStudentAttendance(String studentId, StudentsModel student, String? currentStatus) async {
    String newStatus;
    String newPresentDetail;

    if (currentStatus == null) {
      newStatus = "Morning & Evening";
      newPresentDetail = "Full Day";
    } else if (currentStatus == "Absent") {
      newStatus = "Unmarked";
      newPresentDetail = "";
    } else {
      newStatus = "Absent";
      newPresentDetail = "Absent";
    }

    final dateId = " ${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}";
    final docRef = FirebaseFirestore.instance.schoolCollection(FirebaseConstant.attendance).doc(dateId);

    try {
      final docSnap = await docRef.get();
      List<dynamic> attendanceList = [];
      Map<String, dynamic> docData = {};

      if (docSnap.exists) {
        docData = Map<String, dynamic>.from(docSnap.data()!);
      }

      final classKey = student.classNo.toString();
      final classDiv = student.division.isNotEmpty ? student.division.toUpperCase() : 'A';

      if (docData[classKey] != null && docData[classKey][classDiv] != null) {
        attendanceList = List<dynamic>.from(docData[classKey][classDiv]);
      }

      // Remove existing record for studentId
      attendanceList.removeWhere((item) => item['studentId'] == studentId);

      if (newStatus != "Unmarked") {
        // Add updated record
        final record = {
          'classNo': student.classNo,
          'rollNo': student.rollNo,
          'studentId': student.studentId,
          'division': student.division,
          'studentName': student.studentName,
          'teacherName': _selectedTeacherName ?? '',
          'status': newStatus,
          'presentDetail': newPresentDetail,
          'teacherId': widget.teacherId,
          'date': Timestamp.fromDate(_selectedDate),
          'schoolId': '',
        };
        attendanceList.add(record);
      }

      // Build updated payload
      if (docData[classKey] == null) {
        docData[classKey] = {};
      }
      docData[classKey][classDiv] = attendanceList;

      await docRef.set(docData, SetOptions(merge: true));
    } catch (e) {
      log("Error toggling attendance: $e");
    }
  }

  Widget _filterTab(
    String label,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    final isBlueTab = label == "All";
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff1193D4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xff1193D4) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : (isBlueTab ? Colors.grey.shade700 : activeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateId = " ${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}";

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),

      /// Floating Add Button
      floatingActionButton: _isClassTeacher
          ? FloatingActionButton(
              shape: const CircleBorder(),
              backgroundColor: const Color(0xff1193D4),
              onPressed: () {
                _openStudentDialog(); // ✅ Add Student
              },
              child: const Icon(Icons.person_add_alt_1, color: Colors.white),
            )
          : null,

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Navigation Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                            )
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        "Students & Class View",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  // Refresh Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Color(0xff1193D4)),
                      onPressed: () {
                        _fetchTeachers();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Class Teacher & Dropdowns Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLanguageTeacher
                          ? "Language Teacher: ${_selectedTeacherName ?? ''}${_teacherSubject.isNotEmpty ? ' ($_teacherSubject)' : ''}"
                          : "Class Teacher: ${_classTeacherNames["$_classNo-$_division"] ?? _selectedTeacherName ?? ''}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff1193D4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Class Overview",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // CLASS SELECTOR/DISPLAY (Dropdown)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xffF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<AssignedClass>(
                                value: _selectedClassItem,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.blue),
                                onChanged: (AssignedClass? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedClassItem = newValue;
                                      _classNo = newValue.classNo.toString();
                                      _division = newValue.division;
                                      _isClassTeacher = newValue.isClassTeacher;
                                    });
                                  }
                                },
                                items: _assignedClasses
                                    .map<DropdownMenuItem<AssignedClass>>(
                                        (AssignedClass value) {
                                  return DropdownMenuItem<AssignedClass>(
                                    value: value,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text("CLASS",
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 1),
                                        Text(
                                          value.label ??
                                              "Class ${_classNoToString(value.classNo)}-${value.division}${value.isClassTeacher ? ' (Class Teacher)' : ' (Subject Teacher)'}",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // DATE PICKER
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xffF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("DATE", style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat("MMM dd, yyyy").format(_selectedDate),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.blue),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Nested Streams for Attendance Document and Students
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .schoolCollection(FirebaseConstant.attendance)
                    .doc(dateId)
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.hasError) {
                    return Center(child: Text("Error: ${attendanceSnapshot.error}"));
                  }
                  // Map of studentId -> status
                  final attendanceMap = <String, String>{};
                  if (attendanceSnapshot.hasData && attendanceSnapshot.data!.exists) {
                    try {
                      final docData = attendanceSnapshot.data!.data() as Map<String, dynamic>;
                      if (_classNo == '999' || _division == 'All') {
                        docData.forEach((cKey, cVal) {
                          if (cVal is Map<String, dynamic>) {
                            cVal.forEach((divKey, divVal) {
                              if (divVal is List<dynamic>) {
                                for (var item in divVal) {
                                  if (item is Map && item['studentId'] != null) {
                                    attendanceMap[item['studentId'].toString()] = item['status'] ?? 'Absent';
                                  }
                                }
                              }
                            });
                          }
                        });
                      } else {
                        final classKey = _classNo ?? '0';
                        final classDiv = (_division ?? 'Not').toUpperCase();
                        if (docData[classKey] != null && docData[classKey][classDiv] != null) {
                          final list = docData[classKey][classDiv] as List<dynamic>;
                          for (var item in list) {
                            attendanceMap[item['studentId']] = item['status'] ?? 'Absent';
                          }
                        }
                      }
                    } catch (e) {
                      log("Error parsing attendance stream: $e");
                    }
                  }

                  final Query<Map<String, dynamic>> studentQuery;
                  if (_classNo == '999') {
                    studentQuery = FirebaseFirestore.instance
                        .schoolCollection(FirebaseConstant.student)
                        .where("delete", isEqualTo: false);
                  } else if (_division == 'All') {
                    studentQuery = FirebaseFirestore.instance
                        .schoolCollection(FirebaseConstant.student)
                        .where("classNo", isEqualTo: int.tryParse(_classNo ?? '0') ?? 0)
                        .where("delete", isEqualTo: false);
                  } else {
                    studentQuery = FirebaseFirestore.instance
                        .schoolCollection(FirebaseConstant.student)
                        .where("classNo", isEqualTo: int.tryParse(_classNo ?? '0') ?? 0)
                        .where("division", isEqualTo: _division ?? '')
                        .where("delete", isEqualTo: false);
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: studentQuery.snapshots(),
                    builder: (context, studentSnapshot) {
                      if (studentSnapshot.hasError) {
                        return Center(child: Text("Error: ${studentSnapshot.error}"));
                      }
                      if (!studentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = studentSnapshot.data!.docs;

                      var allStudents = docs.map((doc) {
                        return StudentsModel.fromMap(doc.data() as Map<String, dynamic>);
                      }).toList();

                      // 1. Filter by Language if Language Teacher & default filter
                      if (_isLanguageTeacher && _teacherSubject.isNotEmpty && _selectedLanguageFilter == 'All') {
                        allStudents = allStudents.where((s) {
                          if (s.language.isEmpty) return true;
                          return s.language.trim().toLowerCase() == _teacherSubject.trim().toLowerCase();
                        }).toList();
                      }

                      // 2. Filter by Class Grade (if selected from class filter chips)
                      if (_selectedClassFilter != 'All') {
                        final classVal = int.tryParse(_selectedClassFilter);
                        if (classVal != null) {
                          allStudents = allStudents.where((s) => s.classNo == classVal).toList();
                        }
                      }

                      // 3. Filter by Specific Language
                      if (_selectedLanguageFilter != 'All') {
                        allStudents = allStudents.where((s) {
                          return s.language.trim().toLowerCase().contains(_selectedLanguageFilter.trim().toLowerCase());
                        }).toList();
                      }

                      // 4. Filter by Club / Activity
                      if (_selectedClubFilter != 'All') {
                        final clubLower = _selectedClubFilter.toLowerCase();
                        allStudents = allStudents.where((s) {
                          final studentClub = s.clubs_nss_ncc.trim().toLowerCase();
                          if (clubLower == 'nss') {
                            return studentClub.contains('nss');
                          } else if (clubLower == 'ncc') {
                            return studentClub.contains('ncc');
                          } else if (clubLower == 'clubs') {
                            return studentClub.isNotEmpty;
                          } else {
                            return studentClub.contains(clubLower);
                          }
                        }).toList();
                      }

                      // 5. Filter by Gender
                      if (_selectedGenderFilter != 'All') {
                        allStudents = allStudents.where((s) {
                          return s.gender.toLowerCase() == _selectedGenderFilter.toLowerCase();
                        }).toList();
                      }

                      final totalStudents = allStudents.length;

                      // Count present and absent
                      int presentCount = 0;
                      int absentCount = 0;
                      
                      for (final s in allStudents) {
                        final status = attendanceMap[s.studentId];
                        if (status != null && status != 'Absent') {
                          presentCount++;
                        } else if (status == 'Absent') {
                          absentCount++;
                        }
                      }

                      // Client-side sorting by Class then RollNo
                      allStudents.sort((a, b) {
                        final cComp = a.classNo.compareTo(b.classNo);
                        if (cComp != 0) return cComp;
                        return a.rollNo.compareTo(b.rollNo);
                      });

                      final attendancePercentage = totalStudents > 0
                          ? ((presentCount / totalStudents) * 100).round()
                          : 0;

                      // Apply search query and attendance status filter tab
                      final query = _searchController.text.trim().toLowerCase();
                      var filteredStudents = allStudents;

                      if (query.isNotEmpty) {
                        filteredStudents = filteredStudents.where((s) {
                          return s.studentName.toLowerCase().contains(query) ||
                              s.rollNo.toString().contains(query) ||
                              s.admissionNo.toString().contains(query) ||
                              s.language.toLowerCase().contains(query);
                        }).toList();
                      }

                      if (_selectedFilter != 'All') {
                        filteredStudents = filteredStudents.where((s) {
                          final status = attendanceMap[s.studentId];
                          if (_selectedFilter == 'Present') {
                            return status != null && status != 'Absent';
                          } else {
                            return status == 'Absent';
                          }
                        }).toList();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Class Overview Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Class Overview",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${DateFormat("MMM dd, yyyy").format(_selectedDate)} • ${DateFormat("EEEE").format(_selectedDate)}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "$attendancePercentage% Attendance",
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff1193D4),
                                      ),
                                    ),
                                  ],
                                ) ,
                                const SizedBox(height: 16),
                                // Split Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 8,
                                    child: Row(
                                      children: [
                                        if (presentCount > 0)
                                          Expanded(
                                            flex: presentCount,
                                            child: Container(color: Colors.green),
                                          ),
                                        if (absentCount > 0)
                                          Expanded(
                                            flex: absentCount,
                                            child: Container(color: Colors.redAccent),
                                          ),
                                        if (presentCount == 0 && absentCount == 0)
                                          Expanded(
                                            child: Container(color: Colors.grey.shade200),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$presentCount Present",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "$absentCount Absent",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {});
                              },
                              decoration: InputDecoration(
                                hintText: "Search students or roll no ...",
                                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                                border: InputBorder.none,
                                fillColor : Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Filter Tabs (Attendance Status)
                          Row(
                            children: [
                              _filterTab("All", _selectedFilter == "All", Colors.blue, () {
                                setState(() => _selectedFilter = "All");
                              }),
                              const SizedBox(width: 10),
                              _filterTab("Present", _selectedFilter == "Present", Colors.green, () {
                                setState(() => _selectedFilter = "Present");
                              }, icon: Icons.check_circle_outline),
                              const SizedBox(width: 10),
                              _filterTab("Absent", _selectedFilter == "Absent", Colors.redAccent, () {
                                setState(() => _selectedFilter = "Absent");
                              }, icon: Icons.cancel_outlined),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Redesigned Filter Toolbar (Language & Activity/Club & Gender)
                          _buildTeacherFilterBar(allStudents),
                          const SizedBox(height: 16),
                          const SizedBox(height: 16),

                          // Students Title
                          const Text(
                            "Students Details",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),

                          // List View
                          filteredStudents.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Text("No Students Found"),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = filteredStudents[index];
                                    final attStatus = attendanceMap[student.studentId];

                                    return studentCard(
                                      student: student,
                                      attendanceStatus: attStatus,
                                      onView: () {
                                        showStudentDetailsModal(context, student);
                                      },
                                      onEdit: () {
                                        _openStudentDialog(student);
                                      },
                                      onDelete: () {
                                        _deleteStudent(context, student);
                                      },
                                      onToggleAttendance: () {
                                        _toggleStudentAttendance(student.studentId, student, attStatus);
                                      },
                                      isClassTeacher: _isClassTeacher,
                                    );
                                  },
                                ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherFilterBar(List<StudentsModel> students) {
    int activeFilterCount = 0;
    if (_selectedLanguageFilter != 'All') activeFilterCount++;
    if (_selectedClubFilter != 'All') activeFilterCount++;
    if (_selectedGenderFilter != 'All') activeFilterCount++;
    bool hasActiveFilter = activeFilterCount > 0;

    // Collect unique languages
    final langSet = <String>{'All', 'Arabic', 'Malayalam', 'Hindi', 'English', 'Sanskrit', 'Urdu'};
    for (var s in students) {
      if (s.language.isNotEmpty) langSet.add(s.language);
    }

    // Collect unique clubs / activities
    final clubList = <String>['All', 'NSS', 'NCC', 'Clubs'];
    for (var s in students) {
      final cVal = s.clubs_nss_ncc.trim();
      if (cVal.isNotEmpty) {
        for (var part in cVal.split(RegExp(r'[,/|]'))) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty &&
              trimmed.toUpperCase() != 'NSS' &&
              trimmed.toUpperCase() != 'NCC' &&
              trimmed.toLowerCase() != 'clubs' &&
              !clubList.contains(trimmed)) {
            clubList.add(trimmed);
          }
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: hasActiveFilter
                      ? const Color(0xff1193D4).withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: hasActiveFilter ? const Color(0xff1193D4) : const Color(0xFF64748B),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Filter Students",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: hasActiveFilter ? const Color(0xff1193D4) : const Color(0xFF334155),
                        fontSize: 13,
                      ),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xff1193D4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$activeFilterCount",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (hasActiveFilter)
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedLanguageFilter = 'All';
                      _selectedClubFilter = 'All';
                      _selectedGenderFilter = 'All';
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.clear_all_rounded, size: 16, color: Colors.redAccent),
                        SizedBox(width: 4),
                        Text(
                          "Reset Filters",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Language Filter Dropdown
              _buildFilterPillDropdown(
                label: "Language",
                value: _selectedLanguageFilter,
                items: langSet.toList(),
                onChanged: (val) => setState(() => _selectedLanguageFilter = val ?? 'All'),
                icon: Icons.translate_rounded,
              ),
              // Activity / Club Filter Dropdown
              _buildFilterPillDropdown(
                label: "Activity / Club",
                value: _selectedClubFilter,
                items: clubList,
                onChanged: (val) => setState(() => _selectedClubFilter = val ?? 'All'),
                icon: Icons.sports_soccer_rounded,
              ),
              // Gender Filter Dropdown
              _buildFilterPillDropdown(
                label: "Gender",
                value: _selectedGenderFilter,
                items: ['All', 'Male', 'Female'],
                onChanged: (val) => setState(() => _selectedGenderFilter = val ?? 'All'),
                icon: Icons.wc_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPillDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final isActive = value != 'All';
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xff1193D4).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xff1193D4) : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? const Color(0xff1193D4) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xff1193D4) : const Color(0xFF64748B),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : 'All',
              icon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isActive ? const Color(0xff1193D4) : const Color(0xFF64748B),
                  size: 20,
                ),
              ),
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isActive ? const Color(0xff1193D4) : const Color(0xFF0F172A),
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: item == value ? FontWeight.bold : FontWeight.normal,
                      color: item == value ? const Color(0xff1193D4) : const Color(0xFF1E293B),
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

Widget studentCard({
  required StudentsModel student,
  required String? attendanceStatus,
  required VoidCallback onView,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onToggleAttendance,
  required bool isClassTeacher,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: attendanceStatus == null
                  ? Colors.grey.shade300
                  : (attendanceStatus == "Absent" ? Colors.redAccent : Colors.green),
              width: 6,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            /// 🔹 Profile Image + Status Badge on bottom right
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: isClassTeacher ? onToggleAttendance : null,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: student.imageUrl.isNotEmpty
                        ? NetworkImage(student.imageUrl)
                        : const AssetImage(ImageConstant.temporaryStudentImage)
                              as ImageProvider,
                  ),
                ),
                if (attendanceStatus != null)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: attendanceStatus == "Absent" ? Colors.redAccent : Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        attendanceStatus == "Absent" ? Icons.close : Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),

                /// Roll Number Badge on top left
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xff4C6FFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "#${student.rollNo}",
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            /// 🔹 Name + Roll
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        "Roll No. #${student.rollNo.toString().padLeft(3, '0')}",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: attendanceStatus == null
                              ? Colors.grey.shade100
                              : (attendanceStatus == "Absent"
                                  ? const Color(0xffFEE2E2)
                                  : const Color(0xffDCFCE7)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          attendanceStatus ?? "Unmarked",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: attendanceStatus == null
                                ? Colors.grey.shade600
                                : (attendanceStatus == "Absent"
                                    ? Colors.red.shade700
                                    : Colors.green.shade700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// 🔹 Actions (View, Edit, Delete)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Profile Icon
                Container(
                  height: 36,
                  width: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xff1193D4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove_red_eye, size: 16, color: Colors.white),
                    onPressed: onView,
                  ),
                ),
                if (isClassTeacher) ...[
                  const SizedBox(width: 8),

                  // Edit Icon
                  Container(
                    height: 36,
                    width: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xffEEF3FF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Color(0xff1193D4)),
                      onPressed: onEdit,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Delete Icon
                  Container(
                    height: 36,
                    width: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xffFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
