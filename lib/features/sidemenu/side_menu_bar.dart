import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:scholo_admin/features/teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:searchfield/searchfield.dart';
import '../../core/config/session_manager.dart';

import '../../core/cloudinaryServies/cloudinary_service.dart';
import '../../core/constant/image_constant.dart';
import '../../models/students_model.dart';
import '../../models/teacher_model.dart';
import '../teachers/controller/teacher_controller.dart';
import '../../models/class_model.dart';
import '../../models/school_model.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';
import '../../auth/controller/login_controller.dart';
import 'package:alert_info/alert_info.dart';

class AdminPanel extends ConsumerStatefulWidget {
  final Widget child;
  const AdminPanel({super.key, required this.child});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel> {
  final SideMenuController _sideMenuController = SideMenuController();

  late Future<List<Map<String, String>>> _searchDataFuture;

  final GlobalKey _profileKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();

    _searchDataFuture = _fetchSearchItems(); // ✅ cache search data once

    _nameController.addListener(_updateGeneratedCredentials);
    _admissionController.addListener(_updateGeneratedCredentials);
    _teacherIdController.addListener(_updateGeneratedCredentials);
  }

  void _updateGeneratedCredentials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _emailController.clear();
      _passwordController.clear();
      return;
    }

    final firstName = name.split(' ').first.toLowerCase();

    // Check if we are in Student Add mode
    if (editingStudent == null && _admissionController.text.isNotEmpty) {
      final id = _admissionController.text.trim();
      _emailController.text = "$firstName$id@scholo.com";
      _passwordController.text = "$firstName@$id";
    }
    // Check if we are in Teacher Add mode
    else if (editingTeacher == null && _teacherIdController.text.isNotEmpty) {
      final id = _teacherIdController.text.trim();
      _emailController.text = "$firstName$id@scholo.com";
      _passwordController.text = "$firstName@$id";
    }
  }

  @override
  void dispose() {
    _hideProfileTooltip();
    super.dispose();
  }

  void _showProfileTooltip() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      return;
    }

    final RenderBox renderBox =
    _profileKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismissible background
          GestureDetector(
            onTap: _hideProfileTooltip,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: offset.dy + size.height + 10,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: AdminProfileTooltipCard(
                onClose: _hideProfileTooltip,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideProfileTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 🔹 Fetch Students & Teachers (with display info)
  Future<List<Map<String, String>>> _fetchSearchItems() async {
    final teachersSnap = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    final studentsSnap = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .get();

    final teachers = teachersSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['teacherName'] ?? '',
        'role': 'Teacher',
        'display': '${data['teacherName'] ?? ''} (Teacher)',
      };
    }).toList();

    final students = studentsSnap.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['studentName'] ?? '',
        'role': 'Student',
        'classNo': data['classNo']?.toString() ?? '',
        'division': data['division'] ?? '',
        'display':
        '${data['studentName'] ?? ''} (Class ${data['classNo'] ?? ''}${data['division'] ?? ''})',
      };
    }).toList();

    return [
      ...teachers.map((e) => e.map((key, value) => MapEntry(key, value.toString()))),
      ...students.map((e) => e.map((key, value) => MapEntry(key, value.toString()))),
    ];
  }

  /// 🔹 Handle search result
  Future<void> _handleSearchSelection(String name, BuildContext context) async {
    // Search in teachers
    final teacherQuery = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .where('teacherName', isEqualTo: name)
        .get();

    if (teacherQuery.docs.isNotEmpty) {
      showTeacherDetailsModal(
        context,
        TeacherModel.fromMap(teacherQuery.docs.first.data()),
      );
      return;
    }

    // Search in students
    final studentQuery = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.student)
        .where('studentName', isEqualTo: name)
        .get();

    if (studentQuery.docs.isNotEmpty) {
      showStudentDetailsModal(
        context,
        StudentsModel.fromMap(studentQuery.docs.first.data()),
      );
      return;
    }

    AlertInfo.show(
      context: context,
      text: 'No match found',
      typeInfo: TypeInfo.error,
      iconColor: Colors.white,
      backgroundColor: Colors.redAccent,
      textColor: Colors.white,
      position: MessagePosition.top,
    );
  }

  /// 🔹 Logout confirmation
  Future<void> _logout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text("Logout"),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                SessionManager.schoolId = null;
                if (context.mounted) {
                  Navigator.of(context).pop();
                  context.go('/login');
                }
              },
            ),
          ],
        );
      },
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
              width: 650,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🔹 Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Student Details",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 🔹 Profile Picture + Name
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: student.imageUrl.isNotEmpty
                                ? NetworkImage(student.imageUrl)
                                : const AssetImage(ImageConstant.temporaryStudentImage)
                            as ImageProvider,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            student.studentName,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Admission No: ${student.admissionNo}",
                                style:
                                const TextStyle(fontSize: 14, color: Colors.grey),
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
                                  color: Colors.black,
                                  height: 20,
                                  width: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 🔹 Info Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
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
                          _infoRow(
                            "Date of Birth",
                            "${student.dateOfBirth.day}/${student.dateOfBirth.month}/${student.dateOfBirth.year}",
                          ),
                          _infoRow("Email", student.email),
                          _infoRow("Password", student.password),
                        ],
                      ),
                    ),

                    // 🔹 Footer Buttons
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.end,
                    //   children: [
                    //     TextButton(
                    //       onPressed: () => Navigator.pop(context),
                    //       child: const Text("Close"),
                    //     ),
                    //     const SizedBox(width: 10),
                    //     ElevatedButton.icon(
                    //       style: ElevatedButton.styleFrom(
                    //         backgroundColor: const Color(0xff1193D4),
                    //         shape: RoundedRectangleBorder(
                    //           borderRadius: BorderRadius.circular(10),
                    //         ),
                    //       ),
                    //       icon: const Icon(Icons.edit, color: Colors.white),
                    //       label: const Text("Edit",
                    //           style: TextStyle(color: Colors.white)),
                    //       onPressed: () {
                    //         Navigator.pop(context);
                    //         Future.delayed(Duration.zero, () {
                    //           _openStudentDialog(student); // reuse your existing edit modal
                    //         });
                    //       },
                    //     ),
                    //   ],
                    // ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showTeacherDetailsModal(BuildContext context, TeacherModel teacher) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 650, // center width
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🔹 Header with Edit Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Teacher Details",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 🔹 Profile Image + Name
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: teacher.imageUrl.isNotEmpty
                                ? NetworkImage(teacher.imageUrl)
                                : const AssetImage(
                              ImageConstant.temporaryTeacherImage,
                            )
                            as ImageProvider,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            teacher.teacherName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Employee ID: ${teacher.employeeId}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  Future.delayed(Duration.zero, () {
                                    _showAddEditSheet(teacher);
                                  });
                                },
                                child: SvgPicture.asset(
                                  ImageConstant.editIcon,
                                  fit: BoxFit.contain,
                                  color: Colors.black,
                                  height: 20,
                                  width: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 🔹 Details Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _infoRow("Employee Id", "#${teacher.employeeId}"),
                          _infoRow("Name", teacher.teacherName),
                          _infoRow("Gender", teacher.gender),
                          _infoRow("Class", teacher.classNo.toString()),
                          _infoRow("Division", teacher.division),
                          _infoRow("Subject", teacher.subject),
                          _infoRow("Mobile", teacher.mobileNo),
                          _infoRow("Address", teacher.address),
                          _infoRow(
                            "Date of Birth",
                            "${teacher.dateOfBirth.day}/${teacher.dateOfBirth.month}/${teacher.dateOfBirth.year}",
                          ),
                          _infoRow("Email", teacher.email),
                          _infoRow("Password", teacher.password),

                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Reusable Info Row Widget
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : "-",
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  TeacherModel? editingTeacher;

  final _teacherIdController = TextEditingController();
  final _subjectController = TextEditingController();

  String? _selectedClass;
  String? _selectedDiv;

  Widget _buildTextFieldWithValidation(
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
              if (isEmail) {
                isValid = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(v);
              }
              if (isPassword) {
                isValid = v.length >= 6;
              }
            });
          },
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: (isEmail || isPassword)
                ? (controller.text.isEmpty
                ? null
                : Icon(
              isValid ? Icons.check_circle : Icons.cancel,
              color: isValid ? Colors.green : Colors.red,
            ))
                : null,
          ),
        );
      },
    );
  }

  void _showAddEditSheet([TeacherModel? teacher]) {
    final repo = ref.read(teacherControllerProvider.notifier);

    if (teacher != null) {
      editingTeacher = teacher;
      _teacherIdController.text = teacher.employeeId;
      _nameController.text = teacher.teacherName;
      _emailController.text = teacher.email;
      _passwordController.text = teacher.password;
      _mobileController.text = teacher.mobileNo;
      _subjectController.text = teacher.subject;
      _addressController.text = teacher.address;
      _selectedClass = teacher.classNo.toString();
      _selectedDiv = teacher.division;
      _selectedGender = teacher.gender;
      _dayController.text = teacher.dateOfBirth.day.toString();
      _monthController.text = teacher.dateOfBirth.month.toString();
      _yearController.text = teacher.dateOfBirth.year.toString();
      _uploadedImageUrl = teacher.imageUrl;
    } else {
      editingTeacher = null;
      _teacherIdController.clear();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _subjectController.clear();
      _addressController.clear();
      _selectedClass = null;
      _selectedDiv = null;
      _selectedGender = null;
      _dayController.clear();
      _monthController.clear();
      _yearController.clear();
      _uploadedImageUrl = null;
      _selectedFile = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Text(
                editingTeacher == null ? 'Add Teacher' : 'Edit Teacher',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            /// Profile Image
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _selectedFile != null
                        ? FileImage(_selectedFile!)
                        : (_uploadedImageUrl != null
                        ? NetworkImage(_uploadedImageUrl!)
                        : const AssetImage(
                      ImageConstant.temporaryTeacherImage,
                    )
                    as ImageProvider),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: const Icon(Icons.edit, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_teacherIdController, "Employee ID"),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_nameController, "Name",inputFormatters: [ FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),)]),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_subjectController, "Subject",inputFormatters: [ FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),)]),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    "Class",
                    _selectedClass,
                    // List.generate(13, (i) => '${i + 5}'),
                    ['5', '6', '7', '8', '9', '10','11','12','0',],
                        (v) {
                      setState(() => _selectedClass = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDropdown(
                    "Division",
                    _selectedDiv,
                    ['A', 'B', 'C', 'D', 'E', 'F','G','H','I','J','K','L','M','N','Nil'],
                        (v) {
                      setState(() => _selectedDiv = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) {
              setState(() => _selectedGender = v);
            }),
            const SizedBox(height: 12),
            _buildPhoneField(),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_emailController, "Email",
                isEmail: true, readOnly: true),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_passwordController, "Password",
                isPassword: true, readOnly: true),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(_addressController, "Address",inputFormatters: [ FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),)]),
            const SizedBox(height: 12),
            const Text(
              "Date of Birth",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDateOfBirthField(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                final employeeId = _teacherIdController.text.trim();
                final name = _nameController.text.trim();
                final mobile = _mobileController.text.trim();
                final subject = _subjectController.text.trim();
                final address = _addressController.text.trim();
                final email = _emailController.text.trim();
                final password = _passwordController.text.trim();
                final dayStr = _dayController.text.trim();
                final monthStr = _monthController.text.trim();
                final yearStr = _yearController.text.trim();

                if (employeeId.isEmpty) {
                  AlertInfo.show(
                    context: context,
                    text: 'Employee ID cannot be empty',
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
                if (subject.isEmpty) {
                  AlertInfo.show(
                    context: context,
                    text: 'Subject cannot be empty',
                    typeInfo: TypeInfo.error,
                    iconColor: Colors.white,
                    backgroundColor: Colors.redAccent,
                    textColor: Colors.white,
                    position: MessagePosition.top,
                  );
                  return;
                }
                if (_selectedClass == null || _selectedDiv == null) {
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
                if (_selectedGender == null) {
                  AlertInfo.show(
                    context: context,
                    text: 'Please select Gender',
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
                final dayVal = int.tryParse(dayStr);
                final monthVal = int.tryParse(monthStr);
                final yearVal = int.tryParse(yearStr);
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

                setState(() => _isUploading = true);
                try {
                  if (_selectedFile != null) {
                    _uploadedImageUrl = await repo.uploadImage(
                      _selectedFile!,
                    );
                  }

                  final dob = DateTime(
                    int.parse(_yearController.text),
                    int.parse(_monthController.text),
                    int.parse(_dayController.text),
                  );

                  final teacher = TeacherModel(
                    id: editingTeacher?.id ?? '',
                    employeeId: _teacherIdController.text,
                    mobileNo: _mobileController.text,
                    teacherName: _nameController.text,
                    classNo: int.parse(_selectedClass!),
                    division: _selectedDiv!,
                    subject: _subjectController.text,
                    email: _emailController.text,
                    password: _passwordController.text,
                    address: _addressController.text,
                    gender: _selectedGender!,
                    imageUrl: _uploadedImageUrl ?? '',
                    delete: false,
                    createdDate:
                    editingTeacher?.createdDate ?? DateTime.now(),
                    dateOfBirth: dob,
                  );

                  if (editingTeacher != null) {
                    await repo.updateTeacher(teacher);
                  } else {
                    await repo.addTeacher(teacher);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    AlertInfo.show(
                      context: context,
                      text: editingTeacher != null ? 'Teacher updated successfully' : 'Teacher added successfully',
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
                  : Text(editingTeacher != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  //-----------------student-------------------

  void _openStudentDialog([StudentsModel? student])
  {
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
      _selectedGender = student.gender;
      _classNo = _classNoToString(student.classNo);
      _division = student.division;
      _selectedTeacherName = student.teacherName;
      _selectedTeacherId = student.teacherId;
      _uploadedImageUrl = student.imageUrl;
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<ClassModel> classes = ref.read(classesStreamProvider).value ?? <ClassModel>[];
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: Text(
                    editingStudent == null ? 'Add Student' : 'Edit Student',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                // Profile
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: _selectedFile != null
                            ? FileImage(_selectedFile!)
                            : (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                            ? NetworkImage(_uploadedImageUrl!)
                            : const AssetImage(ImageConstant.temporaryStudentImage)
                        as ImageProvider),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            await _pickImage();
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: const Icon(Icons.edit, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildValidatedField(_admissionController, "Admission No",inputFormatters: [FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(6)]),
                const SizedBox(height: 12),
                _buildValidatedField(_nameController, "Name",inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r"[a-zA-Z\s]"),),
                ]),
                const SizedBox(height: 12),
                _buildValidatedField(_rollController, "Roll No",inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),]),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 12),
                _buildDropdown("Gender", _selectedGender,
                    ['Male', 'Female',], (v) => setSheetState(() => _selectedGender = v)),
                const SizedBox(height: 12),
                _buildClassAndDivisionDropdowns(classes, setSheetState),
                const SizedBox(height: 12),
                _buildDateOfBirthField(),
                const SizedBox(height: 12),
                _buildValidatedField(_parentController, "Parent Name",inputFormatters: [ FilteringTextInputFormatter.allow(
                  RegExp(r"[a-zA-Z\s]"),),]),
                const SizedBox(height: 12),
                _buildValidatedField(_addressController, "Address",inputFormatters: [ FilteringTextInputFormatter.allow(
                  RegExp(r"[a-zA-Z\s]"),),]),
                const SizedBox(height: 12),
                _buildValidatedField(_emailController, "Email", isEmail: true, readOnly: true),
                const SizedBox(height: 12),
                _buildValidatedField(_passwordController, "Password",
                    isPassword: true, readOnly: true),
                const SizedBox(height: 20),

                ElevatedButton(
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
                      );

                      final studentCollectionRef = FirebaseFirestore.instance
                          .schoolCollection(FirebaseConstant.student);
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
                      setSheetState(() => _isUploading = false);
                      setState(() => _isUploading = false);
                    }
                  },
                  child: _isUploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(editingStudent != null ? "Update" : "Add"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollController = TextEditingController();
  final _admissionController = TextEditingController();
  final _parentController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  String? _selectedGender;
  String? _selectedTeacherName;
  String? _selectedTeacherId;
  String? _classNo;
  String? _division;

  List<Map<String, dynamic>> _teacherList = [];
  StudentsModel? editingStudent;


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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: (isEmail || isPassword)
              ? (controller.text.isEmpty
              ? null
              : Icon(
            isValid ? Icons.check_circle : Icons.cancel,
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
  Widget _buildDateOfBirthField() {
    return Row(
      children: [
        Expanded(child: _buildValidatedField(_dayController, "DD", inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],)),
        const SizedBox(width: 10),
        Expanded(child: _buildValidatedField(_monthController, "MM" ,inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],)),
        const SizedBox(width: 10),
        Expanded(child: _buildValidatedField(_yearController, "YYYY", inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],)),
      ],
    );
  }

  /// 🔹 Gender Dropdown
  Widget _buildDropdown(String hint, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                hint: const Text("Select Class"),
                items: uniqueClassNumbers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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
                hint: const Text("Select Division"),
                items: availableDivisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(classesStreamProvider);
    final school = ref.watch(schoolStreamProvider).asData?.value;

    final String location = GoRouterState.of(context).matchedLocation;
    int activeIndex = 0;
    if (location.startsWith('/admin/teachers')) {
      activeIndex = 1;
    } else if (location.startsWith('/admin/students')) {
      activeIndex = 2;
    } else if (location.startsWith('/admin/events')) {
      activeIndex = 3;
    } else if (location.startsWith('/admin/classrooms')) {
      activeIndex = 4;
    } else if (location.startsWith('/admin/trash')) {
      activeIndex = 5;
    } else if (location.startsWith('/admin/settings')) {
      activeIndex = 6;
    } else if (location.startsWith('/admin/notifications')) {
      activeIndex = -1;
    }

    if (activeIndex != -1 && _sideMenuController.currentPage != activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sideMenuController.changePage(activeIndex);
      });
    }

    return Scaffold(
      body: Row(
        children: [
          // 🔹 Sidebar
          Container(
            decoration: const BoxDecoration(color: Color(0xff1293d4)),
            child: SideMenu(
              controller: _sideMenuController,
              style: SideMenuStyle(
                displayMode: SideMenuDisplayMode.auto,
                openSideMenuWidth: 260,
                selectedColor: Colors.white,
                selectedIconColor: const Color(0xff1293d4),
                selectedTitleTextStyle: const TextStyle(
                  color: Color(0xff1293d4),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                unselectedIconColor: Colors.white.withValues(alpha: 0.85),
                unselectedTitleTextStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                backgroundColor: const Color(0xff1293d4),
                iconSize: 22,
                itemHeight: 52,
                itemBorderRadius: BorderRadius.circular(12),
                itemOuterPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                hoverColor: Colors.white.withValues(alpha: 0.15),
              ),
              title: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          ImageConstant.logoWithText,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      school?.schoolName ?? "Scholo Admin",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Administrator",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              items: [
                SideMenuItem(
                  title: 'Dashboard',
                  icon: const Icon(CupertinoIcons.square_split_2x2_fill),
                  onTap: (index, _) => context.go('/admin/dashboard'),
                ),
                SideMenuItem(
                  title: 'Teacher',
                  icon: const Icon(CupertinoIcons.person_alt_circle_fill),
                  onTap: (index, _) => context.go('/admin/teachers'),
                ),
                SideMenuItem(
                  title: 'Student',
                  icon: const Icon(CupertinoIcons.person_3_fill),
                  onTap: (index, _) => context.go('/admin/students'),
                ),
                SideMenuItem(
                  title: 'Events',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onTap: (index, _) => context.go('/admin/events'),
                ),
                SideMenuItem(
                  title: 'Class Rooms',
                  icon: const Icon(Icons.co_present),
                  onTap: (index, _) => context.go('/admin/classrooms'),
                ),
                SideMenuItem(
                  title: 'Trash Bin',
                  icon: const Icon(Icons.delete),
                  onTap: (index, _) => context.go('/admin/trash'),
                ),
                SideMenuItem(
                  title: 'Settings',
                  icon: const Icon(Icons.settings),
                  onTap: (index, _) => context.go('/admin/settings'),
                ),
              ],
              footer: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _logout(context),
                      hoverColor: Colors.white.withValues(alpha: 0.1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Logout",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🔹 Main Area (Top Bar + Pages)
          Expanded(
            child: Column(
              children: [
                // 🔸 Top Bar with Search
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      // 🔍 Search Field (Same Logic)
                      SizedBox(
                        height: 45,
                        width: 520,
                        child: FutureBuilder<List<Map<String, String>>>(
                          future: _searchDataFuture,
                          builder: (context, snapshot) {
                            final items = snapshot.data ?? [];
                            final isWaiting = snapshot.connectionState == ConnectionState.waiting;
                            final hasError = snapshot.hasError;

                            if (hasError) {
                              debugPrint('Error loading search data: ${snapshot.error}');
                            }

                            return SearchField(
                              suggestions: items.map((e) {
                                return SearchFieldListItem<String>(
                                  e['name']!,
                                  item: e['name'],
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        e['name']!,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      Text(
                                        e['role'] == 'Teacher'
                                            ? 'Teacher'
                                            : 'Student (${e['classNo'] ?? ''}${e['division'] ?? ''})',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                              suggestionState: Suggestion.expand,

                              hint: 'Search students, teachers, or classes...',

                              // ✅ UI Updated Here Only
                              searchInputDecoration: SearchInputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                suffixIcon: isWaiting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : (hasError
                                        ? const Icon(Icons.error_outline, color: Colors.red)
                                        : null),
                                contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30), // pill shape
                                  borderSide: BorderSide.none,
                                ),
                              ),

                              onSuggestionTap: (item) {
                                _handleSearchSelection(item.searchKey, context);
                              },
                              onSubmit: (value) {
                                _handleSearchSelection(value, context);
                              },
                            );
                          },
                        ),
                      ),

                      // ✅ Right Side Profile Section
                      Row(
                        children: [

                          // 🔔 Notification
                          GestureDetector(
                            onTap: () {
                              context.go('/admin/notifications');
                            },
                            child: const Icon(
                              Icons.notifications_none,
                              size: 26,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(width: 25),

                          // Divider like screenshot
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),

                          const SizedBox(width: 20),

                          // Profile + Name
                          GestureDetector(
                            key: _profileKey,
                            onTap: _showProfileTooltip,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xff1193D4).withValues(alpha: 0.15),
                                    backgroundImage: (school != null && school.imageUrl.isNotEmpty)
                                        ? NetworkImage(school.imageUrl) as ImageProvider
                                        : const AssetImage(ImageConstant.temporaryTeacherImage),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        school?.schoolName ?? "Scholo Admin",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        (school?.principalName ?? "Administrator").toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                          letterSpacing: 0.6,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 🔸 Main Pages
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminProfileTooltipCard extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const AdminProfileTooltipCard({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<AdminProfileTooltipCard> createState() => _AdminProfileTooltipCardState();
}

class _AdminProfileTooltipCardState extends ConsumerState<AdminProfileTooltipCard> {
  bool _isEditing = false;
  bool _showPassword = false;
  bool _isSaving = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _schoolCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _officialEmailCtrl = TextEditingController();
  String? _selectedGender;

  SchoolModel? _lastInitializedSchool;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _officialEmailCtrl.dispose();
    super.dispose();
  }

  void _initializeControllers(SchoolModel school) {
    _nameCtrl.text = school.principalName;
    _schoolCtrl.text = school.schoolName;
    _mobileCtrl.text = school.phoneNumber;
    _selectedGender = school.gender;
    _addressCtrl.text = school.schoolAddress;
    _officialEmailCtrl.text = school.officialEmail;
    _lastInitializedSchool = school;
  }

  Widget _buildField({required String label, required Widget content}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isEditing) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
          ],
          content,
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolStreamProvider);
    final school = schoolAsync.asData?.value;

    if (school != null && _lastInitializedSchool == null) {
      _initializeControllers(school);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Arrow pointing up
        Padding(
          padding: const EdgeInsets.only(right: 28.0),
          child: CustomPaint(
            size: const Size(18, 10),
            painter: _ArrowPainter(),
          ),
        ),
        Container(
          width: 320,
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: schoolAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xff1193D4)),
                ),
              ),
            ),
            error: (err, stack) => SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Error loading data',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                ),
              ),
            ),
            data: (school) {
              if (school == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'No admin profile found',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Edit Profile' : 'Admin Profile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (!_isEditing)
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 20, color: Color(0xff1193D4)),
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                              _initializeControllers(school);
                            });
                          },
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Fields Area (Scrollable to prevent overflow)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // School Logo Avatar & Code
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: const Color(0xff1193D4).withValues(alpha: 0.15),
                                  backgroundImage: school.imageUrl.isNotEmpty
                                      ? NetworkImage(school.imageUrl) as ImageProvider
                                      : const AssetImage(ImageConstant.temporaryTeacherImage),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  school.schoolCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade500,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),

                          // Badges: Status, Environment, Plan
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildBadge(
                                label: school.status.toUpperCase(),
                                color: school.status.toLowerCase() == 'active' ? Colors.green : Colors.red,
                              ),
                              _buildBadge(
                                label: school.environment.toUpperCase(),
                                color: school.environment.toLowerCase() == 'prod' ? Colors.orange : Colors.blue,
                              ),
                              _buildBadge(
                                label: school.subscriptionPlan.toUpperCase(),
                                color: const Color(0xff1193D4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // School Name
                          _buildField(
                            label: 'SCHOOL NAME',
                            content: _isEditing
                                ? TextField(
                                    controller: _schoolCtrl,
                                    decoration: _inputDecoration('School Name'),
                                  )
                                : Text(
                                    school.schoolName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // Principal Name
                          _buildField(
                            label: 'PRINCIPAL NAME',
                            content: _isEditing
                                ? TextField(
                                    controller: _nameCtrl,
                                    decoration: _inputDecoration('Principal Name'),
                                  )
                                : Text(
                                    school.principalName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // Gender
                          _buildField(
                            label: 'GENDER',
                            content: _isEditing
                                ? Row(
                                    children: [
                                      Radio<String>(
                                        value: 'Male',
                                        groupValue: _selectedGender,
                                        activeColor: const Color(0xff1193D4),
                                        onChanged: (v) => setState(() => _selectedGender = v),
                                      ),
                                      const Text('Male', style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 20),
                                      Radio<String>(
                                        value: 'Female',
                                        groupValue: _selectedGender,
                                        activeColor: const Color(0xff1193D4),
                                        onChanged: (v) => setState(() => _selectedGender = v),
                                      ),
                                      const Text('Female', style: TextStyle(fontSize: 14)),
                                    ],
                                  )
                                : Text(
                                    school.gender.isNotEmpty ? school.gender : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // Phone Number
                          _buildField(
                            label: 'PHONE NUMBER',
                            content: _isEditing
                                ? CountryPhoneField(
                                    controller: _mobileCtrl,
                                    labelText: 'Phone Number',
                                  )
                                : Text(
                                    school.phoneNumber.isNotEmpty ? school.phoneNumber : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // Official Email
                          _buildField(
                            label: 'OFFICIAL EMAIL',
                            content: _isEditing
                                ? TextField(
                                    controller: _officialEmailCtrl,
                                    decoration: _inputDecoration('Official Email'),
                                  )
                                : Text(
                                    school.officialEmail.isNotEmpty ? school.officialEmail : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // School Address
                          _buildField(
                            label: 'SCHOOL ADDRESS',
                            content: _isEditing
                                ? TextField(
                                    controller: _addressCtrl,
                                    maxLines: 2,
                                    decoration: _inputDecoration('School Address'),
                                  )
                                : Text(
                                    school.schoolAddress.isNotEmpty ? school.schoolAddress : 'Not set',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                          ),

                          // Admin Login Email (Read-Only)
                          _buildField(
                            label: 'ADMIN LOGIN EMAIL (READ-ONLY)',
                            content: _isEditing
                                ? TextField(
                                    controller: TextEditingController(text: school.email),
                                    readOnly: true,
                                    decoration: _inputDecoration('Login Email (Read-only)'),
                                  )
                                : Text(
                                    school.email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                          ),

                          // Admin Login Password (Read-Only)
                          _buildField(
                            label: 'ADMIN LOGIN PASSWORD (READ-ONLY)',
                            content: _isEditing
                                ? TextField(
                                    controller: TextEditingController(text: school.password),
                                    readOnly: true,
                                    obscureText: !_showPassword,
                                    decoration: _inputDecoration('Login Password (Read-only)').copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword ? Icons.visibility : Icons.visibility_off,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => setState(() => _showPassword = !_showPassword),
                                      ),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _showPassword ? school.password : '•••••••••',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _showPassword ? Icons.visibility : Icons.visibility_off,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () => setState(() => _showPassword = !_showPassword),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isEditing) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _isEditing = false;
                                    _initializeControllers(school);
                                  });
                                },
                          child: const Text('Cancel', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1193D4),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setState(() {
                                    _isSaving = true;
                                  });
                                  try {
                                    final updatedSchool = school.copyWith(
                                      schoolName: _schoolCtrl.text.trim(),
                                      principalName: _nameCtrl.text.trim(),
                                      gender: _selectedGender ?? '',
                                      phoneNumber: _mobileCtrl.text.trim(),
                                      officialEmail: _officialEmailCtrl.text.trim(),
                                      schoolAddress: _addressCtrl.text.trim(),
                                    );

                                    await ref.read(updateSchoolProvider)(updatedSchool);
                                    setState(() {
                                      _isEditing = false;
                                      _isSaving = false;
                                      _lastInitializedSchool = null; // force reload of new data
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _isSaving = false;
                                    });
                                    if (context.mounted) {
                                      AlertInfo.show(
                                        context: context,
                                        text: 'Failed to update profile: $e',
                                        typeInfo: TypeInfo.error,
                                        iconColor: Colors.white,
                                        backgroundColor: Colors.redAccent,
                                        textColor: Colors.white,
                                        position: MessagePosition.top,
                                      );
                                    }
                                  }
                                },
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Save', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ] else ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: widget.onClose,
                          child: const Text('Close', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
