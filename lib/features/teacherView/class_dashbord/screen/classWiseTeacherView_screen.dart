import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';

import '../../../../core/constant/image_constant.dart';
import '../../../../models/teacher_model.dart';
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

  void _assignTeacher() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedTeacherId;
        String? selectedTeacherName;

        String? selectedGrade;
        String? selectedDivision;

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

                    // ===================================================
                    // HEADER
                    // ===================================================
                    Row(
                      children: [
                        const Icon(Icons.person_add_alt_1,
                            color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        const Text(
                          "Assign New Teacher",
                          style: TextStyle(
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

                    // ===================================================
                    // TEACHER DROPDOWN (classNo == 0)
                    // ===================================================

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
                          .where("classNo", isEqualTo: 0) // ✅ Not assigned
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
                                final data = doc.data();

                                // ✅ Correct field name
                                final name = data["teacherName"] ?? "";

                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (val) {
                                final teacherDoc =
                                docs.firstWhere((e) => e.id == val);

                                setState(() {
                                  selectedTeacherId = val;
                                  selectedTeacherName =
                                  teacherDoc["teacherName"];
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // ===================================================
                    // GRADE + DIVISION
                    // ===================================================

                    Row(
                      children: [

                        // ---------------- Grade Dropdown ----------------
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Select Grade"),
                              const SizedBox(height: 8),

                              Container(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedGrade,
                                    hint: const Text("Grade"),
                                    isExpanded: true,
                                    items: grades.map((g) {
                                      return DropdownMenuItem(
                                        value: g,
                                        child: Text("Grade $g"),
                                      );
                                    }).toList(),
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

                        // ---------------- Division Dropdown ----------------
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
                                      .collection("classes")
                                      .where("classNo",
                                      isEqualTo: int.parse(selectedGrade!))
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const CircularProgressIndicator();
                                    }

                                    // ✅ Existing divisions for that grade
                                    final usedDivisions = snapshot.data!.docs
                                        .map((doc) =>
                                        doc["division"].toString())
                                        .toList();

                                    // ✅ Filter available divisions
                                    final availableDivisions = allDivisions
                                        .where((d) =>
                                    !usedDivisions.contains(d))
                                        .toList();

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedDivision,
                                          hint: const Text("Division"),
                                          isExpanded: true,
                                          items: availableDivisions.map((d) {
                                            return DropdownMenuItem(
                                              value: d,
                                              child: Text(d),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              selectedDivision = val;
                                            });
                                          },
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

                    // ===================================================
                    // ASSIGN BUTTON (Update TeacherModel)
                    // ===================================================

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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                            ),
                            onPressed: () async {
                              if (selectedTeacherId == null ||
                                  selectedGrade == null ||
                                  selectedDivision == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Please select all fields"),
                                  ),
                                );
                                return;
                              }

                              // ✅ Update teacher document
                              await FirebaseFirestore.instance
                                  .collection(FirebaseConstant.teacher)
                                  .doc(selectedTeacherId)
                                  .update({
                                "classNo": int.parse(selectedGrade!),
                                "division": selectedDivision,
                              });

                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      "Assigned $selectedTeacherName Successfully"),
                                ),
                              );
                            },
                            child: const Text("Assign"),
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
                    _assignTeacher();
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

  /// ===================================================
  /// TEACHER CARD UI
  /// ===================================================
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey[200],
            backgroundImage: teacher.imageUrl.isNotEmpty
                ? NetworkImage(teacher.imageUrl)
                : const AssetImage(ImageConstant.temporaryTeacherImage)
            as ImageProvider,
          ),

          const SizedBox(height: 10),

          Text(
            teacher.teacherName,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 4),

          if (!isOtherClass)
            Text(
              "SECTION ${teacher.division}",
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xff2F80ED),
                fontWeight: FontWeight.w600,
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeacherDashbordScreen(
                      teacherId: teacher.id,
                    ),
                  ),
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
