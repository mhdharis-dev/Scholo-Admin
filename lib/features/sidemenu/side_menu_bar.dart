import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_sidemenu/easy_sidemenu.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:scholo_admin/features/dashbord/screen/dashboard_screen.dart';
import 'package:scholo_admin/features/events/screen/events_screen.dart';
import 'package:scholo_admin/features/trashbin/screen/trashBin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:searchfield/searchfield.dart';

import '../../auth/screen/loginPage.dart';
import '../../core/cloudinaryServies/cloudinary_service.dart';
import '../../core/constant/image_constant.dart';
import '../../models/students_model.dart';
import '../../models/teacher_model.dart';
import '../students/screen/students_list.dart';
import '../teacherView/class_dashbord/screen/classWiseTeacherView_screen.dart';
import '../teachers/controller/teacher_controller.dart';
import '../teachers/screen/teacher_list.dart';

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key});

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel> {
  final PageController _pageController = PageController();
  final SideMenuController _sideMenuController = SideMenuController();

  late Future<List<Map<String, String>>> _searchDataFuture;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();


    _sideMenuController.addListener((index) {
      _pageController.jumpToPage(index);
    });
    _searchDataFuture = _fetchSearchItems(); // ✅ cache search data once
  }

  /// 🔹 Fetch Students & Teachers (with display info)
  Future<List<Map<String, String>>> _fetchSearchItems() async {
    final teachersSnap = await FirebaseFirestore.instance
        .collection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    final studentsSnap = await FirebaseFirestore.instance
        .collection(FirebaseConstant.student)
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
        .collection(FirebaseConstant.teacher)
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
        .collection(FirebaseConstant.student)
        .where('studentName', isEqualTo: name)
        .get();

    if (studentQuery.docs.isNotEmpty) {
      showStudentDetailsModal(
        context,
        StudentsModel.fromMap(studentQuery.docs.first.data()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No match found')),
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
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                  );
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
                    color: Colors.black.withOpacity(0.2),
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
                    color: Colors.black.withOpacity(0.2),
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
        List<TextInputFormatter>? inputFormatters,
      }) {
    bool isValid = true;
    return StatefulBuilder(
      builder: (context, setStateField) {
        return TextField(
          controller: controller,
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
            _buildTextFieldWithValidation(
              _emailController,
              "Email",
              isEmail: true,
            ),
            const SizedBox(height: 12),
            _buildTextFieldWithValidation(
                _passwordController,
                "Password",
                isPassword: true,
                inputFormatters: [LengthLimitingTextInputFormatter(8)]
            ),
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
                // Validate required fields
                if (_teacherIdController.text.isEmpty ||
                    _nameController.text.isEmpty ||
                    _mobileController.text.isEmpty ||
                    _selectedClass == null ||
                    _selectedDiv == null ||
                    _subjectController.text.isEmpty ||
                    !_isEmailValid(_emailController.text) ||
                    !_isPasswordValid(_passwordController.text) ||
                    _selectedGender == null ||
                    _addressController.text.isEmpty ||
                    _dayController.text.isEmpty ||
                    _monthController.text.isEmpty ||
                    _yearController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Fill all fields correctly"),
                    ),
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

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      _classNo = student.classNo.toString();
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
                        : (_uploadedImageUrl != null
                        ? NetworkImage(_uploadedImageUrl!)
                        : const AssetImage(ImageConstant.temporaryStudentImage)
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
            _buildValidatedField(_admissionController, "Admission No",inputFormatters: [FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(10)]),
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
                ['Male', 'Female',], (v) => setState(() => _selectedGender = v)),
            const SizedBox(height: 12),
            _buildTeacherDropdown(),
            const SizedBox(height: 12),
            _buildDateOfBirthField(),
            const SizedBox(height: 12),
            _buildValidatedField(_parentController, "Parent Name",inputFormatters: [ FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),),]),
            const SizedBox(height: 12),
            _buildValidatedField(_addressController, "Address",inputFormatters: [ FilteringTextInputFormatter.allow(
              RegExp(r"[a-zA-Z\s]"),),]),
            const SizedBox(height: 12),
            _buildValidatedField(_emailController, "Email", isEmail: true),
            const SizedBox(height: 12),
            _buildValidatedField(_passwordController, "Password",
                isPassword: true,inputFormatters: [LengthLimitingTextInputFormatter(8)]),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                if (_selectedTeacherId == null || _classNo == null || _division == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Select a valid teacher")));
                  return;
                }

                setState(() => _isUploading = true);
                try {
                  if (_selectedFile != null) {
                    _uploadedImageUrl = await _uploadToCloudinary(_selectedFile!);
                  }

                  final dob = DateTime.tryParse(
                    "${_yearController.text}-${_monthController.text}-${_dayController.text}",
                  ) ??
                      DateTime(2000, 1, 1);

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
                    classNo: int.parse(_classNo ?? '0'), // ✅ Auto-fetched from teacher
                    division: _division ?? 'Not',
                    teacherName: _selectedTeacherName ?? '',
                    teacherId: _selectedTeacherId ?? '',
                    gender: _selectedGender ?? '',
                    delete: false,
                    imageUrl: _uploadedImageUrl ?? '',
                    dateOfBirth: DateTime.tryParse(
                        "${_yearController.text}-${_monthController.text}-${_dayController.text}") ??
                        DateTime(2000, 1, 1),
                    createdDate: editingStudent?.createdDate ?? DateTime.now(),
                  );

                  final ref = FirebaseFirestore.instance
                      .collection(FirebaseConstant.student);
                  if (editingStudent != null) {
                    await ref.doc(editingStudent!.studentId).update(newStudent.toMap());
                  } else {
                    final doc = await ref.add(newStudent.toMap());
                    await doc.update({'studentId': doc.id});
                  }

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  setState(() => _isUploading = false);
                }
              },
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(editingStudent != null ? "Update" : "Add"),
            ),
          ],
        ),
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
        .collection(FirebaseConstant.teacher)
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
        List<TextInputFormatter>? inputFormatters}) {
    bool isValid = true;
    return StatefulBuilder(builder: (context, setStateField) {
      return TextField(
        controller: controller,
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
    return Row(
      children: [
        Container(
          width: 70,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Text('+91')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Mobile No',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
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
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// 🔹 Teacher Dropdown with Search + Auto Class & Division
  Widget _buildTeacherDropdown() {
    final searchController = TextEditingController();

    return DropdownButtonFormField2<String>(
      value: _selectedTeacherName,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Teacher Name',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
        ),
      ),
      dropdownSearchData: DropdownSearchData(
        searchController: searchController,
        searchInnerWidgetHeight: 60,
        searchInnerWidget: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextFormField(
            controller: searchController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              hintText: 'Search teacher...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        searchMatchFn: (item, searchValue) =>
            item.value!.toLowerCase().contains(searchValue.toLowerCase()),
      ),
      items: _teacherList
          .map((t) => DropdownMenuItem<String>(
        value: t['name'] as String,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(t['name'] as String),
            Text(
              "Class ${t['classNo']} - ${t['division']}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ))
          .toList(),
      onChanged: (v) {
        setState(() {
          final selected = _teacherList.firstWhere((t) => t['name'] == v);
          _selectedTeacherName = selected['name'];
          _selectedTeacherId = selected['id'];
          _classNo = selected['classNo'];
          _division = selected['division'];
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                openSideMenuWidth: 250,
                selectedColor: Colors.white,
                selectedIconColor: const Color(0xff1293d4),
                selectedTitleTextStyle: const TextStyle(
                  color: Color(0xff1293d4),
                  fontWeight: FontWeight.bold,
                ),
                unselectedIconColor: Colors.white,
                unselectedTitleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: const Color(0xff1293d4),
                iconSize: 20,
                itemHeight: 48,
              ),
              title: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(
                            ImageConstant.logoWithText,
                            fit: BoxFit.contain,
                            height: 115,
                            width: 115,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              items: [
                SideMenuItem(
                  title: 'Dashboard',
                  icon: const Icon(CupertinoIcons.square_split_2x2_fill),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),
                SideMenuItem(
                  title: 'Teacher',
                  icon: const Icon(CupertinoIcons.person_alt_circle_fill),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),
                SideMenuItem(
                  title: 'Student',
                  icon: const Icon(CupertinoIcons.person_3_fill),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),
                SideMenuItem(
                  title: 'Events',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),
                SideMenuItem(
                  title: 'Class Rooms',
                  icon:  Icon(Icons.co_present),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),   SideMenuItem(
                  title: 'Trash Bin',
                  icon:  Icon(Icons.delete,),
                  onTap: (index, _) => _sideMenuController.changePage(index),
                ),
              ],
              footer: Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
                        color: Colors.black.withOpacity(0.06),
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
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return const Text('Error loading search data');
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No data available');
                            }

                            final items = snapshot.data!;

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
                          const Icon(Icons.notifications_none,
                              size: 26, color: Colors.black54),

                          const SizedBox(width: 25),

                          // Divider like screenshot
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),

                          const SizedBox(width: 20),

                          // Profile + Name
                          Row(
                            children: [
                               CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.blue.withOpacity(0.5),
                                backgroundImage: AssetImage(
                                  ImageConstant.temporaryTeacherImage,
                                ),
                              ),
                              const SizedBox(width: 10),

                              const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "D.U.H.S.S THOOTHA",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "ADMINISTRATOR",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 🔸 Main Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      DashboardScreen(),
                      TeacherListScreen(),
                      StudentListScreen(),
                      EventsScreen(),
                      ClassWiseTeacherViewScreen(),
                      RecycleBinPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
