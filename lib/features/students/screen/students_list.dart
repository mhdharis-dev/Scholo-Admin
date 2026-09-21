import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:scholo_admin/features/students/controller/student_controller.dart';
import 'package:scholo_admin/models/students_model.dart';
import 'package:scholo_admin/models/class_model.dart';
import '../../teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';
import '../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../core/constant/firebase_constant.dart';
import '../../../core/config/session_manager.dart';
import '../../../core/constant/image_constant.dart';
import 'package:alert_info/alert_info.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  const StudentListScreen({super.key});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  // Controllers
  final _searchController = TextEditingController();
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

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String _searchQuery = "";

  // Directory Filters
  String _selectedClassFilter = 'All';
  String _selectedDivisionFilter = 'All';
  String _selectedGenderFilter = 'All';
  String _selectedLanguageFilter = 'All';
  String _selectedClubFilter = 'All';

  String? _selectedGender;
  String? _selectedTeacherName;
  String? _selectedTeacherId;
  String? _classNo;
  String? _division;

  // ignore: unused_field
  List<Map<String, dynamic>> _teacherList = [];
  StudentsModel? editingStudent;

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
    _searchController.dispose();
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
    super.dispose();
  }

  /// 🔹 Fetch Teachers (with class and division)
  Future<void> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    setState(() {
      _teacherList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['teacherName'] ?? '',
          'classNo': data['classNo']?.toString() ?? '0',
          'division': data['division'] ?? 'Not',
        };
      }).toList();
    });
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

  /// 🔹 Upload Image to Cloudinary
  Future<String> _uploadToCloudinary(File file) async {
    final response = await CloudinaryService.studentProfile.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: 'student_images'),
    );
    return response.secureUrl;
  }

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  /// 🔹 Email & Password Validation
  bool _isEmailValid(String email) =>
      RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  bool _isPasswordValid(String password) => password.length >= 6;

  /// 🔹 Validated Field Widget
  Widget _buildValidatedField(TextEditingController controller, String label,
      {bool isEmail = false,
        bool isPassword = false,
        bool readOnly = false,
        List<TextInputFormatter>? inputFormatters}) {
    bool isValid = true;
    return StatefulBuilder(builder: (context, setStateField) {
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
    });
  }

  /// 🔹 Phone Number Field
  Widget _buildPhoneField() {
    return CountryPhoneField(
      controller: _mobileController,
      labelText: 'Mobile No',
    );
  }

  /// 🔹 Date of Birth Field
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
    List<StudentsModel>? students,
  }) {
    final baseLanguages = ['Arabic', 'Malayalam', 'Hindi', 'English', 'Sanskrit', 'Urdu'];
    final dynamicLanguages = <String>[...baseLanguages];

    if (students != null) {
      for (final s in students) {
        final lang = s.language.trim();
        if (lang.isNotEmpty && !dynamicLanguages.contains(lang)) {
          dynamicLanguages.add(lang);
        }
      }
    }

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
            Text(" Add new", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xff1193D4))),
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
    List<StudentsModel>? students,
  }) {
    final baseClubs = ['NSS', 'NCC', 'Computer Science Club', 'Maths Club'];
    final dynamicClubs = <String>[...baseClubs];

    if (students != null) {
      for (final s in students) {
        final club = s.clubs_nss_ncc.trim();
        if (club.isNotEmpty && !dynamicClubs.contains(club)) {
          dynamicClubs.add(club);
        }
      }
    }

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

  /// 🔹 Gender Dropdown
  Widget _buildDropdown(String hint, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      decoration: InputDecoration(
        labelText: hint,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  int _classNoToInt(String classNoStr) {
    if (classNoStr == 'LKG') return -2;
    if (classNoStr == 'UKG') return -1;
    return int.tryParse(classNoStr) ?? 0;
  }

  Widget _buildClassAndDivisionDropdowns(List<ClassModel> classes, StateSetter setSheetState) {
    final activeClasses = classes.where((c) => !c.delete).toList();
    final uniqueClassNumbers = activeClasses.map((c) => c.classNo).toSet().toList();
    uniqueClassNumbers.sort((a, b) => _classNoToInt(a).compareTo(_classNoToInt(b)));

    final availableDivisions = _classNo == null
        ? <String>[]
        : activeClasses
            .where((c) => c.classNo == _classNo)
            .map((c) => c.division)
            .toSet()
            .toList()
          ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _classNo,
                hint: Text("Class", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                items: uniqueClassNumbers.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    _classNo = v;
                    _division = null; // reset division
                    _selectedTeacherId = null;
                    _selectedTeacherName = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Class',
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _division,
                hint: Text("Division", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                items: availableDivisions.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    _division = v;
                    if (_classNo != null && _division != null) {
                      final selectedClassModel = activeClasses.firstWhere(
                        (c) => c.classNo == _classNo && c.division == _division,
                        orElse: () => ClassModel(classNo: _classNo!, division: _division!, className: '', delete: false, createdDate: DateTime.now()),
                      );
                      _selectedTeacherId = selectedClassModel.teacherId;
                      _selectedTeacherName = selectedClassModel.teacherName;
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Division',
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
              ),
            ),
          ],
        ),
        if (_selectedTeacherName != null && _selectedTeacherName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Assigned Teacher: $_selectedTeacherName",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xff1193D4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 🔹 Add/Edit Modal Sheet
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
      _classNo = _classNoToString(student.classNo);
      _division = student.division;
      _selectedTeacherName = student.teacherName;
      _selectedTeacherId = student.teacherId;
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
      _selectedTeacherName = null;
      _selectedTeacherId = null;
      _uploadedImageUrl = null;
      _selectedFile = null;
      _classNo = null;
      _division = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<ClassModel> classes = ref.read(classesStreamProvider).value ?? <ClassModel>[];
          return Center(
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
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _selectedFile != null
                                  ? FileImage(_selectedFile!)
                                  : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                                  ? NetworkImage(_uploadedImageUrl!)
                                  : const AssetImage(ImageConstant.temporaryStudentImage)
                              as ImageProvider),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                await _pickImage();
                                setSheetState(() {});
                              },
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
                    _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) => setSheetState(() => _selectedGender = v)),
                    const SizedBox(height: 14),
                    _buildClassAndDivisionDropdowns(classes, setSheetState),
                    const SizedBox(height: 14),
                    _buildDateOfBirthField(context: context, setSheetState: setSheetState),
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
                      setSheetState: setSheetState,
                      students: ref.read(studentControllerProvider).value,
                    ),
                    const SizedBox(height: 14),
                    _buildClubsDropdownField(
                      context: context,
                      controller: _clubsController,
                      setSheetState: setSheetState,
                      students: ref.read(studentControllerProvider).value,
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
                              text: 'Please select Class and Division',
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

                          // Client-side Duplicate Student Pre-Check
                          final existingStudents = ref.read(studentControllerProvider).value ?? [];
                          final currentAdmissionNo = int.tryParse(_admissionController.text.trim()) ?? 0;
                          final currentRollNo = int.tryParse(_rollController.text.trim()) ?? 0;
                          final currentEmail = _emailController.text.trim().toLowerCase();
                          final currentMobile = _mobileController.text.replaceAll(RegExp(r'\D'), '');
                          final currentClassNo = _classNoToInt(_classNo!);
                          final currentDivision = (_division ?? '').trim().toLowerCase();

                          for (final s in existingStudents) {
                            if (s.delete) continue;
                            if (editingStudent != null && (s.studentId == editingStudent!.studentId || (editingStudent!.admissionNo != 0 && s.admissionNo == editingStudent!.admissionNo))) {
                              continue; // Skip self when updating
                            }

                            final sAdmissionNo = s.admissionNo;
                            final sRollNo = s.rollNo;
                            final sEmail = s.email.trim().toLowerCase();
                            final sMobile = s.mobileNo.replaceAll(RegExp(r'\D'), '');
                            final sClassNo = s.classNo;
                            final sDivision = s.division.trim().toLowerCase();

                            String? duplicateError;
                            if (currentAdmissionNo != 0 && sAdmissionNo == currentAdmissionNo) {
                              duplicateError = 'Admission No. "#$currentAdmissionNo" is already assigned to ${s.studentName}.';
                            } else if (currentEmail.isNotEmpty && sEmail == currentEmail) {
                              duplicateError = 'Email address "${_emailController.text.trim()}" is already registered to ${s.studentName}.';
                            } else if (currentMobile.isNotEmpty && sMobile == currentMobile) {
                              duplicateError = 'Mobile number "${_mobileController.text.trim()}" is already registered to ${s.studentName}.';
                            } else if (currentRollNo != 0 && sClassNo == currentClassNo && sDivision == currentDivision && sRollNo == currentRollNo) {
                              duplicateError = 'Roll No. $currentRollNo in Class $_classNo - ${_division ?? ''} is already assigned to ${s.studentName}.';
                            }

                            if (duplicateError != null) {
                              AlertInfo.show(
                                context: context,
                                text: duplicateError,
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                          }

                          setSheetState(() => _isUploading = true);
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
                              classNo: _classNoToInt(_classNo!),
                              division: _division ?? 'Not',
                              teacherName: _selectedTeacherName ?? '',
                              teacherId: _selectedTeacherId ?? '',
                              gender: _selectedGender ?? '',
                              delete: false,
                              imageUrl: _uploadedImageUrl ?? '',
                              dateOfBirth: dob,
                              createdDate: editingStudent?.createdDate ?? DateTime.now(),
                              schoolId: SessionManager.schoolId,
                              language: _languageController.text.trim(),
                              clubs_nss_ncc: _clubsController.text.trim(),
                            );

                            final studentRepo = ref.read(studentRepositoryProvider);
                            await studentRepo.validateNoDuplicateStudent(newStudent, isUpdate: editingStudent != null);

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
                                text: editingStudent != null ? "Student updated successfully" : "Student added successfully",
                                typeInfo: TypeInfo.success,
                                iconColor: Colors.white,
                                backgroundColor: const Color(0xFF27AE60),
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              final errorMsg = e.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
                              AlertInfo.show(
                                context: context,
                                text: errorMsg,
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                            }
                          } finally {
                            setSheetState(() => _isUploading = false);
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
          );
        },
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

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: const [
          Expanded(flex: 2, child: Text('Adm No', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Class & Div', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Roll No', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Mobile', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Teacher', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 4, child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Password', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(StudentsModel student, int index, StudentController controller) {
    final isEven = index % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          // Adm No
          Expanded(
            flex: 2,
            child: Text(
              "#${student.admissionNo}",
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ),
          // Student Avatar + Name
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => showStudentDetailsModal(context, student),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: student.imageUrl.isNotEmpty
                        ? NetworkImage(student.imageUrl)
                        : const AssetImage(ImageConstant.temporaryStudentImage) as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      student.studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1193D4),
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Class
          Expanded(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${student.classNo} - ${student.division}",
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Roll No
          Expanded(
            flex: 2,
            child: Text(
              student.rollNo.toString(),
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          // Mobile
          Expanded(
            flex: 3,
            child: Text(
              student.mobileNo,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          // Teacher
          Expanded(
            flex: 3,
            child: Text(
              student.teacherName,
              style: const TextStyle(color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Email
          Expanded(
            flex: 4,
            child: Text(
              student.email,
              style: const TextStyle(color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Password
          Expanded(
            flex: 3,
            child: Text(
              student.password,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          // Action
          Expanded(
            flex: 2,
            child: Center(
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openStudentDialog(student);
                  } else if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Container(
                          width: 380,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent.shade200, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                "Confirm Delete",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Are you sure you want to delete this student? This action cannot be undone.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF475569))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await controller.deleteStudent(student.studentId);

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
                                      },
                                      child: const Text("Delete"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Redesigned Filter Bar Widget
  Widget _buildFilterBar(List<StudentsModel> students, List<ClassModel> classes) {
    int activeFilterCount = 0;
    if (_selectedClassFilter != 'All') activeFilterCount++;
    if (_selectedDivisionFilter != 'All') activeFilterCount++;
    if (_selectedGenderFilter != 'All') activeFilterCount++;
    if (_selectedLanguageFilter != 'All') activeFilterCount++;
    if (_selectedClubFilter != 'All') activeFilterCount++;
    if (_searchQuery.isNotEmpty) activeFilterCount++;

    bool hasActiveFilter = activeFilterCount > 0;

    // Collect ONLY existing added classes
    final classList = <String>[];
    for (var c in classes) {
      if (c.classNo.isNotEmpty && !classList.contains(c.classNo)) {
        classList.add(c.classNo);
      }
    }
    for (var s in students) {
      final sClassStr = _classNoToString(s.classNo);
      if (sClassStr.isNotEmpty && !classList.contains(sClassStr)) {
        classList.add(sClassStr);
      }
    }
    classList.sort((a, b) {
      int? numA = int.tryParse(a);
      int? numB = int.tryParse(b);
      if (numA != null && numB != null) return numA.compareTo(numB);
      return a.compareTo(b);
    });
    final classSet = ['All', ...classList];

    // Collect unique divisions
    final divList = <String>[];
    for (var c in classes) {
      if (c.division.isNotEmpty && !divList.contains(c.division)) divList.add(c.division);
    }
    for (var s in students) {
      if (s.division.isNotEmpty && !divList.contains(s.division)) divList.add(s.division);
    }
    divList.sort();
    final divSet = ['All', ...divList];

    // Collect unique languages
    final langSet = <String>{'All', 'Arabic', 'Malayalam', 'Hindi', 'English', 'Sanskrit', 'Urdu'};
    for (var s in students) {
      if (s.language.isNotEmpty) langSet.add(s.language);
    }

    // Collect unique clubs / activities (NSS, NCC, Clubs + custom added clubs)
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                      "Filter Directory",
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
                      _selectedClassFilter = 'All';
                      _selectedDivisionFilter = 'All';
                      _selectedGenderFilter = 'All';
                      _selectedLanguageFilter = 'All';
                      _selectedClubFilter = 'All';
                      _searchQuery = '';
                      _searchController.clear();
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
                          "Reset All Filters",
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
              // Class Filter Dropdown
              _buildFilterDropdown(
                label: "Class",
                value: _selectedClassFilter,
                items: classSet.toList(),
                onChanged: (val) => setState(() => _selectedClassFilter = val ?? 'All'),
                icon: Icons.school_outlined,
              ),
              // Division Filter Dropdown
              _buildFilterDropdown(
                label: "Division",
                value: _selectedDivisionFilter,
                items: divSet.toList(),
                onChanged: (val) => setState(() => _selectedDivisionFilter = val ?? 'All'),
                icon: Icons.grid_view_rounded,
              ),
              // Gender Filter Dropdown
              _buildFilterDropdown(
                label: "Gender",
                value: _selectedGenderFilter,
                items: ['All', 'Male', 'Female'],
                onChanged: (val) => setState(() => _selectedGenderFilter = val ?? 'All'),
                icon: Icons.wc_rounded,
              ),
              // Language Filter Dropdown
              _buildFilterDropdown(
                label: "Language",
                value: _selectedLanguageFilter,
                items: langSet.toList(),
                onChanged: (val) => setState(() => _selectedLanguageFilter = val ?? 'All'),
                icon: Icons.translate_rounded,
              ),
              // Activity / Club Filter Dropdown
              _buildFilterDropdown(
                label: "Activity / Club",
                value: _selectedClubFilter,
                items: clubList,
                onChanged: (val) => setState(() => _selectedClubFilter = val ?? 'All'),
                icon: Icons.sports_soccer_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
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

  /// 🔹 Build Main UI
  @override
  Widget build(BuildContext context) {
    ref.watch(classesStreamProvider);
    final studentState = ref.watch(studentControllerProvider);
    final controller = ref.read(studentControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Title, Subtitle, Search, Add Button)
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Students Directory',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    studentState.when(
                      data: (students) => Text(
                        'Manage and view all ${students.length} students in your school.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
                const Spacer(),

                // Search Bar
                Container(
                  width: 320,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search student, ID, class, parent...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      filled: false,
                      focusColor: Colors.transparent,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Add Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff1193D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _openStudentDialog(),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Student',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),

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
                      ref.invalidate(studentControllerProvider);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Bar
            studentState.when(
              data: (students) {
                final classes = ref.watch(classesStreamProvider).value ?? <ClassModel>[];
                return _buildFilterBar(students, classes);
              },
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 16),

            // Table Container
            Expanded(
              child: studentState.when(
                data: (students) {
                  // Filter
                  final filteredStudents = students.where((student) {
                    final query = _searchQuery.toLowerCase();
                    final matchesSearch = query.isEmpty ||
                        student.studentName.toLowerCase().contains(query) ||
                        student.admissionNo.toString().contains(query) ||
                        student.email.toLowerCase().contains(query) ||
                        student.mobileNo.contains(query) ||
                        student.teacherName.toLowerCase().contains(query) ||
                        student.parentName.toLowerCase().contains(query);

                    if (!matchesSearch) return false;

                    if (_selectedClassFilter != 'All') {
                      final studentClassStr = _classNoToString(student.classNo);
                      if (studentClassStr != _selectedClassFilter && student.classNo.toString() != _selectedClassFilter) {
                        return false;
                      }
                    }

                    if (_selectedDivisionFilter != 'All') {
                      if (student.division.toUpperCase() != _selectedDivisionFilter.toUpperCase()) {
                        return false;
                      }
                    }

                    if (_selectedGenderFilter != 'All') {
                      if (student.gender.toLowerCase() != _selectedGenderFilter.toLowerCase()) {
                        return false;
                      }
                    }

                    if (_selectedLanguageFilter != 'All') {
                      if (!student.language.toLowerCase().contains(_selectedLanguageFilter.toLowerCase())) {
                        return false;
                      }
                    }

                    if (_selectedClubFilter != 'All') {
                      final clubLower = _selectedClubFilter.toLowerCase();
                      final studentClub = student.clubs_nss_ncc.trim().toLowerCase();

                      if (clubLower == 'nss') {
                        if (!studentClub.contains('nss')) return false;
                      } else if (clubLower == 'ncc') {
                        if (!studentClub.contains('ncc')) return false;
                      } else if (clubLower == 'clubs') {
                        if (studentClub.isEmpty) return false;
                      } else {
                        if (!studentClub.contains(clubLower)) return false;
                      }
                    }

                    return true;
                  }).toList();

                  // Sort by Admission No descending (or class code)
                  filteredStudents.sort((a, b) => b.admissionNo.compareTo(a.admissionNo));

                  if (filteredStudents.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No Students Found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try modifying your search query.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1200,
                            child: Column(
                              children: [
                                // Table Header
                                _buildTableHeader(),
                                // Table Rows
                                ...List.generate(filteredStudents.length, (index) {
                                  return _buildTableRow(filteredStudents[index], index, controller);
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error loading data: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
