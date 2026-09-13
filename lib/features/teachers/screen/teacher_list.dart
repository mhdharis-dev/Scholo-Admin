import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scholo_admin/core/constant/image_constant.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/class_model.dart';
import '../../teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import '../controller/teacher_controller.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';
import 'package:alert_info/alert_info.dart';

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

  String _selectedSubjectFilter = 'All';
  String _selectedClassFilter = 'All';
  String _selectedGenderFilter = 'All';
  String _selectedLanguageTeacherFilter = 'All';

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
  bool _isLanguageTeacher = false;
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
  int _classNoToInt(String classNoStr) {
    if (classNoStr == 'LKG') return -2;
    if (classNoStr == 'UKG') return -1;
    return int.tryParse(classNoStr) ?? 0;
  }

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  int _compareClassNos(String a, String b) {
    return _classNoToInt(a).compareTo(_classNoToInt(b));
  }

  Widget _buildClassAndDivisionDropdowns(List<ClassModel> classes, StateSetter setSheetState) {
    final activeClasses = classes.where((c) => !c.delete).toList();
    final uniqueClassNumbers = activeClasses.map((c) => c.classNo).toSet().toList();
    uniqueClassNumbers.sort((a, b) => _compareClassNos(a, b));

    final availableDivisions = (_selectedClass == null || _selectedClass == '0')
        ? <String>[]
        : activeClasses
            .where((c) => c.classNo == _selectedClass)
            .map((c) => c.division)
            .toSet()
            .toList()
          ..sort();

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: (_selectedClass != null && (uniqueClassNumbers.contains(_selectedClass) || _selectedClass == '0'))
                ? _selectedClass
                : null,
            hint: const Text("Select Class"),
            items: [
              const DropdownMenuItem<String>(value: '0', child: Text("Not Assigned")),
              ...uniqueClassNumbers.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
            ],
            onChanged: (v) {
              setSheetState(() {
                _selectedClass = v;
                _selectedDiv = 'Nil'; // reset division
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
            value: (_selectedDiv != null && (availableDivisions.contains(_selectedDiv) || _selectedDiv == 'Nil'))
                ? _selectedDiv
                : null,
            hint: const Text("Select Division"),
            items: [
              const DropdownMenuItem<String>(value: 'Nil', child: Text("Nil")),
              ...availableDivisions.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))),
            ],
            onChanged: (v) {
              setSheetState(() {
                _selectedDiv = v;
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
    );
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
      initialValue: value,
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
    return CountryPhoneField(
      controller: _mobileController,
      labelText: 'Mobile No',
    );
  }

  /// Date of Birth Field
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
      _isLanguageTeacher = teacher.isLanguageTeacher;
    } else {
      editingTeacher = null;
      _teacherIdController.clear();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _mobileController.clear();
      _subjectController.clear();
      _addressController.clear();
      _selectedClass = '0';
      _selectedDiv = 'Nil';
      _selectedGender = null;
      _dayController.clear();
      _monthController.clear();
      _yearController.clear();
      _uploadedImageUrl = null;
      _selectedFile = null;
      _isLanguageTeacher = false;
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
                    _buildClassAndDivisionDropdowns(classes, setSheetState),
                    const SizedBox(height: 14),
                    _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) {
                      setSheetState(() => _selectedGender = v);
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
                    _buildDateOfBirthField(context: context, setSheetState: setSheetState),
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      title: const Text(
                        "Is Language Teacher?",
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                      ),
                      value: _isLanguageTeacher,
                      activeColor: const Color(0xff1193D4),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setSheetState(() => _isLanguageTeacher = val ?? false);
                        setState(() => _isLanguageTeacher = val ?? false);
                      },
                    ),
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

                                setSheetState(() => _isUploading = true);
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
                                    classNo: _classNoToInt(_selectedClass!),
                                    division: _selectedDiv!,
                                    subject: _subjectController.text,
                                    email: _emailController.text,
                                    password: _passwordController.text,
                                    address: _addressController.text,
                                    gender: _selectedGender!,
                                    imageUrl: _uploadedImageUrl ?? '',
                                    delete: false,
                                    isLanguageTeacher: _isLanguageTeacher,
                                    createdDate:
                                        editingTeacher?.createdDate ?? DateTime.now(),
                                    dateOfBirth: dob,
                                  );

                                  final oldClassNo = editingTeacher != null && editingTeacher!.classNo != 0
                                      ? _classNoToString(editingTeacher!.classNo)
                                      : null;
                                  final oldDivision = editingTeacher != null && editingTeacher!.division != "Nil"
                                      ? editingTeacher!.division
                                      : null;

                                  String? savedTeacherId;
                                  if (editingTeacher != null) {
                                    savedTeacherId = editingTeacher!.id;
                                    await repo.updateTeacher(teacher);
                                  } else {
                                    savedTeacherId = await repo.addTeacher(teacher);
                                  }

                                  if (savedTeacherId != null && savedTeacherId.isNotEmpty) {
                                    final classRepo = ref.read(classWiseTeacherRepoProvider);

                                    // If target class already has a teacher assigned, unassign them first
                                    if (_selectedClass != '0' && _selectedDiv != 'Nil') {
                                      final targetClassDoc = classes.firstWhere(
                                        (c) => c.classNo == _selectedClass && c.division == _selectedDiv && !c.delete,
                                        orElse: () => ClassModel(
                                          classNo: _selectedClass!,
                                          division: _selectedDiv!,
                                          className: '',
                                          delete: false,
                                          createdDate: DateTime.now(),
                                        ),
                                      );

                                      if (targetClassDoc.teacherId.isNotEmpty && targetClassDoc.teacherId != savedTeacherId) {
                                        await FirebaseFirestore.instance
                                            .schoolCollection(FirebaseConstant.teacher)
                                            .doc(targetClassDoc.teacherId)
                                            .update({
                                          'classNo': 0,
                                          'division': 'Nil',
                                        });
                                      }
                                    }

                                    // Sync teacher to target class
                                    await classRepo.syncTeacherToClass(
                                      oldClassNo: oldClassNo,
                                      oldDivision: oldDivision,
                                      newClassNo: _selectedClass == '0' ? '' : _selectedClass,
                                      newDivision: _selectedDiv == 'Nil' ? '' : _selectedDiv,
                                      teacherId: savedTeacherId,
                                      teacherName: teacher.teacherName,
                                    );
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    AlertInfo.show(
                                      context: context,
                                      text: editingTeacher != null
                                          ? 'Teacher updated successfully'
                                          : 'Teacher added successfully',
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
                                      text: 'Error: $e',
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
                                editingTeacher != null ? 'Update Teacher' : 'Add Teacher',
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
                              border: Border.all(color: const Color(0xff1193D4).withValues(alpha: 0.2), width: 4),
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
                          _infoRow("Language Teacher", teacher.isLanguageTeacher ? "Yes" : "No"),
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

  Widget _buildFilterBar(List<TeacherModel> allTeachers, List<ClassModel> activeClasses) {
    int activeFilterCount = 0;
    if (_selectedSubjectFilter != 'All') activeFilterCount++;
    if (_selectedClassFilter != 'All') activeFilterCount++;
    if (_selectedGenderFilter != 'All') activeFilterCount++;
    if (_selectedLanguageTeacherFilter != 'All') activeFilterCount++;
    bool hasActiveFilter = activeFilterCount > 0;

    // Collect unique subjects dynamically
    final subjectSet = <String>{'All'};
    for (var t in allTeachers) {
      final s = t.subject.trim();
      if (s.isNotEmpty) subjectSet.add(s);
    }

    // Collect class options
    final classSet = <String>{'All', 'Not Assigned'};
    final uniqueClassNumbers = activeClasses
        .where((c) => !c.delete)
        .map((c) => c.classNo)
        .toSet()
        .toList();
    uniqueClassNumbers.sort((a, b) => _compareClassNos(a, b));
    classSet.addAll(uniqueClassNumbers);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      _selectedSubjectFilter = 'All';
                      _selectedClassFilter = 'All';
                      _selectedGenderFilter = 'All';
                      _selectedLanguageTeacherFilter = 'All';
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Subject Filter
              _buildFilterPillDropdown(
                label: "Subject",
                value: _selectedSubjectFilter,
                items: subjectSet.toList(),
                onChanged: (val) => setState(() => _selectedSubjectFilter = val ?? 'All'),
                icon: Icons.book_outlined,
              ),
              // Class Filter
              _buildFilterPillDropdown(
                label: "Class",
                value: _selectedClassFilter,
                items: classSet.toList(),
                onChanged: (val) => setState(() => _selectedClassFilter = val ?? 'All'),
                icon: Icons.class_outlined,
              ),
              // Gender Filter
              _buildFilterPillDropdown(
                label: "Gender",
                value: _selectedGenderFilter,
                items: ['All', 'Male', 'Female'],
                onChanged: (val) => setState(() => _selectedGenderFilter = val ?? 'All'),
                icon: Icons.wc_rounded,
              ),
              // Role / Language Teacher Filter
              _buildFilterPillDropdown(
                label: "Role Type",
                value: _selectedLanguageTeacherFilter,
                items: ['All', 'Language Teacher', 'General Teacher'],
                onChanged: (val) => setState(() => _selectedLanguageTeacherFilter = val ?? 'All'),
                icon: Icons.translate_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPillDropdown({
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

  @override
  Widget build(BuildContext context) {
    ref.watch(classesStreamProvider);
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
                      ref.invalidate(teacherControllerProvider);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter Toolbar Container
            teachersAsync.when(
              data: (teachers) => _buildFilterBar(teachers, ref.watch(classesStreamProvider).value ?? []),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),

            const SizedBox(height: 16),
            
            // Table Container
            Expanded(
              child: teachersAsync.when(
                data: (teachers) {
                  // Filter first
                  final filteredTeachers = teachers.where((teacher) {
                    // 1. Search Query
                    final query = _searchQuery.toLowerCase();
                    final matchesQuery = query.isEmpty ||
                        teacher.teacherName.toLowerCase().contains(query) ||
                        teacher.employeeId.toLowerCase().contains(query) ||
                        teacher.subject.toLowerCase().contains(query) ||
                        teacher.email.toLowerCase().contains(query) ||
                        teacher.mobileNo.contains(query);
                    if (!matchesQuery) return false;

                    // 2. Subject Filter
                    if (_selectedSubjectFilter != 'All') {
                      if (teacher.subject.trim().toLowerCase() != _selectedSubjectFilter.trim().toLowerCase()) {
                        return false;
                      }
                    }

                    // 3. Class Filter
                    if (_selectedClassFilter != 'All') {
                      if (_selectedClassFilter == 'Not Assigned') {
                        if (teacher.classNo != 0) return false;
                      } else {
                        final targetClassNo = _classNoToInt(_selectedClassFilter);
                        if (teacher.classNo != targetClassNo) return false;
                      }
                    }

                    // 4. Gender Filter
                    if (_selectedGenderFilter != 'All') {
                      if (teacher.gender.trim().toLowerCase() != _selectedGenderFilter.trim().toLowerCase()) {
                        return false;
                      }
                    }

                    // 5. Language Teacher Filter
                    if (_selectedLanguageTeacherFilter != 'All') {
                      if (_selectedLanguageTeacherFilter == 'Language Teacher') {
                        if (!teacher.isLanguageTeacher) return false;
                      } else if (_selectedLanguageTeacherFilter == 'General Teacher') {
                        if (teacher.isLanguageTeacher) return false;
                      }
                    }

                    return true;
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
