import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';

import '../../../../core/constant/image_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../teachers/controller/teacher_controller.dart';
import '../controller/class_wise_teacher_view_controller.dart';
import 'teacherViewDashbord.dart';

class ClassWiseTeacherViewScreen extends ConsumerStatefulWidget {
  const ClassWiseTeacherViewScreen({super.key});

  @override
  ConsumerState<ClassWiseTeacherViewScreen> createState() =>
      _ClassWiseTeacherViewScreenState();
}

class _ClassWiseTeacherViewScreenState
    extends ConsumerState<ClassWiseTeacherViewScreen> {
  final Map<int, bool> _expanded = {};
  bool _initialized = false;

  // Controllers for Editing
  final _teacherIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _subjectController = TextEditingController();
  final _addressController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String? _selectedClass;
  String? _selectedDiv;
  String? _selectedGender;
  TeacherModel? editingTeacher;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateTeacherCredentials);
    _teacherIdController.addListener(_updateTeacherCredentials);
  }

  void _updateTeacherCredentials() {
    if (editingTeacher == null) {
      final name = _nameController.text.trim();
      final id = _teacherIdController.text.trim();
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
    _teacherIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _subjectController.dispose();
    _addressController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _showAssignmentDialog({TeacherModel? teacher}) {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedTeacherId = teacher?.id;
        String? selectedTeacherName = teacher?.teacherName;

        String? selectedGrade = teacher?.classNo != 0 ? teacher?.classNo.toString() : null;
        String? selectedDivision = teacher?.division != "Nil" ? teacher?.division : null;

        // ✅ Grades 5–12
        final grades = List.generate(8, (i) => (i + 5).toString());

        // ✅ Divisions A–N
        final allDivisions = [
          "A","B","C","D","E","F","G","H",
          "I","J","K","L","M","N"
        ];

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        Icon(teacher == null ? Icons.person_add_alt_1 : Icons.edit_calendar_rounded,
                            color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text(
                          teacher == null ? "Assign New Teacher" : "Update Assignment",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),

                    const SizedBox(height: 20),

                    // TEACHER SELECTION (Only show if not editing a specific teacher)
                    if (teacher == null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Teacher",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection(FirebaseConstant.teacher)
                            .where("classNo", isEqualTo: 0)
                            .where("delete", isEqualTo: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final docs = snapshot.data!.docs;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedTeacherId,
                                hint: const Text("Choose a teacher"),
                                isExpanded: true,
                                items: docs.map((doc) {
                                  final name = doc.data()["teacherName"] ?? "";
                                  return DropdownMenuItem(
                                    value: doc.id,
                                    child: Text(name),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  final teacherDoc = docs.firstWhere((e) => e.id == val);
                                  setState(() {
                                    selectedTeacherId = val;
                                    selectedTeacherName = teacherDoc["teacherName"];
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      // Show Current Teacher Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: teacher.imageUrl.isNotEmpty
                                  ? NetworkImage(teacher.imageUrl)
                                  : const AssetImage(ImageConstant.temporaryTeacherImage) as ImageProvider,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher.teacherName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    teacher.subject,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // GRADE + DIVISION
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Select Grade"),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedGrade,
                                    hint: const Text("Grade"),
                                    isExpanded: true,
                                    items: grades.map((g) => DropdownMenuItem(value: g, child: Text("Grade $g"))).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        selectedGrade = val;
                                        selectedDivision = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Select Division"),
                              const SizedBox(height: 8),
                              if (selectedGrade == null)
                                const Text("Select Grade First")
                              else
                                StreamBuilder(
                                  stream: FirebaseFirestore.instance
                                      .collection(FirebaseConstant.teacher) // Check assigned divisions
                                      .where("classNo", isEqualTo: int.parse(selectedGrade!))
                                      .where("delete", isEqualTo: false)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();

                                    final usedDivisions = snapshot.data!.docs
                                        .where((doc) => doc.id != selectedTeacherId) // Exclude current teacher
                                        .map((doc) => doc["division"].toString())
                                        .toList();

                                    final availableDivisions = allDivisions.where((d) => !usedDivisions.contains(d)).toList();

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedDivision,
                                          hint: const Text("Division"),
                                          isExpanded: true,
                                          items: availableDivisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                          onChanged: (val) => setState(() => selectedDivision = val),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            onPressed: () async {
                              if (selectedTeacherId == null || selectedGrade == null || selectedDivision == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select all fields")));
                                return;
                              }

                              await FirebaseFirestore.instance
                                  .collection(FirebaseConstant.teacher)
                                  .doc(selectedTeacherId)
                                  .update({
                                "classNo": int.parse(selectedGrade!),
                                "division": selectedDivision,
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Assignment updated for $selectedTeacherName")),
                              );
                            },
                            child: Text(teacher == null ? "Assign" : "Update"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ===================================================
            /// TOP HEADER (Title + Button)
            /// ===================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// Title Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Classroom Management",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Overview of teaching assignments and grade structures.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),

                /// Assign Teacher Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2F80ED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () {
                    _showAssignmentDialog();
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text(
                    "Assign teacher",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            /// ===================================================
            /// MAIN LISTVIEW (Dropdown Grades)
            /// ===================================================
            Expanded(
              child: teachersAsync.when(
                data: (teachers) {

                  // ✅ REAL COUNTS
                  final totalStaff = teachers.length;

                  final assignedStaff =
                      teachers.where((t) => t.classNo != 0).length;

                  if (teachers.isEmpty) {
                    return const Center(child: Text("No teachers found."));
                  }

                  /// 🔹 GROUP TEACHERS BY CLASS
                  final Map<int, List<TeacherModel>> classGroups = {};
                  for (final t in teachers) {
                    classGroups.putIfAbsent(t.classNo, () => []).add(t);
                  }

                  /// 🔹 SORT CLASSES (class 0 goes LAST)
                  final List<int> sortedClassList = classGroups.keys
                      .where((c) => c != 0)
                      .toList()
                    ..sort();

                  if (classGroups.containsKey(0)) {
                    sortedClassList.add(0);
                  }

                  /// 🔹 AUTO EXPAND FIRST CLASS
                  if (!_initialized && sortedClassList.isNotEmpty) {
                    _expanded[sortedClassList.first] = true;
                    _initialized = true;
                  }

                  return ListView.builder(
                    itemCount: sortedClassList.length + 1,
                    itemBuilder: (context, index) {
                      /// ===================================================
                      /// BOTTOM STAFF CARDS
                      /// ===================================================
                      if (index == sortedClassList.length) {
                        return _buildBottomStaffCards(
                          totalStaff: totalStaff,
                          assignedStaff: assignedStaff,
                        );
                      }
                      
                      final classNo = sortedClassList[index];
                      final classTeachers = classGroups[classNo]!
                        ..sort((a, b) => a.division.compareTo(b.division));

                      final bool isOtherClass = classNo == 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// HEADER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor:
                                      const Color(0xffEAF4FF),
                                      child: Text(
                                        isOtherClass ? "O" : "$classNo",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff2F80ED),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isOtherClass
                                              ? "Other Teachers"
                                              : "Grade $classNo",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          isOtherClass
                                          ? '${classTeachers.length} Teachers'
                                          : "${classTeachers.length} Sections",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                IconButton(
                                  icon: Icon(
                                    _expanded[classNo] == true
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(() {
                                    _expanded[classNo] =
                                    !(_expanded[classNo] ?? false);
                                  }),
                                )
                              ],
                            ),

                            /// TEACHERS
                            if (_expanded[classNo] == true) ...[
                              const SizedBox(height: 18),

                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: classTeachers.map((teacher) {
                                    return _buildTeacherCard(
                                      teacher,
                                      isOtherClass,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ]
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text("Error: $e")),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick image
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  /// Email validation
  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  /// Password validation (min 6 chars)
  bool _isPasswordValid(String password) {
    return password.length >= 6;
  }

  /// Build TextField with validation icon
  Widget _buildTextFieldWithValidation(TextEditingController controller, String label,
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

  /// Dropdown
  Widget _buildDropdown(
      String hint,
      String? value,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14))))
          .toList(),
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

  /// Phone field
  Widget _buildPhoneField() {
    return Row(
      children: [
        Container(
          width: 70,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(
            child: Text(
              '+91',
              style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Date of Birth Field
  Widget _buildDateOfBirthField() {
    return Row(
      children: [
        Expanded(child: _buildTextFieldWithValidation(_dayController, "DD", inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextFieldWithValidation(_monthController, "MM", inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextFieldWithValidation(_yearController, "YYYY", inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],)),
      ],
    );
  }

  /// Add/Edit Modal Sheet
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
                color: Colors.black.withOpacity(0.15),
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
                    editingTeacher == null ? 'Add New Teacher' : 'Edit Teacher Profile',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                /// Profile Image
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
                              color: Colors.black.withOpacity(0.08),
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
                              : (_uploadedImageUrl != null
                              ? NetworkImage(_uploadedImageUrl!)
                              : const AssetImage(
                            ImageConstant.temporaryTeacherImage,
                          )
                          as ImageProvider),
                        ),
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
                _buildTextFieldWithValidation(_teacherIdController, "Employee ID"),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_nameController, "Name", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_subjectController, "Subject", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        "Class",
                        _selectedClass,
                        ['5', '6', '7', '8', '9', '10', '11', '12', '0'],
                            (v) {
                          setState(() => _selectedClass = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        "Division",
                        _selectedDiv,
                        ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'Nil'],
                            (v) {
                          setState(() => _selectedDiv = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) {
                  setState(() => _selectedGender = v);
                }),
                const SizedBox(height: 14),
                _buildPhoneField(),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(
                  _emailController,
                  "Email",
                  isEmail: true,
                  readOnly: true,
                ),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(
                  _passwordController,
                  "Password",
                  isPassword: true,
                  readOnly: true,
                ),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_addressController, "Address", inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s]")),
                ]),
                const SizedBox(height: 16),
                const Text(
                  "Date of Birth",
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildDateOfBirthField(),
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

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        setState(() => _isUploading = false);
                      }
                    },
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      editingTeacher != null ? 'Update Teacher' : 'Add Teacher',
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

  Widget _buildTeacherCard(TeacherModel teacher, bool isOtherClass) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffF9FBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child:Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: teacher.imageUrl.isNotEmpty
                        ? NetworkImage(teacher.imageUrl)
                        : const AssetImage(
                      ImageConstant.temporaryTeacherImage,
                    ) as ImageProvider,
                  ),
                ),

                Positioned(
                  top: 0,
                  right: 0,
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAssignmentDialog(teacher: teacher);
                      } else if (value == 'remove') {
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
                                  Icon(Icons.person_remove_rounded, color: Colors.orange.shade400, size: 48),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Remove Assignment",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Are you sure you want to remove ${teacher.teacherName} from Grade ${teacher.classNo} - ${teacher.division}?",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
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
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await FirebaseFirestore.instance
                                                .collection(FirebaseConstant.teacher)
                                                .doc(teacher.id)
                                                .update({
                                              "classNo": 0,
                                              "division": "Nil",
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("${teacher.teacherName} moved to unassigned staff")),
                                            );
                                          },
                                          child: const Text("Remove"),
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
                            Icon(Icons.edit_calendar_rounded,
                                size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Reassign'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_rounded,
                                size: 16, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Remove'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),


          GestureDetector(
            onTap: () => _showAssignmentDialog(teacher: teacher),
            child: Text(
              teacher.teacherName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 4),

          if (!isOtherClass)
            GestureDetector(
              onTap: () => _showAssignmentDialog(teacher: teacher),
              child: Text(
                "SECTION ${teacher.division}",
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xff2F80ED),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffEEF6FF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.push(
                  '/admin/classrooms/teacher-dashboard/${teacher.id}',
                );
              },
              child: const Text(
                "View Details",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff2F80ED),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  /// ===================================================
  /// BOTTOM STAFF COUNT CARDS
  /// ===================================================
  Widget _buildBottomStaffCards({
    required int totalStaff,
    required int assignedStaff,
  }) {
    final percent =
    totalStaff == 0 ? 0 : ((assignedStaff / totalStaff) * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 25),
      child: Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              title: "TOTAL STAFF COUNT",
              value: totalStaff.toString(),
              subtitle: "All active teachers",
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _buildInfoCard(
              title: "ASSIGNED STAFF COUNT",
              value: assignedStaff.toString(),
              subtitle: "$percent% Assigned",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
