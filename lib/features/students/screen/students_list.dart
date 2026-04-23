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

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
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

  /// 🔹 Build Main UI
  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(studentControllerProvider);
    final controller = ref.read(studentControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management', style: TextStyle(color: Colors.black)),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xff1193D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openStudentDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add New Student', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: studentState.when(
          data: (students) => SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                color: Colors.white,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Adm No',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Name',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Class',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Division',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Mobile',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Teacher',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Email',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Password',style: TextStyle(fontWeight: FontWeight.w700))),
                    DataColumn(label: Text('Action',style: TextStyle(fontWeight: FontWeight.w700))),
                  ],
                  rows: students.map((student) {
                    return DataRow(cells: [
                      DataCell(Text("#${student.admissionNo.toString()}")),
                      DataCell(InkWell(child: Text(student.studentName),onTap: () => showStudentDetailsModal(context, student),)),
                      DataCell(Text(student.classNo.toString())),
                      DataCell(Text(student.division)),
                      DataCell(Text(student.mobileNo)),
                      DataCell(Text(student.teacherName)),
                      DataCell(Text(student.email)),
                      DataCell(Text(student.password)),
                      DataCell(
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.black54),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: const [
                                  Icon(Icons.edit, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                              onTap: () => Future.delayed(Duration.zero, () => _openStudentDialog(student)),
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
                              onTap: () {
                                Future.delayed(Duration.zero, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Confirm Delete"),
                                      content: const Text(
                                        "Are you sure you want to delete this student?",
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
                                            controller.deleteStudent(student.studentId); // Delete action
                                          },
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Error: $e")),
        ),
      ),
    );
  }
}
