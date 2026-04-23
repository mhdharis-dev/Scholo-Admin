import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scholo_admin/core/constant/image_constant.dart';
import '../../../../models/teacher_model.dart';
import '../controller/teacher_controller.dart';

class TeacherListScreen extends ConsumerStatefulWidget {
  const TeacherListScreen({super.key});

  @override
  ConsumerState<TeacherListScreen> createState() => _TeacherListScreenState();
}

class _TeacherListScreenState extends ConsumerState<TeacherListScreen> {
  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

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

  String? _selectedClass;
  String? _selectedDiv;
  String? _selectedGender;
  TeacherModel? editingTeacher;

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
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Phone field
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

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teacherControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Management',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Color(0xff1193D4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadiusGeometry.all(Radius.circular(10)),
                ),
              ),
              onPressed: () => _showAddEditSheet(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add New Teacher',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: teachersAsync.when(
          data: (teachers) {
            // 🔹 Sort teachers by class first, then by division alphabetically
            teachers.sort((a, b) {
              final classComparison = a.classNo.compareTo(b.classNo);
              if (classComparison != 0) return classComparison;
              return a.division.compareTo(b.division);
            });

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  color: Colors.white,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Text(
                          'ID',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Name',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Class',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Division',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Subject',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Mobile',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Email',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Password',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Action',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    rows: List.generate(teachers.length, (index) {
                      final teacher = teachers[index];
                      return DataRow(
                        cells: [
                          DataCell(Text(teacher.employeeId)),
                          DataCell(
                            InkWell(
                              onTap: () => showTeacherDetailsModal(context, teacher),
                              child: Text(teacher.teacherName),
                            ),
                          ),
                          DataCell(Text(teacher.classNo.toString())),
                          DataCell(Text(teacher.division)),
                          DataCell(Text(teacher.subject)),
                          DataCell(Text(teacher.mobileNo)),
                          DataCell(Text(teacher.email)),
                          DataCell(Text(teacher.password)),
                          DataCell(
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAddEditSheet(teacher);
                                }else if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: const Text(
                                        "Are you sure you want to delete this teacher?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context); // Close dialog
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context); // Close dialog

                                            // ✅ Delete Teacher
                                            ref
                                                .read(teacherControllerProvider.notifier)
                                                .deleteTeacher(teacher.id);
                                          },
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit, size: 18, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
