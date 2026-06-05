import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:scholo_admin/features/students/controller/student_controller.dart';
import 'package:scholo_admin/models/students_model.dart';
import '../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../core/constant/firebase_constant.dart';
import '../../../core/constant/image_constant.dart';

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
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  String _searchQuery = "";

  String? _selectedGender;
  String? _selectedTeacherName;
  String? _selectedTeacherId;
  String? _classNo;
  String? _division;

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
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
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

  /// 🔹 Teacher Dropdown with Search + Auto Class & Division
  Widget _buildTeacherDropdown() {
    final searchController = TextEditingController();

    return DropdownButtonFormField2<String>(
      value: _selectedTeacherName,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Teacher Name',
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
            Text(t['name'] as String, style: const TextStyle(fontSize: 14)),
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
      _selectedGender = student.gender;
      _classNo = student.classNo.toString();
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
                              : const AssetImage(ImageConstant.temporaryStudentImage)
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
                _buildValidatedField(_admissionController, "Admission No", inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10)
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
                _buildTeacherDropdown(),
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
                          classNo: int.parse(_classNo ?? '0'),
                          division: _division ?? 'Not',
                          teacherName: _selectedTeacherName ?? '',
                          teacherId: _selectedTeacherId ?? '',
                          gender: _selectedGender ?? '',
                          delete: false,
                          imageUrl: _uploadedImageUrl ?? '',
                          dateOfBirth: dob,
                          createdDate: editingStudent?.createdDate ?? DateTime.now(),
                        );

                        final ref = FirebaseFirestore.instance.collection(FirebaseConstant.student);
                        if (editingStudent != null) {
                          await ref.doc(editingStudent!.studentId).update(newStudent.toMap());
                        } else {
                          final doc = await ref.add(newStudent.toMap());
                          await doc.update({'studentId': doc.id});
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text("Error: $e")));
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
                              border: Border.all(color: const Color(0xff1193D4).withOpacity(0.2), width: 4),
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
                                      onPressed: () {
                                        Navigator.pop(context);
                                        controller.deleteStudent(student.studentId);
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

  /// 🔹 Build Main UI
  @override
  Widget build(BuildContext context) {
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
                      hintText: 'Search student, ID, class...',
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
              ],
            ),
            const SizedBox(height: 24),

            // Table Container
            Expanded(
              child: studentState.when(
                data: (students) {
                  // Filter
                  final filteredStudents = students.where((student) {
                    final query = _searchQuery.toLowerCase();
                    return student.studentName.toLowerCase().contains(query) ||
                        student.admissionNo.toString().contains(query) ||
                        student.email.toLowerCase().contains(query) ||
                        student.mobileNo.contains(query) ||
                        student.teacherName.toLowerCase().contains(query);
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
