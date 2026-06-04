import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../core/constant/image_constant.dart';
import '../../../../models/students_model.dart';

class TeacherScreenStudentList extends StatefulWidget {
  final String teacherId; // ✅ TeacherId from previous page

  const TeacherScreenStudentList({super.key, required this.teacherId});

  @override
  State<TeacherScreenStudentList> createState() =>
      _TeacherScreenStudentListState();
}

class _TeacherScreenStudentListState extends State<TeacherScreenStudentList> {
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

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  String? _selectedGender;
  String? _selectedTeacherName;
  String? _selectedTeacherId;
  String? _classNo;
  String? _division;

  StudentsModel? editingStudent;

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  /// 🔹 Fetch Teachers List
  Future<void> _fetchTeachers() async {
    final doc = await FirebaseFirestore.instance
        .collection(FirebaseConstant.teacher)
        .doc(widget.teacherId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;

      setState(() {
        _selectedTeacherId = widget.teacherId;
        _selectedTeacherName = data['teacherName'] ?? '';
        _classNo = data['classNo']?.toString();
        _division = data['division'];
      });
    }
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
      },
    );
  }

  /// 🔹 Phone Field
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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
      value: value,
      items: items.map((e) {
        return DropdownMenuItem(value: e, child: Text(e));
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

  /// 🔹 Open Add/Edit Modal
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                              : const AssetImage(
                                      ImageConstant.temporaryStudentImage,
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
            _buildValidatedField(
              _admissionController,
              "Admission No",
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 12),
            _buildValidatedField(
              _nameController,
              "Name",
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
              ],
            ),
            const SizedBox(height: 12),
            _buildValidatedField(
              _rollController,
              "Roll No",
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
            ),
            const SizedBox(height: 12),
            _buildPhoneField(),
            const SizedBox(height: 12),
            _buildDropdown("Gender", _selectedGender, [
              'Male',
              'Female',
            ], (v) => setState(() => _selectedGender = v)),
            const SizedBox(height: 12),
            _buildDateOfBirthField(),
            const SizedBox(height: 12),
            _buildValidatedField(
              _parentController,
              "Parent Name",
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
              ],
            ),
            const SizedBox(height: 12),
            _buildValidatedField(
              _addressController,
              "Address",
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
              ],
            ),
            const SizedBox(height: 12),
            _buildValidatedField(_emailController, "Email", isEmail: true),
            const SizedBox(height: 12),
            _buildValidatedField(
              _passwordController,
              "Password",
              isPassword: true,
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                      if (_classNo == null || _division == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Teacher data not loaded"),
                          ),
                        );
                        return;
                      }
                      setState(() => _isUploading = true);
                      try {
                        if (_selectedFile != null) {
                          _uploadedImageUrl = await _uploadToCloudinary(
                            _selectedFile!,
                          );
                        }

                        final dob =
                            DateTime.tryParse(
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
                          classNo: int.parse(
                            _classNo ?? '0',
                          ), // ✅ Auto-fetched from teacher
                          division: _division ?? 'Not',
                          teacherName: _selectedTeacherName ?? '',
                          teacherId: widget.teacherId,
                          gender: _selectedGender ?? '',
                          delete: false,
                          imageUrl: _uploadedImageUrl ?? '',
                          dateOfBirth:
                              DateTime.tryParse(
                                "${_yearController.text}-${_monthController.text}-${_dayController.text}",
                              ) ??
                              DateTime(2000, 1, 1),
                          createdDate:
                              editingStudent?.createdDate ?? DateTime.now(),
                        );

                        final ref = FirebaseFirestore.instance.collection(
                          FirebaseConstant.student,
                        );
                        if (editingStudent != null) {
                          await ref
                              .doc(editingStudent!.studentId)
                              .update(newStudent.toMap());
                        } else {
                          final doc = await ref.add(newStudent.toMap());
                          await doc.update({'studentId': doc.id});
                        }

                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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

  /// ✅ Student Details Popup Modal
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

                    // 🔹 Profile Picture + Name
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: student.imageUrl.isNotEmpty
                                ? NetworkImage(student.imageUrl)
                                : const AssetImage(
                                        ImageConstant.temporaryStudentImage,
                                      )
                                      as ImageProvider,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Admission No: ${student.admissionNo}",
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
                                    showStudentDetailsModal(context, student);
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

  //===========================================================
  //====================== UI BUILD ============================
  //===========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),

      /// Floating Add Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4C6FFF),
        onPressed: () {
          _openStudentDialog(); // ✅ Add Student
        },
        child: const Icon(Icons.add),
      ),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// 🔹 Left: Assigned Teacher
                  Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xffEEF3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xff4C6FFF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ASSIGNED TEACHER",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTeacherName ?? "Loading...",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  /// 🔹 Right: Date + Class Filter (UI only)
                  Row(
                    children: [
                      /// Date Button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "October 24, 2023",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// Class Filter Button
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.filter_list,
                              size: 14,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6),
                            Text("All Classes", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Students Details",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            /// ✅ REALTIME STUDENT LIST
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(FirebaseConstant.student)
                    .where("teacherId", isEqualTo: widget.teacherId)
                    .where("delete", isEqualTo: false)
                    .orderBy("rollNo")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text("No Students Found"));
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final student = StudentsModel.fromMap(
                        docs[index].data() as Map<String, dynamic>,
                      );

                      return studentCard(
                        student: student,
                        onView: () {
                          showStudentDetailsModal(context, student);
                        },
                        onEdit: () {
                          _openStudentDialog(student);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget studentCard({
  required StudentsModel student,
  required VoidCallback onView,
  required VoidCallback onEdit,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        /// 🔹 Profile Image + Roll Badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: student.imageUrl.isNotEmpty
                  ? NetworkImage(student.imageUrl)
                  : const AssetImage(ImageConstant.temporaryStudentImage)
                        as ImageProvider,
            ),

            /// Roll Number Badge
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

        /// 🔹 Name + Pills
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.studentName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                children: [
                  /// Class Pill
                  pillWidget(
                    text: "Class ${student.classNo}-${student.division}",
                    bg: const Color(0xffEEF3FF),
                    textColor: const Color(0xff4C6FFF),
                  ),

                  const SizedBox(width: 8),

                  /// Status Pill
                  pillWidget(
                    text: "Active",
                    bg: Colors.green.withOpacity(0.15),
                    textColor: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),

        /// 🔹 View Profile
        TextButton.icon(
          onPressed: onView,
          icon: const Icon(
            Icons.remove_red_eye_outlined,
            size: 18,
            color: Colors.grey,
          ),
          label: const Text(
            "View profile",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),

        const SizedBox(width: 6),

        /// 🔹 Edit Button
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: const Color(0xffEEF3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Color(0xff4C6FFF)),
            onPressed: onEdit,
          ),
        ),
      ],
    ),
  );
}

Widget pillWidget({
  required String text,
  required Color bg,
  required Color textColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
    ),
  );
}
