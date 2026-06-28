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
import '../../../../core/constant/image_constant.dart';
import '../../../../models/students_model.dart';
import '../../../../models/teacher_model.dart';
import 'package:alert_info/alert_info.dart';

class AssignedClass {
  final int classNo;
  final String division;
  final bool isClassTeacher;

  AssignedClass({
    required this.classNo,
    required this.division,
    required this.isClassTeacher,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignedClass &&
          runtimeType == other.runtimeType &&
          classNo == other.classNo &&
          division == other.division;

  @override
  int get hashCode => classNo.hashCode ^ division.hashCode;
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

      setState(() {
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

  Widget _buildDateOfBirthField() {
    return Row(
      children: [
        Expanded(
          child: _buildValidatedField(
            _dayController,
            "DD",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildValidatedField(
            _monthController,
            "MM",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildValidatedField(
            _yearController,
            "YYYY",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ),
      ],
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
                _buildDateOfBirthField(),
                const SizedBox(height: 14),
                _buildValidatedField(_parentController, "Parent Name", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                _buildValidatedField(_addressController, "Address", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
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

      final classKey = _classNo ?? '0';
      final classDiv = (_division ?? 'Not').toUpperCase();

      if (docData[classKey] != null && docData[classKey][classDiv] != null) {
        attendanceList = List<dynamic>.from(docData[classKey][classDiv]);
      }

      // Remove existing record for studentId
      attendanceList.removeWhere((item) => item['studentId'] == studentId);

      if (newStatus != "Unmarked") {
        // Add updated record
        final record = {
          'classNo': int.parse(_classNo ?? '0'),
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
                      "Class Teacher: ${_classTeacherNames["$_classNo-$_division"] ?? _selectedTeacherName ?? ''}",
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
                      final classKey = _classNo ?? '0';
                      final classDiv = (_division ?? 'Not').toUpperCase();
                      if (docData[classKey] != null && docData[classKey][classDiv] != null) {
                        final list = docData[classKey][classDiv] as List<dynamic>;
                        for (var item in list) {
                          attendanceMap[item['studentId']] = item['status'] ?? 'Absent';
                        }
                      }
                    } catch (e) {
                      log("Error parsing attendance stream: $e");
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .schoolCollection(FirebaseConstant.student)
                        .where("classNo", isEqualTo: int.tryParse(_classNo ?? '0') ?? 0)
                        .where("division", isEqualTo: _division ?? '')
                        .where("delete", isEqualTo: false)
                        .snapshots(),
                    builder: (context, studentSnapshot) {
                      if (studentSnapshot.hasError) {
                        return Center(child: Text("Error: ${studentSnapshot.error}"));
                      }
                      if (!studentSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = studentSnapshot.data!.docs;
                      final totalStudents = docs.length;

                      // Count present and absent
                      int presentCount = 0;
                      int absentCount = 0;
                      
                      final allStudents = docs.map((doc) {
                        final s = StudentsModel.fromMap(doc.data() as Map<String, dynamic>);
                        final status = attendanceMap[s.studentId];
                        if (status != null && status != 'Absent') {
                          presentCount++;
                        } else if (status == 'Absent') {
                          absentCount++;
                        }
                        return s;
                      }).toList();

                      // Client-side sorting by rollNo
                      allStudents.sort((a, b) => a.rollNo.compareTo(b.rollNo));

                      final attendancePercentage = totalStudents > 0
                          ? ((presentCount / totalStudents) * 100).round()
                          : 0;

                      // Apply search query and filter tab
                      final query = _searchController.text.trim().toLowerCase();
                      var filteredStudents = allStudents;

                      if (query.isNotEmpty) {
                        filteredStudents = filteredStudents.where((s) {
                          return s.studentName.toLowerCase().contains(query) ||
                              s.rollNo.toString().contains(query);
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

                          // Filter Tabs
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
