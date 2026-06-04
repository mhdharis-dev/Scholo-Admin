// lib/features/teacherView/class_dashbord/screen/teacherdashbord_screen.dart
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:printing/printing.dart';
import 'package:scholo_admin/features/teacherView/mark/screen/folderPage_screen.dart';
import 'package:scholo_admin/features/teacherView/report/screen/year_wise_report.dart';
import 'package:scholo_admin/features/teacherView/students/screen/teacherScreenStudentList.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../../../../core/constant/image_constant.dart';
import '../../../../models/otherTeacher_model.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/otherFiles_model.dart';
import '../../timetable_otherFiles/screen/tableAndOtherFilesPage_Screen.dart';
import '../controller/teacherdashbord_controller.dart';
import '../../attendance/screen/attendance_page.dart';
import '../../fee/screen/fee_list.dart';
import '../../fee/screen/fee_collection.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;

class TeacherDashbordScreen extends ConsumerStatefulWidget {
  final String teacherId;
  const TeacherDashbordScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherDashbordScreen> createState() =>
      _TeacherDashbordScreenState();
}

class _TeacherDashbordScreenState extends ConsumerState<TeacherDashbordScreen> {
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    if (ts is DateTime) {
      return "${ts.day}/${ts.month}/${ts.year}";
    }
    return ts.toString();
  }

  void _showAddFeeBottomSheet(TeacherModel teacher) async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    List<Map<String, dynamic>> studentList = [];

    // Fetch students under teacher
    final snapshot = await FirebaseFirestore.instance
        .collection(FirebaseConstant.student)
        .where("delete", isEqualTo: false)
        .where("teacherId", isEqualTo: teacher.id)
        .get();

    studentList = snapshot.docs.map((doc) {
      return {
        "name": doc["studentName"],
        "id": doc["studentId"],
        "status": "unpaid",
        "collected": false,
      };
    }).toList();

    int totalAmount = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Container(
                width: 480,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Add Fee",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Description with Suggestions
                      _descriptionField(
                        context: context,
                        controller: descriptionController,
                        onSelectSuggestion: (selected) async {
                          final snap = await FirebaseFirestore.instance
                              .collection(FirebaseConstant.fees)
                              .doc(selected)
                              .get();

                          if (snap.exists) {
                            final map = snap.data();
                            final mapped =
                                map![teacher.classNo
                                    .toString()][teacher.division];

                            amountController.text = mapped["fee"].toString();
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // Amount
                      _buildTextField(
                        amountController,
                        "Amount (per student)",
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        onChanged: (txt) {
                          setState(() {
                            final per = int.tryParse(txt) ?? 0;
                            totalAmount = per * studentList.length;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _rowInfo(
                              "Class:",
                              "${teacher.classNo} ${teacher.division}",
                            ),
                            _rowInfo("Teacher:", teacher.teacherName),
                            _rowInfo(
                              "Students:",
                              studentList.length.toString(),
                            ),
                            const SizedBox(height: 4),
                            _rowInfo(
                              "Total Amount:",
                              "₹$totalAmount",
                              valueColor: Colors.green,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1193D4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            if (descriptionController.text.isEmpty ||
                                amountController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Fill all fields"),
                                ),
                              );
                              return;
                            }

                            final fee = FeeModel(
                              description: descriptionController.text.trim(),
                              fee: double.parse(amountController.text),
                              totalAmount: 0,
                              classNo: teacher.classNo,
                              collectedCount: 0,
                              division: teacher.division,
                              teacherName: teacher.teacherName,
                              teacherId: teacher.id,
                              delete: false,
                              completed: false,
                              createdDate: DateTime.now(),
                              students: studentList,
                            );

                            await ref.read(saveFeeProvider)(fee);

                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Add Fee",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    double width = double.infinity,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    onChanged,
  }) {
    return SizedBox(
      height: 65,
      width: width,
      child: TextFormField(
        onChanged: onChanged,
        controller: controller,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label, // 👈 FLOATING LABEL
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Color(0xFF5E6777),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _rowInfo(
    String label,
    String value, {
    Color valueColor = Colors.black,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.black)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionField({
    required BuildContext context,
    required TextEditingController controller,
    required Function(String) onSelectSuggestion,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final suggestionsAsync = ref.watch(feeDescriptionsProvider);

        return suggestionsAsync.when(
          data: (list) {
            final suggestions = list
                .where(
                  (item) => item.toLowerCase().contains(
                    controller.text.toLowerCase(),
                  ),
                )
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TEXT FIELD
                TextFormField(
                  controller: controller,
                  onChanged: (_) {
                    (context as Element).markNeedsBuild();
                  },
                  decoration: InputDecoration(
                    labelText: "Description",
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    labelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF5E6777),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                  ),
                ),

                // SUGGESTION LIST — shows only when typing
                if (controller.text.isNotEmpty && suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: suggestions.map((suggestion) {
                        return ListTile(
                          dense: true,
                          title: Text(suggestion),
                          onTap: () {
                            controller.text = suggestion;
                            onSelectSuggestion(suggestion);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xff1193D4)),
          ),
          error: (e, _) => Text("Error: $e"),
        );
      },
    );
  }

  //--------------------other teacher----------------------
  void _showAddTeacherBottomSheet(
    TeacherModel mainTeacher, {
    OtherTeacherModel? editTeacher, // ✅ for edit mode
  }) async {
    TeacherModel? selectedSubstituteTeacher;

    bool isPermanent = editTeacher?.isPermanent ?? true;

    final subjectController = TextEditingController(
      text: editTeacher?.subject ?? "",
    );

    TeacherModel? selectedTeacher;

    final substitutedByController = TextEditingController(
      text: editTeacher?.substitutedBy ?? "",
    );
    String substitutedId = editTeacher?.substitutedId ?? '';
    String substituteMobileNo = editTeacher?.substitutedMobileNo?.toString() ?? '';
    String substituteImageUrl = editTeacher?.substitutedImageUrl ?? '';

    DateTime? substitutedDate = editTeacher?.substitutedDate;

    // ✅ Fetch Teachers List
    final snapshot = await FirebaseFirestore.instance
        .collection(FirebaseConstant.teacher)
        .where("delete", isEqualTo: false)
        .get();

    final allTeachers = snapshot.docs
        .map((e) => TeacherModel.fromMap(e.data()))
        .toList();

    // Preselect substitute teacher if editing
    if (editTeacher != null && editTeacher.substitutedId != null) {
      final matches = allTeachers.where((t) => t.id == editTeacher.substitutedId);
      if (matches.isNotEmpty) {
        selectedSubstituteTeacher = matches.first;
      }
    }

    /// ✅ Already added teacher IDs
    final existingIds =
        mainTeacher.otherTeachers?.map((e) => e.teacherId).toList() ?? [];

    /// ✅ Filter teachers
    final teacherList = allTeachers.where((t) {
      // allow same teacher when editing
      if (editTeacher != null && t.id == editTeacher.teacherId) {
        return true;
      }

      return t.id != widget.teacherId && !existingIds.contains(t.id);
    }).toList();

    /// ✅ Preselect teacher when editing
    if (editTeacher != null) {
      final matches = allTeachers.where((t) => t.id == editTeacher.teacherId);
      if (matches.isNotEmpty) {
        selectedTeacher = matches.first;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Container(
                width: 480,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// ✅ Title
                      Text(
                        editTeacher == null
                            ? "Add Other Teacher"
                            : "Edit Other Teacher",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        height: 55,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          // 🔵 Blue background (change to gradient if needed)
                          color: Colors.blue,
                          // gradient: LinearGradient(
                          //   colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                          // ),
                        ),
                        child: Stack(
                          children: [
                            // ⚪ Sliding white toggle
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                              alignment: isPermanent
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: 0.5,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                // Permanent
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => isPermanent = true);
                                      log(isPermanent.toString());
                                    },
                                    child: Center(
                                      child: Text(
                                        "Permanent",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isPermanent
                                              ? Colors.blue
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Substitution
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => isPermanent = false);
                                      log(isPermanent.toString());
                                    },
                                    child: Center(
                                      child: Text(
                                        "Substitution",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: !isPermanent
                                              ? Colors.blue
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      /// ✅ Teacher Dropdown
                      DropdownButtonFormField<TeacherModel>(
                        value: selectedTeacher,
                        decoration: InputDecoration(
                          labelText: "Select Teacher",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: teacherList.map((teacher) {
                          return DropdownMenuItem(
                            value: teacher,
                            child: Text(teacher.teacherName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedTeacher = value;

                            // ✅ Auto fill subject if empty
                            if (subjectController.text.isEmpty) {
                              subjectController.text =
                                  selectedTeacher?.subject ?? "";
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 15),

                      /// ✅ Subject Field
                      _buildTextField(
                        subjectController,
                        "Enter Subject",
                        onChanged: (txt) {
                          setState(() {});
                        },
                      ),

                      const SizedBox(height: 5),

                      /// ✅ Permanent
                      if (!isPermanent) ...[
                        const SizedBox(height: 10),

                        /// Substituted By
                        DropdownButtonFormField<TeacherModel>(
                          value: selectedSubstituteTeacher,
                          decoration: InputDecoration(
                            labelText: "Substituted By",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: allTeachers.map((teacher) {
                            return DropdownMenuItem(
                              value: teacher,
                              child: Text(
                                "${teacher.teacherName} (${teacher.subject})",
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSubstituteTeacher = value;
                              substitutedByController.text =
                                  value?.teacherName ?? "";
                              substitutedId = value?.id ?? "";
                              substituteMobileNo = value?.mobileNo ?? "";
                              substituteImageUrl = value?.imageUrl ?? "";
                            });
                          },
                        ),
                        const SizedBox(height: 10),

                        /// Substituted Date
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: substitutedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );

                            if (picked != null) {
                              setState(() {
                                substitutedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  substitutedDate == null
                                      ? "Select Date"
                                      : "${substitutedDate!.day}/${substitutedDate!.month}/${substitutedDate!.year}",
                                ),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      /// ✅ Info Card
                      if (selectedTeacher != null)
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            children: [
                              _rowInfoTeacher(
                                "Teacher:",
                                selectedTeacher!.teacherName,
                              ),
                              _rowInfoTeacher(
                                "Employee ID:",
                                selectedTeacher!.employeeId,
                              ),
                              _rowInfoTeacher(
                                "Mobile No:",
                                selectedTeacher!.mobileNo,
                              ),
                              _rowInfoTeacher(
                                "Subject:",
                                subjectController.text,
                                valueColor: Colors.blue,
                                isBold: true,
                              ),
                              if (!isPermanent) ...[
                                _rowInfoTeacher(
                                  "Substituted By:",
                                  substitutedByController.text,
                                ),
                                _rowInfoTeacher(
                                  "Substituted Date:",
                                  substitutedDate != null
                                      ? "${substitutedDate!.day}/${substitutedDate!.month}/${substitutedDate!.year}"
                                      : "-",
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 25),

                      /// ✅ Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff1193D4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            editTeacher == null
                                ? "Add Teacher"
                                : "Update Teacher",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () async {
                            if (!isPermanent) {
                              if (substitutedByController.text.isEmpty ||
                                  substitutedDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Fill substitution details"),
                                  ),
                                );
                                return;
                              }
                            }
                            if (subjectController.text.isEmpty ||
                                selectedTeacher == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Fill all fields"),
                                ),
                              );
                              return;
                            }

                            try {
                              final docRef = FirebaseFirestore.instance
                                  .collection(FirebaseConstant.teacher)
                                  .doc(widget.teacherId);

                              final snap = await docRef.get();
                              if (!snap.exists) return;

                              final teacherData = TeacherModel.fromMap(
                                snap.data()!,
                              );

                              final list = teacherData.otherTeachers ?? [];

                              /// ✅ New Teacher Object (for Add or Edit)
                              final updatedOtherTeacher = OtherTeacherModel(
                                email: selectedTeacher!.email,
                                imageUrl: selectedTeacher!.imageUrl,
                                teacherName: selectedTeacher!.teacherName,
                                teacherId: selectedTeacher!.id,
                                subject: subjectController.text.trim(),
                                employeeId: selectedTeacher!.employeeId,
                                mobileNo: int.parse(selectedTeacher!.mobileNo),
                                isPermanent: isPermanent,
                                substitutedBy: isPermanent
                                    ? null
                                    : substitutedByController.text.trim(),
                                substitutedDate: isPermanent
                                    ? null
                                    : substitutedDate,
                                substitutedMobileNo: isPermanent
                                    ? null
                                    : int.tryParse(
                                        substituteMobileNo) ?? 0,
                                substitutedImageUrl: isPermanent
                                    ? null
                                    : substituteImageUrl,
                                substitutedId: isPermanent
                                    ? null
                                    : substitutedId,
                              );

                              List<OtherTeacherModel> updatedList = [];

                              /// ✅ ADD MODE
                              if (editTeacher == null) {
                                updatedList = [...list, updatedOtherTeacher];
                              }
                              /// ✅ EDIT MODE (Replace existing object)
                              else {
                                updatedList = list.map((t) {
                                  if (t.teacherId == editTeacher.teacherId) {
                                    return updatedOtherTeacher; // ✅ Replace full object
                                  }
                                  return t;
                                }).toList();
                              }

                              /// ✅ Update Firestore
                              await docRef.update({
                                "otherTeachers": updatedList
                                    .map((e) => e.toMap())
                                    .toList(),
                              });

                              if (isPermanent == false) {
                                Future.delayed(Duration.zero, () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Substitution Info"),
                                      content: const Text(
                                        "This substitution will expire at the end of the day.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.pop(context);

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                       "Substitution Added Successfully",
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text("OK"),
                                        ),
                                      ],
                                    ),
                                  );
                                });
                              }else {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      editTeacher == null
                                          ? "New ${subjectController.text.trim()}Teacher Added Successfully"
                                          : "${subjectController.text.trim()}Teacher Detail Updated Successfully",
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          },
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

  Widget _rowInfoTeacher(
    String title,
    String value, {
    Color valueColor = Colors.black,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void confirmDelete(TeacherModel mainTeacher, OtherTeacherModel teacher) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Teacher?"),
        content: Text("Remove ${teacher.teacherName} from Other Teachers?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deleteOtherTeacher(mainTeacher, teacher);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> deleteOtherTeacher(
    TeacherModel mainTeacher,
    OtherTeacherModel otherTeacher,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirebaseConstant.teacher)
          .doc(mainTeacher.id);

      // existing list
      final existingList = mainTeacher.otherTeachers ?? [];

      // remove teacher by id
      final updatedList = existingList
          .where((t) => t.teacherId != otherTeacher.teacherId)
          .toList();

      // update firestore
      await docRef.update({
        "otherTeachers": updatedList.map((e) => e.toMap()).toList(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Other Teacher Deleted")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Delete Error: $e")));
    }
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
                    /// ✅ Header
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

                    /// ✅ Profile Section
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

                    const SizedBox(height: 5),

                    Text(
                      "Employee ID: ${teacher.employeeId}",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),

                    const SizedBox(height: 24),

                    /// ✅ Details Card
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
    final teacherAsync = ref.watch(teacherDetailsProvider(widget.teacherId));
    final totalStudentsAsync = ref.watch(
      totalStudentsProvider(widget.teacherId),
    );
    final feesAsync = ref.watch(feesProvider(widget.teacherId));
    final attendanceAsync = ref.watch(
      todayAttendanceProvider(widget.teacherId),
    );

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: teacherAsync.when(
        data: (mainTeacher) {
          if (mainTeacher == null) {
            return const Center(child: Text('Teacher not found'));
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: ListView(
              children: [
                // Header Banner Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff1D9BF0), Color(0xff1A8CD8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff1D9BF0).withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white),
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/admin/classrooms');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundImage: mainTeacher.imageUrl.isNotEmpty
                              ? NetworkImage(mainTeacher.imageUrl)
                              : const AssetImage(
                                      ImageConstant.temporaryTeacherImage,
                                    )
                                    as ImageProvider,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              mainTeacher.teacherName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Class ${mainTeacher.classNo} - ${mainTeacher.division}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Quick actions row
                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2C3E50),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/attendance/${mainTeacher.id}',
                      ),
                      child: _actionCard(
                        Icons.fact_check_rounded,
                        "Manage Attendance",
                        true,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/teacher-dashboard/${mainTeacher.id}/student-list',
                      ),
                      child: _actionCard(
                        Icons.people_alt_rounded,
                        "Student Report",
                        false,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/teacher-dashboard/${mainTeacher.id}/timetable/${mainTeacher.classNo}/${mainTeacher.division}',
                      ),
                      child: _actionCard(
                        Icons.calendar_month_rounded,
                        "Timetable & Other",
                        false,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/teacher-dashboard/${mainTeacher.id}/marks',
                      ),
                      child: _actionCard(
                        Icons.note_alt_rounded,
                        "Marks",
                        false,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/teacher-dashboard/${mainTeacher.id}/class-report',
                      ),
                      child: _actionCard(
                        Icons.bar_chart_rounded,
                        "Class Reports",
                        false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Overview area — uses attendanceAsync & totalStudentsAsync
                const Text(
                  "Overview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff2C3E50),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _overviewMetricCard(
                        "Total Students",
                        totalStudentsAsync.when(
                          data: (v) => v.toString(),
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                        const Color(0xff1D9BF0),
                        Icons.people_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _overviewMetricCard(
                        "Present Today",
                        attendanceAsync.when(
                          data: (map) => map['present']?.toString() ?? '0',
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                        const Color(0xff2E7D32),
                        Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _overviewMetricCard(
                        "Absent Today",
                        attendanceAsync.when(
                          data: (map) => map['absent']?.toString() ?? '0',
                          loading: () => '...',
                          error: (_, __) => '0',
                        ),
                        const Color(0xffC62828),
                        Icons.cancel_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Pending fees section with view button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Pending Fees",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(
                        '/admin/classrooms/teacher-dashboard/${mainTeacher.id}/fees',
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // horizontal recent fee cards
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: feesAsync.when(
                    data: (fees) {
                      // fees is List<Map<String,dynamic>>
                      fees.sort((a, b) {
                        final da = (a['createdDate'] is Timestamp)
                            ? (a['createdDate'] as Timestamp).toDate()
                            : DateTime.now();
                        final db = (b['createdDate'] is Timestamp)
                            ? (b['createdDate'] as Timestamp).toDate()
                            : DateTime.now();
                        return db.compareTo(da);
                      });

                      final recent = fees.take(5).toList();

                      return Row(
                        children: [
                          ...recent.map((f) {
                            final feeAmount = (f['fee'] ?? f['amount'] ?? 0)
                                .toString();
                            final desc = f['description'] ?? '';
                            final collected = (f['students'] is List)
                                ? (f['students'] as List)
                                      .where((s) => s['collected'] == true)
                                      .length
                                : 0;
                            final dateStr = _formatTimestamp(f['createdDate']);
                            return Row(
                              children: [
                                _feesCard(
                                  int.tryParse(feeAmount) ?? 0,
                                  desc,
                                  collected,
                                  dateStr,
                                ),
                                const SizedBox(width: 20),
                              ],
                            );
                          }).toList(),
                          _addCard(mainTeacher),
                          const SizedBox(width: 20),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                      height: 150,
                      width: 300,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Text("Error loading fees: $e"),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  "Other Teachers",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 180,
                  child: Consumer(
                    builder: (context, ref, _) {
                      final otherTeachersAsync = ref.watch(
                        otherTeachersProvider(widget.teacherId),
                      );

                      return otherTeachersAsync.when(
                        data: (otherTeachers) {
                          return SizedBox(
                            height: 180,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: otherTeachers.length + 1,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 15),
                              itemBuilder: (context, index) {
                                if (index == otherTeachers.length) {
                                  return GestureDetector(
                                    onTap: () {
                                      _showAddTeacherBottomSheet(mainTeacher);
                                    },
                                    child: Container(
                                      width: 220,
                                      decoration: BoxDecoration(
                                        color: const Color(0xffF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xff1565C0).withOpacity(0.3),
                                          style: BorderStyle.solid,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xff1565C0).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                color: Color(0xff1565C0),
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            const Text(
                                              "Add Teacher",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xff1565C0),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                /// ✅ Teacher Card
                                final teacher = otherTeachers[index];
                                return otherTeacherCard(teacher, mainTeacher);
                              },
                            ),
                          );
                        },

                        loading: () =>
                            const Center(child: CircularProgressIndicator()),

                        error: (e, _) => Center(child: Text("Error: $e")),
                      );
                    },
                  ),
                ),

                // const SizedBox(height: 40),
                //
                // const Text(
                //   "Study Materials & Other",
                //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 20),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xff1193D4)),
        ),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget otherTeacherCard(OtherTeacherModel teacher, TeacherModel mainTeacher) {
    final isPermanent = teacher.isPermanent != false;
    return GestureDetector(
      onTap: () {
        /// ✅ Fetch full TeacherModel using teacherId
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) {
            return Consumer(
              builder: (context, ref, _) {
                final teacherAsync = ref.watch(
                  singleTeacherProvider(teacher.teacherId),
                );

                return teacherAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),

                  error: (e, _) => AlertDialog(
                    title: const Text("Error"),
                    content: Text("Failed to load teacher: $e"),
                  ),

                  data: (teacherData) {
                    if (teacherData == null) {
                      return const AlertDialog(
                        title: Text("Not Found"),
                        content: Text("Teacher details not found"),
                      );
                    }

                    /// ✅ Open Your Modal
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pop(context);
                      showTeacherDetailsModal(context, teacherData);
                    });

                    return const SizedBox();
                  },
                );
              },
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        decoration: BoxDecoration(
          color: isPermanent ? Colors.white : const Color(0xffF4F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPermanent ? Colors.grey.shade100 : const Color(0xff1565C0).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    teacher.teacherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff2C3E50),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == "delete") {
                      confirmDelete(mainTeacher, teacher);
                    }

                    if (value == "edit") {
                      _showAddTeacherBottomSheet(
                        mainTeacher,
                        editTeacher: teacher,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("Edit"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text("Delete"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.book, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Subject: ${teacher.subject}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  "Mobile: ${teacher.mobileNo}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.badge, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  "Employee ID: ${teacher.employeeId}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPermanent ? const Color(0xffE8F5E9) : const Color(0xffFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isPermanent ? "Permanent" : "Substitute",
                style: TextStyle(
                  color: isPermanent ? const Color(0xff2E7D32) : const Color(0xffE65100),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard(IconData icon, String title, bool isActive) {
    return Container(
      width: 190,
      height: 120,
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xff1D9BF0), Color(0xff1A8CD8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.white.withOpacity(0.15) : const Color(0xff1D9BF0).withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xff1D9BF0).withOpacity(0.25)
                : Colors.black.withOpacity(0.015),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? Colors.white.withOpacity(0.2) : const Color(0xff1D9BF0).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xff1D9BF0),
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xff2C3E50),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feesCard(int amount, String discription, int collected, String date) {
    final totalStudents = ref.watch(totalStudentsProvider(widget.teacherId)).maybeWhen(
          data: (v) => v,
          orElse: () => 0,
        );

    final percent = totalStudents > 0 ? collected / totalStudents : 0.0;
    final isFullyCollected = collected == totalStudents && totalStudents > 0;

    return GestureDetector(
      onTap: () => context.push(
        '/admin/classrooms/teacher-dashboard/${widget.teacherId}/fee-collection?description=${Uri.encodeComponent(discription)}',
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFullyCollected ? const Color(0xffE8F5E9) : const Color(0xffFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFullyCollected ? "Completed" : "Pending",
                    style: TextStyle(
                      color: isFullyCollected ? const Color(0xff2E7D32) : const Color(0xffE65100),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              discription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xff2C3E50),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Collected',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$collected / $totalStudents students',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    color: Color(0xff2E7D32),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade100,
                color: isFullyCollected ? const Color(0xff2E7D32) : const Color(0xff1565C0),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addCard(TeacherModel teacher) {
    return GestureDetector(
      onTap: () => _showAddFeeBottomSheet(teacher),
      child: Container(
        width: 300,
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xff1565C0).withOpacity(0.3),
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xff1565C0).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Color(0xff1565C0),
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Create Fee Category",
                style: TextStyle(
                  color: Color(0xff1565C0),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _overviewMetricCard(
    String title,
    String value,
    Color accentColor,
    IconData icon,
  ) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                      ),
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
