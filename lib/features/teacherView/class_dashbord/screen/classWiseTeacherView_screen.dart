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
import '../../../../models/class_model.dart';
import '../../../../models/students_model.dart';
import '../../../teachers/controller/teacher_controller.dart';
import '../controller/class_wise_teacher_view_controller.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';

class ClassWiseTeacherViewScreen extends ConsumerStatefulWidget {
  const ClassWiseTeacherViewScreen({super.key});

  @override
  ConsumerState<ClassWiseTeacherViewScreen> createState() =>
      _ClassWiseTeacherViewScreenState();
}

class _ClassWiseTeacherViewScreenState
    extends ConsumerState<ClassWiseTeacherViewScreen> {
  final Map<String, bool> _expanded = {};
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

  void _showAssignmentDialog({
    TeacherModel? teacher,
    String? prefilledClassNo,
    String? prefilledDivision,
  }) {
    final classesAsync = ref.read(classesStreamProvider);
    final classes = classesAsync.value ?? [];

    showDialog(
      context: context,
      builder: (context) {
        String? selectedTeacherId = teacher?.id;
        String? selectedTeacherName = teacher?.teacherName;

        String? selectedGrade = teacher != null
            ? (teacher.classNo != 0 ? _classNoToString(teacher.classNo) : null)
            : prefilledClassNo;
        String? selectedDivision = teacher != null
            ? (teacher.division != "Nil" ? teacher.division : null)
            : prefilledDivision;

        final grades = classes.map((c) => c.classNo).toSet().toList();
        grades.sort(_compareClassNos);

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
                            .schoolCollection(FirebaseConstant.teacher)
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
                                    items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g == 'LKG' || g == 'UKG' ? g : "Grade $g"))).toList(),
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
                                      .schoolCollection(FirebaseConstant.teacher) // Check assigned divisions
                                      .where("classNo", isEqualTo: _classNoToInt(selectedGrade!))
                                      .where("delete", isEqualTo: false)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const CircularProgressIndicator();

                                    // Collect all divisions defined for this grade
                                    final gradeClasses = classes.where((c) => c.classNo == selectedGrade).toList();
                                    final definedDivisions = gradeClasses.map((c) => c.division).where((d) => d.isNotEmpty).toList();

                                    final usedDivisions = snapshot.data!.docs
                                        .where((doc) => doc.id != selectedTeacherId) // Exclude current teacher
                                        .map((doc) => doc["division"].toString())
                                        .toList();

                                    final availableDivisions = definedDivisions.where((d) => !usedDivisions.contains(d)).toList();

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

                              final classNoInt = _classNoToInt(selectedGrade!);
                              final oldClassNo = teacher != null && teacher.classNo != 0
                                  ? _classNoToString(teacher.classNo)
                                  : null;
                              final oldDivision = teacher != null && teacher.division != "Nil"
                                  ? teacher.division
                                  : null;

                              await FirebaseFirestore.instance
                                  .schoolCollection(FirebaseConstant.teacher)
                                  .doc(selectedTeacherId)
                                  .update({
                                "classNo": classNoInt,
                                "division": selectedDivision,
                              });

                              final repo = ref.read(classWiseTeacherRepoProvider);
                              await repo.syncTeacherToClass(
                                oldClassNo: oldClassNo,
                                oldDivision: oldDivision,
                                newClassNo: selectedGrade,
                                newDivision: selectedDivision,
                                teacherId: selectedTeacherId!,
                                teacherName: selectedTeacherName!,
                              );

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

  void _showAddClassSheet([String? classNo, List<ClassModel>? classItems]) {
    final isEditing = classNo != null && classItems != null;
    String? selectedClassNo = classNo;
    
    // Find initial class name
    String initialClassName = '';
    if (isEditing && classItems.isNotEmpty) {
      initialClassName = classItems.first.className;
    }
    final classNameController = TextEditingController(text: initialClassName);
    final divisionInputController = TextEditingController();
    
    // Divisions list state
    List<String> selectedDivisions = isEditing
        ? classItems.map((c) => c.division).toList()
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
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
                        isEditing ? 'Edit Class Details' : 'Add New Class',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dropdown for class number
                    const Text(
                      "Class Number",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      "Select Class Number",
                      selectedClassNo,
                      ['LKG', 'UKG', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
                      (v) {
                        setSheetState(() => selectedClassNo = v);
                      },
                    ),
                    const SizedBox(height: 18),

                    // Optional Class Name
                    const Text(
                      "Class Name (Optional)",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: classNameController,
                      decoration: InputDecoration(
                        hintText: selectedClassNo != null ? "Class $selectedClassNo" : "Enter class name",
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
                    const SizedBox(height: 18),

                    // Tag-based division adding field
                    const Text(
                      "Divisions",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // Currently selected divisions wrapped chips
                    if (selectedDivisions.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedDivisions.map((div) {
                          return Chip(
                            label: Text(
                              div,
                              style: const TextStyle(
                                color: Color(0xff2F80ED),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            backgroundColor: const Color(0xffEEF6FF),
                            deleteIcon: const Icon(Icons.close, size: 16, color: Color(0xff2F80ED)),
                            onDeleted: () {
                              setSheetState(() {
                                selectedDivisions.remove(div);
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: const Color(0xff2F80ED).withValues(alpha: 0.2)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Input for new division
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: divisionInputController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: "Enter division (e.g., A, B, A1)",
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
                            onSubmitted: (val) {
                              final text = val.trim().toUpperCase();
                              if (text.isNotEmpty && !selectedDivisions.contains(text)) {
                                setSheetState(() {
                                  selectedDivisions.add(text);
                                  divisionInputController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2F80ED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onPressed: () {
                            final text = divisionInputController.text.trim().toUpperCase();
                            if (text.isNotEmpty && !selectedDivisions.contains(text)) {
                              setSheetState(() {
                                selectedDivisions.add(text);
                                divisionInputController.clear();
                              });
                            }
                          },
                          child: const Text("Add"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick suggestions (clickable choice chips)
                    const Text(
                      "Suggestions",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'].map((div) {
                        final isSelected = selectedDivisions.contains(div);
                        return ChoiceChip(
                          label: Text(div),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                if (!selectedDivisions.contains(div)) {
                                  selectedDivisions.add(div);
                                }
                              } else {
                                selectedDivisions.remove(div);
                              }
                            });
                          },
                          selectedColor: const Color(0xffEEF6FF),
                          backgroundColor: const Color(0xffF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xff2F80ED) : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? const Color(0xff2F80ED).withValues(alpha: 0.3) : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Save / Cancel Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              backgroundColor: const Color(0xff1193D4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              if (selectedClassNo == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please select a Class Number")),
                                );
                                return;
                              }

                              final name = classNameController.text.trim();
                              final finalClassName = name.isEmpty ? "Class $selectedClassNo" : name;
                              final repo = ref.read(classWiseTeacherRepoProvider);

                              final initialDivisions = isEditing
                                  ? classItems.map((c) => c.division).toList()
                                  : <String>[];

                              // 1. Add new divisions
                              for (final div in selectedDivisions) {
                                if (!initialDivisions.contains(div)) {
                                  final classModel = ClassModel(
                                    classNo: selectedClassNo!,
                                    division: div,
                                    className: finalClassName,
                                    delete: false,
                                    createdDate: DateTime.now(),
                                  );
                                  await repo.addClass(classModel);
                                } else {
                                  // Update existing className if changed
                                  final existingModel = classItems!.firstWhere((c) => c.division == div, orElse: () => ClassModel(classNo: selectedClassNo!, division: div, className: finalClassName, delete: false, createdDate: DateTime.now()));
                                  if (existingModel.className != finalClassName) {
                                    await repo.updateClass(existingModel.copyWith(className: finalClassName));
                                  }
                                }
                              }

                              // 2. Remove divisions that were deleted
                              for (final oldDiv in initialDivisions) {
                                if (!selectedDivisions.contains(oldDiv)) {
                                  final existingModel = classItems!.firstWhere((c) => c.division == oldDiv, orElse: () => ClassModel(classNo: selectedClassNo!, division: oldDiv, className: finalClassName, delete: false, createdDate: DateTime.now()));
                                  if (existingModel.classId != null) {
                                    await repo.deleteClass(existingModel.classId!);
                                  }
                                }
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isEditing
                                          ? "Class updated successfully"
                                          : "Class created successfully",
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(isEditing ? "Update" : "Save Class"),
                          ),
                        ),
                      ],
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

  void _showDeleteClassDialog(String classNo, List<ClassModel> classItems) {
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
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Delete Class",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Text(
                "Are you sure you want to delete Grade $classNo?",
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
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final repo = ref.read(classWiseTeacherRepoProvider);
                        for (final c in classItems) {
                          await repo.deleteClass(c.classId!);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("$classNo deleted successfully")),
                        );
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

  String _getNextClassNo(String current) {
    if (current == 'LKG') return 'UKG';
    if (current == 'UKG') return '1';
    final currentVal = int.tryParse(current);
    if (currentVal != null) {
      return (currentVal + 1).toString();
    }
    return current;
  }

  Widget _buildInfoDisplay({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  void _showPromoteSheet(ClassModel classModel) {
    final classes = ref.read(classesStreamProvider).value ?? [];
    final teachers = ref.read(teachersProvider).value ?? [];

    // Filter target classes: non-deleted and not the current class
    final targetClasses = classes.where((c) => c.classId != classModel.classId && !c.delete).toList();
    targetClasses.sort((a, b) {
      final cmp = _compareClassNos(a.classNo, b.classNo);
      if (cmp != 0) return cmp;
      return a.division.compareTo(b.division);
    });

    if (targetClasses.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Target Classes"),
          content: const Text("Please create other classes first in Classroom Management before promoting students."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    final nextClassNo = _getNextClassNo(classModel.classNo);
    final nextDivision = classModel.division;

    // Prefill with computed target class if exists
    ClassModel? initialTargetClass = targetClasses.firstWhere(
      (c) => c.classNo == nextClassNo && c.division == nextDivision,
      orElse: () => targetClasses.first,
    );

    // We'll store selected student IDs here
    final List<String> selectedStudentIds = [];
    bool isPromoting = false;
    bool initializedSelections = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        ClassModel? selectedTargetClass = initialTargetClass;
        String? selectedTeacherIdForTargetClass = classModel.teacherId.isNotEmpty
            ? classModel.teacherId
            : selectedTargetClass?.teacherId;

        return StatefulBuilder(
          builder: (context, setSheetState) {

            return Center(
              child: Container(
                width: 600,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 14),
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
                      const Center(
                        child: Text(
                          'Promote Students',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            // Source Class (Current)
                            _buildInfoDisplay(
                              label: "Current Class",
                              value: "${classModel.classNo} - ${classModel.division} (${classModel.className.isEmpty ? 'Grade ' + classModel.classNo : classModel.className})",
                            ),
                            const SizedBox(height: 14),
                            // Select Target Class Dropdown
                            DropdownButtonFormField<ClassModel>(
                              value: selectedTargetClass,
                              items: targetClasses.map((c) {
                                return DropdownMenuItem<ClassModel>(
                                  value: c,
                                  child: Text("${c.classNo} - ${c.division} (${c.className.isEmpty ? 'Grade ' + c.classNo : c.className})"),
                                );
                              }).toList(),
                              onChanged: (newClass) {
                                setSheetState(() {
                                  selectedTargetClass = newClass;
                                  initialTargetClass = newClass;
                                  selectedTeacherIdForTargetClass = newClass?.teacherId;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Select Target Class",
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
                            const SizedBox(height: 14),
                            // Assign/Reassign Teacher Dropdown for target class
                            DropdownButtonFormField<String>(
                              value: (selectedTeacherIdForTargetClass != null && selectedTeacherIdForTargetClass!.isNotEmpty)
                                  ? selectedTeacherIdForTargetClass
                                  : null,
                              hint: const Text("Unassigned / No Teacher"),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text("Unassigned / No Teacher"),
                                ),
                                ...teachers.map((t) {
                                  final currentAssign = t.classNo != 0
                                      ? " (Assigned: ${_classNoToString(t.classNo)}-${t.division})"
                                      : " (Unassigned)";
                                  return DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text("${t.teacherName}$currentAssign"),
                                  );
                                }),
                              ],
                              onChanged: (newTeacherId) {
                                setSheetState(() {
                                  selectedTeacherIdForTargetClass = newTeacherId;
                                });
                              },
                              decoration: InputDecoration(
                                labelText: "Assigned Teacher for Target Class",
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .schoolCollection(FirebaseConstant.student)
                              .where('classNo', isEqualTo: _classNoToInt(classModel.classNo))
                              .where('division', isEqualTo: classModel.division)
                              .where('delete', isEqualTo: false)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text("Error loading students: ${snapshot.error}"));
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text("No students found in this class section."),
                                ),
                              );
                            }

                            final students = docs.map((doc) => StudentsModel.fromMap(doc.data())).toList();

                            // Populate selections on first load
                            if (!initializedSelections && students.isNotEmpty) {
                              selectedStudentIds.addAll(students.map((s) => s.studentId));
                              initializedSelections = true;
                            }

                            final allSelected = students.isNotEmpty && selectedStudentIds.length == students.length;

                            return Column(
                              children: [
                                CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 28),
                                  title: const Text(
                                    "Select All Students",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155)),
                                  ),
                                  value: allSelected,
                                  activeColor: const Color(0xff1193D4),
                                  onChanged: (val) {
                                    setSheetState(() {
                                      selectedStudentIds.clear();
                                      if (val == true) {
                                        selectedStudentIds.addAll(students.map((s) => s.studentId));
                                      }
                                    });
                                  },
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                                    itemCount: students.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final s = students[idx];
                                      final isSelected = selectedStudentIds.contains(s.studentId);
                                      return CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          s.studentName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        subtitle: Text("Roll No: ${s.rollNo} | Admission: ${s.admissionNo}"),
                                        value: isSelected,
                                        activeColor: const Color(0xff1193D4),
                                        secondary: CircleAvatar(
                                          radius: 18,
                                          backgroundImage: s.imageUrl.isNotEmpty
                                              ? NetworkImage(s.imageUrl)
                                              : const AssetImage(ImageConstant.temporaryStudentImage) as ImageProvider,
                                        ),
                                        onChanged: (val) {
                                          setSheetState(() {
                                            if (val == true) {
                                              selectedStudentIds.add(s.studentId);
                                            } else {
                                              selectedStudentIds.remove(s.studentId);
                                            }
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                  backgroundColor: const Color(0xff1193D4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: isPromoting || selectedStudentIds.isEmpty || selectedTargetClass == null
                                    ? null
                                    : () async {
                                        setSheetState(() => isPromoting = true);
                                        try {
                                          final studentCollectionRef = FirebaseFirestore.instance
                                              .schoolCollection(FirebaseConstant.student);
                                          final classRepo = ref.read(classWiseTeacherRepoProvider);

                                          // 1. Reassign/Sync Teacher if changed
                                          String finalTeacherId = selectedTargetClass!.teacherId;
                                          String finalTeacherName = selectedTargetClass!.teacherName;

                                          final oldTeacherId = selectedTargetClass!.teacherId;
                                          final newTeacherId = selectedTeacherIdForTargetClass;

                                          if (newTeacherId != oldTeacherId) {
                                            // Clear old teacher if one was assigned
                                            if (oldTeacherId.isNotEmpty) {
                                              await FirebaseFirestore.instance
                                                  .schoolCollection(FirebaseConstant.teacher)
                                                  .doc(oldTeacherId)
                                                  .update({
                                                'classNo': 0,
                                                'division': 'Nil',
                                              });
                                            }

                                            if (newTeacherId != null && newTeacherId.isNotEmpty) {
                                              final newTeacher = teachers.firstWhere((t) => t.id == newTeacherId);
                                              finalTeacherId = newTeacherId;
                                              finalTeacherName = newTeacher.teacherName;

                                              // Update new teacher's class details
                                              await FirebaseFirestore.instance
                                                  .schoolCollection(FirebaseConstant.teacher)
                                                  .doc(newTeacherId)
                                                  .update({
                                                'classNo': _classNoToInt(selectedTargetClass!.classNo),
                                                'division': selectedTargetClass!.division,
                                              });

                                              // Sync new teacher to the target class doc
                                              await classRepo.syncTeacherToClass(
                                                oldClassNo: _classNoToString(newTeacher.classNo),
                                                oldDivision: newTeacher.division,
                                                newClassNo: selectedTargetClass!.classNo,
                                                newDivision: selectedTargetClass!.division,
                                                teacherId: newTeacherId,
                                                teacherName: newTeacher.teacherName,
                                              );
                                            } else {
                                              finalTeacherId = '';
                                              finalTeacherName = '';

                                              // Clear target class teacher
                                              await classRepo.syncTeacherToClass(
                                                oldClassNo: selectedTargetClass!.classNo,
                                                oldDivision: selectedTargetClass!.division,
                                                newClassNo: '',
                                                newDivision: '',
                                                teacherId: '',
                                                teacherName: '',
                                              );
                                            }
                                          }

                                          // Fetch the current selected student details to sync correctly
                                          final studentsSnap = await studentCollectionRef.get();
                                          final selectedStudents = studentsSnap.docs
                                              .where((doc) => selectedStudentIds.contains(doc.id))
                                              .map((doc) => StudentsModel.fromMap(doc.data()))
                                              .toList();

                                          for (final s in selectedStudents) {
                                            // 1. Update Student doc in Firestore
                                            await studentCollectionRef.doc(s.studentId).update({
                                              'classNo': _classNoToInt(selectedTargetClass!.classNo),
                                              'division': selectedTargetClass!.division,
                                              'teacherId': finalTeacherId,
                                              'teacherName': finalTeacherName,
                                            });

                                            // 2. Sync to Classes subcollection/document using repo helper
                                            await classRepo.syncStudentToClass(
                                              oldClassNo: _classNoToString(s.classNo),
                                              oldDivision: s.division,
                                              newClassNo: selectedTargetClass!.classNo,
                                              newDivision: selectedTargetClass!.division,
                                              studentId: s.studentId,
                                              studentName: s.studentName,
                                              imageUrl: s.imageUrl,
                                              rollNo: s.rollNo,
                                            );
                                          }

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  "Successfully promoted ${selectedStudentIds.length} students to ${selectedTargetClass!.classNo}-${selectedTargetClass!.division}",
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text("Promotion failed: $e")),
                                            );
                                          }
                                        } finally {
                                          setSheetState(() => isPromoting = false);
                                        }
                                      },
                                child: isPromoting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text("Promote Selected"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyDivisionCard(ClassModel classModel) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.amber.shade100,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade700,
                      size: 28,
                    ),
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
                      if (value == 'promote') {
                        _showPromoteSheet(classModel);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            Icon(Icons.trending_up_rounded,
                                size: 16, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Promote'),
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
          Text(
            "Section ${classModel.division}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Unassigned",
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffFEF3C7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _showAssignmentDialog(
                  prefilledClassNo: classModel.classNo,
                  prefilledDivision: classModel.division,
                );
              },
              child: const Text(
                "Assign",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),

      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ===================================================
            /// TOP HEADER (Title + Buttons)
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

                /// Buttons Row
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
                        icon: const Icon(Icons.refresh, size: 20, color: Color(0xff1193D4)),
                        onPressed: () {
                          ref.invalidate(teachersProvider);
                          ref.invalidate(classesStreamProvider);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _showAddClassSheet();
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        "Add Class",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.white),
                      label: const Text(
                        "Assign teacher",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 25),

            /// ===================================================
            /// MAIN LISTVIEW
            /// ===================================================
            Expanded(
              child: classesAsync.when(
                data: (classes) {
                  return teachersAsync.when(
                    data: (teachers) {
                      final totalStaff = teachers.length;
                      final assignedStaff = teachers.where((t) => t.classNo != 0).length;

                      final Map<String, List<ClassModel>> classGroups = {};
                      for (final c in classes) {
                        classGroups.putIfAbsent(c.classNo, () => []).add(c);
                      }
                      
                      final sortedClassNos = classGroups.keys.toList()
                        ..sort(_compareClassNos);

                      final otherTeachers = teachers.where((t) => t.classNo == 0).toList();

                      final int classCount = sortedClassNos.length;
                      final bool hasOtherTeachers = otherTeachers.isNotEmpty;
                      final int itemCount = classCount + (hasOtherTeachers ? 1 : 0) + 1;

                      if (!_initialized && sortedClassNos.isNotEmpty) {
                        _expanded[sortedClassNos.first] = true;
                        _initialized = true;
                      }

                      if (classes.isEmpty && teachers.isEmpty) {
                        return const Center(child: Text("No classes or teachers found."));
                      }

                      return ListView.builder(
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          // 1. Bottom staff cards
                          if (index == itemCount - 1) {
                            return _buildBottomStaffCards(
                              totalStaff: totalStaff,
                              assignedStaff: assignedStaff,
                            );
                          }

                          // 2. Class cards
                          if (index < classCount) {
                            final classNo = sortedClassNos[index];
                            final listForThisClass = classGroups[classNo]!;
                            final classItem = listForThisClass.first;
                            final bool isExpanded = _expanded[classNo] == true;

                            listForThisClass.sort((a, b) => a.division.compareTo(b.division));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
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
                                            backgroundColor: const Color(0xffEAF4FF),
                                            child: Text(
                                              classNo,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xff2F80ED),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                classItem.className.isEmpty ? "Grade $classNo" : classItem.className,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "${listForThisClass.length} Sections",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                                            onPressed: () {
                                              _showAddClassSheet(classNo, listForThisClass);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                            onPressed: () {
                                              _showDeleteClassDialog(classNo, listForThisClass);
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () => setState(() {
                                              _expanded[classNo] = !isExpanded;
                                            }),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),

                                  /// TEACHERS / DIVISIONS
                                  if (isExpanded) ...[
                                    const SizedBox(height: 18),
                                    if (listForThisClass.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          "No divisions registered. Edit class to add divisions.",
                                          style: TextStyle(color: Colors.grey, fontSize: 13),
                                        ),
                                      )
                                    else
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: listForThisClass.map((c) {
                                            TeacherModel? matchingTeacher;
                                            if (c.teacherId.isNotEmpty) {
                                              for (final t in teachers) {
                                                if (t.id == c.teacherId) {
                                                  matchingTeacher = t;
                                                  break;
                                                }
                                              }
                                            }
                                            if (matchingTeacher == null) {
                                              final classNoInt = _classNoToInt(classNo);
                                              for (final t in teachers) {
                                                if (t.classNo == classNoInt && t.division == c.division) {
                                                  matchingTeacher = t;
                                                  break;
                                                }
                                              }
                                            }

                                            if (matchingTeacher != null) {
                                              return _buildTeacherCard(matchingTeacher, false, c);
                                            } else {
                                              return _buildEmptyDivisionCard(c);
                                            }
                                          }).toList(),
                                        ),
                                      ),
                                  ]
                                ],
                              ),
                            );
                          }

                          // 3. Other Teachers section
                          final bool isExpanded = _expanded["Other"] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
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
                                          backgroundColor: const Color(0xffEAF4FF),
                                          child: const Text(
                                            "O",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xff2F80ED),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Other Teachers",
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${otherTeachers.length} Teachers',
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
                                        isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () => setState(() {
                                        _expanded["Other"] = !isExpanded;
                                      }),
                                    )
                                  ],
                                ),

                                /// TEACHERS
                                if (isExpanded) ...[
                                  const SizedBox(height: 18),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: otherTeachers.map((teacher) {
                                        return _buildTeacherCard(
                                          teacher,
                                          true,
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
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text("Error: $e")),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
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
  // ignore: unused_element
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
      _selectedClass = null;
      _selectedDiv = null;
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
                _buildDateOfBirthField(context: context),
                const SizedBox(height: 14),
                StatefulBuilder(
                  builder: (context, setStateSB) {
                    return CheckboxListTile(
                      title: const Text(
                        "Is Language Teacher?",
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                      ),
                      value: _isLanguageTeacher,
                      activeColor: const Color(0xff1193D4),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setStateSB(() => _isLanguageTeacher = val ?? false);
                        setState(() => _isLanguageTeacher = val ?? false);
                      },
                    );
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
                          isLanguageTeacher: _isLanguageTeacher,
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

  Widget _buildTeacherCard(TeacherModel teacher, bool isOtherClass, [ClassModel? classModel]) {
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
                                            final oldClassNo = _classNoToString(teacher.classNo);
                                            final oldDivision = teacher.division;

                                            await FirebaseFirestore.instance
                                                .schoolCollection(FirebaseConstant.teacher)
                                                .doc(teacher.id)
                                                .update({
                                              "classNo": 0,
                                              "division": "Nil",
                                            });

                                            final repo = ref.read(classWiseTeacherRepoProvider);
                                            await repo.syncTeacherToClass(
                                              oldClassNo: oldClassNo,
                                              oldDivision: oldDivision,
                                              teacherId: teacher.id,
                                              teacherName: teacher.teacherName,
                                            );

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
                      } else if (value == 'promote') {
                        if (classModel != null) {
                          _showPromoteSheet(classModel);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
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
                      const PopupMenuItem(
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
                      if (classModel != null)
                        const PopupMenuItem(
                          value: 'promote',
                          child: Row(
                            children: [
                              Icon(Icons.trending_up_rounded,
                                  size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Promote'),
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
            color: Colors.black.withValues(alpha: 0.04),
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
