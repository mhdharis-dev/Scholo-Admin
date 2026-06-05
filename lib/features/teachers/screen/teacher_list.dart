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
  String _searchQuery = "";

  final _searchController = TextEditingController();
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
    _searchController.dispose();
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

  void showTeacherDetailsModal(BuildContext context, TeacherModel teacher) {
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
                    color: Colors.black.withOpacity(0.15),
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
                          "Teacher Profile",
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

                    // Profile Image + Name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xff1193D4).withOpacity(0.2), width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: teacher.imageUrl.isNotEmpty
                                  ? NetworkImage(teacher.imageUrl)
                                  : const AssetImage(
                                          ImageConstant.temporaryTeacherImage,
                                        )
                                        as ImageProvider,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            teacher.teacherName,
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
                                "Employee ID: ${teacher.employeeId}",
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
                                    _showAddEditSheet(teacher);
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

                    // Details Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          _infoRow("Employee Id", "#${teacher.employeeId}"),
                          _infoRow("Name", teacher.teacherName),
                          _infoRow("Gender", teacher.gender),
                          _infoRow("Class", teacher.classNo == 0 ? "Not Assigned" : teacher.classNo.toString()),
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
          Expanded(flex: 2, child: Text('ID', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Class & Div', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Mobile', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 4, child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 3, child: Text('Password', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
          Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTableRow(TeacherModel teacher, int index) {
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
          // ID
          Expanded(
            flex: 2,
            child: Text(
              teacher.employeeId,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ),
          // Name + Avatar
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => showTeacherDetailsModal(context, teacher),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: teacher.imageUrl.isNotEmpty
                        ? NetworkImage(teacher.imageUrl)
                        : const AssetImage(ImageConstant.temporaryTeacherImage) as ImageProvider,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      teacher.teacherName,
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
                    teacher.classNo == 0 ? "Nil" : "${teacher.classNo} - ${teacher.division}",
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
          // Subject
          Expanded(
            flex: 3,
            child: Text(
              teacher.subject,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          // Mobile
          Expanded(
            flex: 3,
            child: Text(
              teacher.mobileNo,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
          ),
          // Email
          Expanded(
            flex: 4,
            child: Text(
              teacher.email,
              style: const TextStyle(color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Password
          Expanded(
            flex: 3,
            child: Text(
              teacher.password,
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
                    _showAddEditSheet(teacher);
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
                                "Are you sure you want to delete this teacher? This action cannot be undone.",
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
                                      onPressed: () {
                                        Navigator.pop(context);
                                        ref.read(teacherControllerProvider.notifier).deleteTeacher(teacher.id);
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

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teacherControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
                      'Teachers Directory',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    teachersAsync.when(
                      data: (teachers) => Text(
                        'Manage and view all ${teachers.length} teachers in your school.',
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
                      hintText: 'Search teacher, ID, subject...',
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
                  onPressed: () => _showAddEditSheet(),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Teacher',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Table Container
            Expanded(
              child: teachersAsync.when(
                data: (teachers) {
                  // Filter first
                  final filteredTeachers = teachers.where((teacher) {
                    final query = _searchQuery.toLowerCase();
                    return teacher.teacherName.toLowerCase().contains(query) ||
                        teacher.employeeId.toLowerCase().contains(query) ||
                        teacher.subject.toLowerCase().contains(query) ||
                        teacher.email.toLowerCase().contains(query) ||
                        teacher.mobileNo.contains(query);
                  }).toList();

                  // Sort
                  filteredTeachers.sort((a, b) {
                    final classComparison = a.classNo.compareTo(b.classNo);
                    if (classComparison != 0) return classComparison;
                    return a.division.compareTo(b.division);
                  });

                  if (filteredTeachers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No Teachers Found',
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
                          color: Colors.black.withOpacity(0.02),
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
                                ...List.generate(filteredTeachers.length, (index) {
                                  return _buildTableRow(filteredTeachers[index], index);
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
