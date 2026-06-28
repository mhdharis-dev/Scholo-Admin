import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/studentMark_model.dart';
import '../../../../models/students_model.dart';
import '../../../../models/subjectMark_model.dart';
import '../../../../models/teacher_model.dart';
import '../helper/marksheet_pdf_helper.dart';
import 'MarkAddingPage_screen.dart';

/// ------------------------------------------------
/// EXAM MARKS PROVIDER
/// ------------------------------------------------
final examMarksStreamProvider =
    StreamProvider.family<
      List<StudentMarkModel>,
      ({String examTitle, int classNo, String division})
    >((ref, params) {
      return FirebaseFirestore.instance
          .schoolCollection(FirebaseConstant.studentsMark)
          .doc(params.examTitle)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return [];

            final data = doc.data()!;
            
            final classKey = data.keys.firstWhere(
              (k) => k.trim() == params.classNo.toString(),
              orElse: () => '',
            );
            if (classKey.isEmpty) return [];
            
            final classMap = data[classKey];
            if (classMap is! Map<String, dynamic>) return [];

            final divKey = classMap.keys.firstWhere(
              (k) => k.trim().toLowerCase() == params.division.trim().toLowerCase(),
              orElse: () => '',
            );
            if (divKey.isEmpty) return [];

            final divisionMap = classMap[divKey];
            if (divisionMap is! Map<String, dynamic>) return [];

            final studentsMark = divisionMap["studentsMark"];
            final List<StudentMarkModel> list = [];
            if (studentsMark is List) {
              for (var e in studentsMark) {
                if (e is Map<String, dynamic>) {
                  list.add(StudentMarkModel.fromMap(e));
                }
              }
            } else if (studentsMark is Map) {
              studentsMark.forEach((studentId, markData) {
                if (markData is Map<String, dynamic>) {
                  final parsed = StudentMarkModel.fromMap(markData);
                  list.add(parsed.studentId.isEmpty
                      ? parsed.copyWith(studentId: studentId.toString())
                      : parsed);
                }
              });
            }

            return list
                .where((e) => e.delete == false) // ✅ soft delete
                .toList();
          });
    });

/// ------------------------------------------------
/// SCREEN
/// ------------------------------------------------
class StudentsMarksPage extends ConsumerStatefulWidget {
  final String teacherId;
  final String examTitle;

  const StudentsMarksPage({
    super.key,
    required this.teacherId,
    required this.examTitle,
  });

  @override
  ConsumerState<StudentsMarksPage> createState() => _StudentsMarksPageState();
}

class _StudentsMarksPageState extends ConsumerState<StudentsMarksPage> {
  String _selectedSubject = 'All Subjects';
  String _selectedGrade = 'All Grades';


  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(teacherProvider(widget.teacherId));
    final studentsAsync = ref.watch(studentsProvider(widget.teacherId));

    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xffF7F9FC),
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
          child: Container(
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
              icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        titleSpacing: 10,
        title: Text(
          widget.examTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xff111827),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                ref.invalidate(teacherProvider(widget.teacherId));
                ref.invalidate(studentsProvider(widget.teacherId));
                if (teacherAsync.hasValue && teacherAsync.value != null) {
                  ref.invalidate(examMarksStreamProvider((
                    examTitle: widget.examTitle,
                    classNo: teacherAsync.value!.classNo,
                    division: teacherAsync.value!.division,
                  )));
                }
              },
            ),
          ),
          const SizedBox(width: 14),
          teacherAsync.when(
            data: (teacher) {
              final marksAsync = ref.watch(
                examMarksStreamProvider((
                  examTitle: widget.examTitle,
                  classNo: teacher.classNo,
                  division: teacher.division,
                )),
              );

              return studentsAsync.when(
                data: (students) {
                  return marksAsync.when(
                    data: (marks) {
                      if (marks.isEmpty) return const SizedBox.shrink();

                      // Extract all unique subjects
                      final subjectsSet = <String>{};
                      for (final m in marks) {
                        for (final s in m.marks) {
                          if (s.subject.trim().isNotEmpty) {
                            subjectsSet.add(s.subject.trim());
                          }
                        }
                      }
                      final subjectsList = subjectsSet.toList()..sort();

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(40),
                            onTap: () => MarksheetPdfHelper.downloadMarksheetPdf(
                              marks: marks,
                              students: students,
                              teacher: teacher,
                              subjects: subjectsList,
                              examTitle: widget.examTitle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: const Color(0xffE5E7EB)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Download All",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          InkWell(
                            borderRadius: BorderRadius.circular(40),
                            onTap: () => MarksheetPdfHelper.printMarksheetPdf(
                              marks: marks,
                              students: students,
                              teacher: teacher,
                              subjects: subjectsList,
                              examTitle: widget.examTitle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: const Color(0xffE5E7EB)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.print, size: 18, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Print All",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: teacherAsync.when(
        data: (teacher) {
          final marksAsync = ref.watch(
            examMarksStreamProvider((
              examTitle: widget.examTitle,
              classNo: teacher.classNo,
              division: teacher.division,
            )),
          );

          return studentsAsync.when(
            data: (students) {
              return marksAsync.when(
                data: (marks) {
                  if (marks.isEmpty) {
                    return const Center(
                      child: Text(
                        "No marks uploaded yet",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  // Extract all unique subjects
                  final subjectsSet = <String>{};
                  for (final m in marks) {
                    for (final s in m.marks) {
                      if (s.subject.trim().isNotEmpty) {
                        subjectsSet.add(s.subject.trim());
                      }
                    }
                  }
                  final subjectsList = subjectsSet.toList()..sort();

                  // Filter marks
                  final filteredMarks = marks.where((m) {
                    if (_selectedSubject != 'All Subjects') {
                      final subMarkIndex = m.marks.indexWhere(
                        (s) => s.subject.trim().toLowerCase() == _selectedSubject.toLowerCase(),
                      );
                      if (subMarkIndex == -1) return false;

                      if (_selectedGrade != 'All Grades') {
                        final subMark = m.marks[subMarkIndex];
                        return subMark.grade.trim().toUpperCase() == _selectedGrade.trim().toUpperCase();
                      }
                      return true;
                    } else {
                      if (_selectedGrade != 'All Grades') {
                        return m.marks.any(
                          (s) => s.grade.trim().toUpperCase() == _selectedGrade.trim().toUpperCase(),
                        );
                      }
                      return true;
                    }
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Filter Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            const Text(
                              "Filters:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff4B5563),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Subject Filter
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xffE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedSubject,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xff6B7280)),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedSubject = val;
                                      });
                                    }
                                  },
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'All Subjects',
                                      child: Text(
                                        'All Subjects',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff374151)),
                                      ),
                                    ),
                                    ...subjectsList.map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: const TextStyle(fontSize: 13, color: Color(0xff374151)),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Grade Filter
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xffE5E7EB)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGrade,
                                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xff6B7280)),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedGrade = val;
                                      });
                                    }
                                  },
                                  items: [
                                    'All Grades',
                                    'A+',
                                    'A',
                                    'B+',
                                    'B',
                                    'C+',
                                    'C',
                                    'D+',
                                    'D'
                                  ].map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: g == 'All Grades' ? FontWeight.w600 : FontWeight.normal,
                                        color: const Color(0xff374151),
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ),
                            ),
                            if (_selectedSubject != 'All Subjects' || _selectedGrade != 'All Grades') ...[
                              const SizedBox(width: 16),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedSubject = 'All Subjects';
                                    _selectedGrade = 'All Grades';
                                  });
                                },
                                icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                                label: const Text(
                                  "Reset",
                                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xffE5E7EB)),
                      Expanded(
                        child: filteredMarks.isEmpty
                            ? const Center(
                                child: Text(
                                  "No student records match the selected filters.",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xff6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: filteredMarks.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 5,
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 20,
                                      childAspectRatio: 0.78,
                                    ),
                                itemBuilder: (_, index) {
                                  final mark = filteredMarks[index];

                                  final student = students.firstWhere(
                                    (s) => s.studentId == mark.studentId,
                                  );

                                  return _studentCard(
                                    context,
                                    ref,
                                    student: student,
                                    teacher: teacher,
                                    uploaded: true,
                                    existing: mark,
                                    allMarks: marks,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MarkAddingPage(teacherId: widget.teacherId, examTitle: widget.examTitle),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// ------------------------------------------------
  /// STUDENT CARD (UI UNCHANGED)
  /// ------------------------------------------------
  Widget _studentCard(
      BuildContext context,
      WidgetRef ref, {
        required StudentsModel student,
        required TeacherModel teacher,
        required bool uploaded,
        StudentMarkModel? existing,
        required List<StudentMarkModel> allMarks,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// MENU (3 dots)
          Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 18, color: Color(0xff9CA3AF)),
              onSelected: (value) async {
                if (value == 'edit') {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => MarkEditBottomSheet(
                      student: student,
                      teacher: teacher,
                      examTitle: widget.examTitle,
                      existing: existing,
                    ),
                  );
                }

                if (value == 'delete') {
                  await softDeleteStudentMark(
                    context: context,
                    ref: ref,
                    examTitle: widget.examTitle,
                    classNo: teacher.classNo,
                    division: teacher.division,
                    studentId: student.studentId,
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text("Edit")),
                PopupMenuItem(
                  value: 'delete',
                  child: Text("Delete",
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// DOCUMENT ICON BOX
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xffF9FAFB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xffE5E7EB),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: Colors.blue,
                  // color: Color(0xffCBD5E1),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// STUDENT LABEL
          const Text(
            "STUDENT",
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xff9CA3AF),
            ),
          ),

          const SizedBox(height:2),

          /// NAME + ICONS ROW
          Row(
            children: [
              Expanded(
                child: Text(
                  student.studentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 10),

              InkWell(
                onTap: () {
                  if (existing != null) {
                    MarksheetPdfHelper.downloadReportCardPdf(
                      mark: existing,
                      student: student,
                      teacher: teacher,
                      allMarks: allMarks,
                      examTitle: widget.examTitle,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No marks uploaded yet for this student")),
                    );
                  }
                },
                child: _circleIcon(Icons.download),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  if (existing != null) {
                    MarksheetPdfHelper.printReportCardPdf(
                      mark: existing,
                      student: student,
                      teacher: teacher,
                      allMarks: allMarks,
                      examTitle: widget.examTitle,
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No marks uploaded yet for this student")),
                    );
                  }
                },
                child: _circleIcon(Icons.print),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// DELETE FROM FIRESTORE
  /// ------------------------------------------------
  Future<void> softDeleteStudentMark({
    required BuildContext context,
    required WidgetRef ref,
    required String examTitle,
    required int classNo,
    required String division,
    required String studentId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Mark"),
        content: const Text(
          "Are you sure you want to delete this student's marks?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final docRef = FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.studentsMark)
        .doc(examTitle);

    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final classKey = data.keys.firstWhere(
      (k) => k.trim() == classNo.toString(),
      orElse: () => '',
    );
    if (classKey.isEmpty) return;

    final classMap = data[classKey];
    if (classMap is! Map<String, dynamic>) return;

    final divKey = classMap.keys.firstWhere(
      (k) => k.trim().toLowerCase() == division.trim().toLowerCase(),
      orElse: () => '',
    );
    if (divKey.isEmpty) return;

    final divisionMap = classMap[divKey];
    if (divisionMap is! Map<String, dynamic>) return;

    final studentsMark = divisionMap["studentsMark"];
    if (studentsMark is List) {
      final list = List<Map<String, dynamic>>.from(
        studentsMark.map((e) => Map<String, dynamic>.from(e as Map)),
      );

      for (int i = 0; i < list.length; i++) {
        if (list[i]["studentId"]?.toString() == studentId) {
          list[i]["delete"] = true;
          list[i]["deletedAt"] = Timestamp.now();
          break;
        }
      }
      await docRef.update({"$classKey.$divKey.studentsMark": list});
    } else if (studentsMark is Map) {
      final matchedStudentId = studentsMark.keys.firstWhere(
        (k) => k.trim() == studentId.trim(),
        orElse: () => '',
      );
      if (matchedStudentId.isNotEmpty) {
        await docRef.update({
          "$classKey.$divKey.studentsMark.$matchedStudentId.delete": true,
          "$classKey.$divKey.studentsMark.$matchedStudentId.deletedAt": Timestamp.now(),
        });
      }
    }
  }
}
Widget _circleIcon(IconData icon) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xffEFF6FF),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      size: 20,
      color: const Color(0xff1D4ED8),
    ),
  );
}

/// ------------------------------------------------
/// SMALL ICON
/// ------------------------------------------------

class MarkEditBottomSheet extends ConsumerStatefulWidget {
  final StudentsModel student;
  final TeacherModel teacher;
  final String examTitle;
  final StudentMarkModel? existing;

  const MarkEditBottomSheet({
    super.key,
    required this.student,
    required this.teacher,
    required this.examTitle,
    this.existing,
  });

  @override
  ConsumerState<MarkEditBottomSheet> createState() =>
      _MarkEntryBottomSheetState();
}

class _MarkEntryBottomSheetState extends ConsumerState<MarkEditBottomSheet> {
  late List<SubjectMarkModel> subjects;
  late List<TextEditingController> maxControllers;
  late List<TextEditingController> obtControllers;
  late List<TextEditingController> subjectControllers;

  List<SubjectMarkModel> _createTemplateFrom(List<SubjectMarkModel> source) {
    return source.map((e) {
      return SubjectMarkModel(
        subject: e.subject,
        maxMarks: e.maxMarks,
        obtained: 0,
        grade: '',
      );
    }).toList();
  }

  bool _isValidRow(SubjectMarkModel s) {
    if (s.subject.trim().isEmpty) return false;
    if (s.maxMarks <= 0) return false;
    if (s.obtained < 0) return false;
    if (s.obtained > s.maxMarks) return false;
    return true;
  }

  bool get _isFormValid {
    if (subjects.isEmpty) return false;
    return subjects.every(_isValidRow);
  }

  bool get isFirstStudent => ref.read(subjectTemplateProvider).isEmpty;

  @override
  void initState() {
    super.initState();

    final template = ref.read(subjectTemplateProvider);

    subjects =
        widget.existing?.marks ??
        (template.isNotEmpty
            ? _createTemplateFrom(template)
            : [
                SubjectMarkModel(
                  subject: "",
                  maxMarks: 0,
                  obtained: 0,
                  grade: '',
                ),
              ]);

    maxControllers = subjects.map((e) {
      return TextEditingController(
        text: e.maxMarks == 0 ? "" : e.maxMarks.toString(),
      );
    }).toList();

    obtControllers = subjects.map((e) {
      return TextEditingController(
        text: e.obtained == 0 ? "" : e.obtained.toString(),
      );
    }).toList();

    subjectControllers = subjects.map((e) {
      return TextEditingController(text: e.subject);
    }).toList();
  }

  String _grade(int max, int obt) {
    if (max == 0) return "-";

    final p = (obt / max) * 100;

    if (p >= 90) return "A+";
    if (p >= 80) return "A";
    if (p >= 70) return "B+";
    if (p >= 60) return "B";
    if (p >= 55) return "C+";
    if (p >= 45) return "C";
    if (p >= 35) return "D+";
    return "D";
  }

  Color _gradeColor(String g) {
    switch (g) {
      case "A+":
      case "A":
        return const Color(0xffDCFCE7); // green

      case "B+":
      case "B":
        return const Color(0xffE0F2FE); // blue

      case "C+":
      case "C":
        return const Color(0xffFEF9C3); // yellow

      case "D+":
        return const Color(0xffFED7AA); // orange (pass)

      case "D":
        return const Color(0xffFEE2E2); // ❌ RED only

      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storageKey = "${widget.teacher.id}_${widget.examTitle}";

    return Center(
      child: Container(
        width: 950,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// ================= HEADER =================
              Row(
                children: [
                  _info("STUDENT NAME", widget.student.studentName),
                  _info("EXAM NAME", widget.examTitle),
                  _info(
                    "CLASS / DIV",
                    "${widget.student.classNo} / ${widget.student.division}",
                  ),
                  _info("ROLL NO", widget.student.rollNo.toString()),
                  const Spacer(),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2563EB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _isFormValid
                        ? () async {
                            final docRef = FirebaseFirestore.instance
                                .schoolCollection(FirebaseConstant.studentsMark)
                                .doc(widget.examTitle);

                            final snap = await docRef.get();
                            if (!snap.exists) return;

                            final data = snap.data()!;
                            
                            final classKey = data.keys.firstWhere(
                              (k) => k.trim() == widget.teacher.classNo.toString(),
                              orElse: () => '',
                            );
                            if (classKey.isEmpty) return;

                            final classMap = data[classKey];
                            if (classMap is! Map<String, dynamic>) return;

                            final divKey = classMap.keys.firstWhere(
                              (k) => k.trim().toLowerCase() == widget.teacher.division.trim().toLowerCase(),
                              orElse: () => '',
                            );
                            if (divKey.isEmpty) return;

                            final divisionMap = classMap[divKey];
                            if (divisionMap is! Map<String, dynamic>) return;

                            final studentsMark = divisionMap["studentsMark"];
                            if (studentsMark is List) {
                              final list = List<Map<String, dynamic>>.from(
                                studentsMark.map((e) => Map<String, dynamic>.from(e as Map)),
                              );

                              for (int i = 0; i < list.length; i++) {
                                if (list[i]["studentId"] ==
                                    widget.student.studentId) {
                                  list[i] = StudentMarkModel(
                                    studentId: widget.student.studentId,
                                    studentName: widget.student.studentName,
                                    delete: false,
                                    marks: subjects,
                                    markType: 'Student Mark',
                                  ).toMap();
                                  break;
                                }
                              }

                              await docRef.update({
                                "$classKey.$divKey.studentsMark": list,
                              });
                            } else if (studentsMark is Map) {
                              final matchedStudentId = studentsMark.keys.firstWhere(
                                (k) => k.trim() == widget.student.studentId.trim(),
                                orElse: () => '',
                              );
                              if (matchedStudentId.isNotEmpty) {
                                await docRef.update({
                                  "$classKey.$divKey.studentsMark.$matchedStudentId": StudentMarkModel(
                                    studentId: widget.student.studentId,
                                    studentName: widget.student.studentName,
                                    delete: false,
                                    marks: subjects,
                                    markType: 'Student Mark',
                                  ).toMap(),
                                });
                              }
                            }

                            Navigator.pop(context);
                          }
                        : null,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text("Save Records"),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              /// ================= TABLE HEADER =================
              Row(
                children: const [
                  Expanded(flex: 4, child: _TableTitle("SUBJECT")),
                  Expanded(flex: 2, child: _TableTitle("MAX MARKS")),
                  Expanded(flex: 2, child: _TableTitle("OBTAINED")),
                  Expanded(flex: 2, child: _TableTitle("GRADE")),
                  Expanded(flex: 1, child: _TableTitle("ACTION")),
                ],
              ),

              const Divider(height: 26),

              /// ================= SUBJECT ROWS =================
              ...subjects.asMap().entries.map((entry) {
                final index = entry.key;
                final e = entry.value;
                final grade = _grade(e.maxMarks, e.obtained);
                e.grade = grade;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      /// SUBJECT
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: subjectControllers[index],
                          onChanged: (v) => e.subject = v,
                          decoration: InputDecoration(
                            hintText: "Enter subject...",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            // isDense: true,
                          ),
                        ),
                      ),

                      /// MAX
                      Expanded(
                        flex: 2,
                        child: _numberField(
                          controller: maxControllers[index],
                          onChanged: (v) {
                            final max = int.tryParse(v) ?? 0;
                            subjects[index].maxMarks = max;

                            // auto adjust obtained if needed
                            if (subjects[index].obtained > max) {
                              subjects[index].obtained = max;
                              obtControllers[index].text = max.toString();
                            }

                            subjects[index].grade = _grade(
                              subjects[index].maxMarks,
                              subjects[index].obtained,
                            );

                            setState(() {});
                          },
                        ),
                      ),

                      /// OBTAINED
                      Expanded(
                        flex: 2,
                        child: _numberField(
                          controller: obtControllers[index],
                          onChanged: (v) {
                            final obt = int.tryParse(v) ?? 0;

                            if (obt > subjects[index].maxMarks) {
                              obtControllers[index].text = subjects[index]
                                  .maxMarks
                                  .toString();
                              return;
                            }

                            subjects[index].obtained = obt;
                            subjects[index].grade = _grade(
                              subjects[index].maxMarks,
                              subjects[index].obtained,
                            );

                            setState(() {});
                          },
                        ),
                      ),

                      /// GRADE
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _gradeColor(grade),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              grade,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      /// DELETE
                      Expanded(
                        flex: 1,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              subjects.removeAt(index);
                              subjectControllers.removeAt(index);
                              maxControllers.removeAt(index);
                              obtControllers.removeAt(index);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              /// ================= ADD FIELD =================
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xff2563EB)),
                ),
                onPressed: () {
                  setState(() {
                    subjects.add(
                      SubjectMarkModel(
                        subject: "",
                        maxMarks: 0,
                        obtained: 0,
                        grade: '',
                      ),
                    );

                    maxControllers.add(TextEditingController());
                    obtControllers.add(TextEditingController());
                    subjectControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Field"),
              ),

              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "• Grades are automatically calculated based on obtained percentage.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Color(0xff9CA3AF)),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required Function(String) onChanged,
    bool? enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: TextField(
        enabled: enabled,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: "0",
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _TableTitle extends StatelessWidget {
  final String text;

  const _TableTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xff9CA3AF),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
