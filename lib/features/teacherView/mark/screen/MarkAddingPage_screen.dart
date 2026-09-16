import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/mark_model.dart';
import '../../../../models/studentMark_model.dart';
import '../../../../models/students_model.dart';
import '../../../../models/subjectMark_model.dart';
import '../../../../models/teacher_model.dart';

/// ============================================================
/// PROVIDERS
/// ============================================================

final subjectTemplateProvider =
StateNotifierProvider<SubjectTemplateNotifier, List<SubjectMarkModel>>(
      (ref) => SubjectTemplateNotifier(),
);

class SubjectTemplateNotifier extends StateNotifier<List<SubjectMarkModel>> {
  SubjectTemplateNotifier() : super([]);

  void setTemplate(List<SubjectMarkModel> subjects) {
    state = subjects
        .map((e) => SubjectMarkModel(
      subject: e.subject,
      maxMarks: e.maxMarks,
      obtained: 0,
      grade: '',
    ))
        .toList();
  }

  void clear() => state = [];
}

final teacherProvider = FutureProvider.family<TeacherModel, String>((
  ref,
  teacherId,
) async {
  final doc = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .doc(teacherId)
      .get();

  return TeacherModel.fromMap(doc.data()!);
});

final studentsProvider = FutureProvider.family<List<StudentsModel>, String>((
  ref,
  teacherId,
) async {
  final snap = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.student)
      .where("teacherId", isEqualTo: teacherId)
      .where("delete", isEqualTo: false)
      .orderBy("rollNo") // ✅ ORDER BY ROLL NUMBER
      .get();

  return snap.docs.map((e) => StudentsModel.fromMap(e.data())).toList();
});

final tempMarksProvider =
    StateNotifierProvider<TempMarksNotifier, Map<String, StudentMarkModel>>(
      (ref) => TempMarksNotifier(),
    );

class TempMarksNotifier extends StateNotifier<Map<String, StudentMarkModel>> {
  TempMarksNotifier() : super({});

  Future<void> saveStudent(String key, StudentMarkModel model) async {
    final pref = await SharedPreferences.getInstance();

    final updated = {...state};
    updated[model.studentId] = model;

    state = updated;

    await pref.setString(
      key,
      jsonEncode(state.map((k, v) => MapEntry(k, v.toMap()))),
    );
  }

  void clear() => state = {};
}

/// ============================================================
/// MARK ADDING PAGE
/// ============================================================

class MarkAddingPage extends ConsumerWidget {
  final String teacherId;
  final String examTitle;

  const MarkAddingPage({
    super.key,
    required this.teacherId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(teacherProvider(teacherId));
    final studentsAsync = ref.watch(studentsProvider(teacherId));
    final tempMarks = ref.watch(tempMarksProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: teacherAsync.when(
        data: (teacher) {
          return studentsAsync.when(
            data: (students) {
              final uploaded = tempMarks.length;

              return Padding(
                padding: const EdgeInsets.all(24),
                child: ListView(
                  children: [
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
                            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
                            onPressed: () => context.pop(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "Add Marks",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    /// HEADER
                    _examHeader(
                      teacher: teacher,
                      examTitle: examTitle,
                      uploaded: uploaded,
                      total: students.length,
                    ),

                    const SizedBox(height: 24),

                    /// STUDENT LIST
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _card(),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Student List",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff2563EB),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                  onPressed: () async {
                                    if (students.length != tempMarks.length) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Please enter all student marks")),
                                      );
                                      return;
                                    }

                                    final markModel = MarkModel(
                                       classNo: teacher.classNo,
                                       examName: examTitle,
                                       teacherName: teacher.teacherName,
                                       teacherId: teacher.id,
                                       division: teacher.division,
                                       uploadedAt: DateTime.now(),
                                       delete: false,
                                       studentsMark: tempMarks.values.toList(),
                                       markType: "Mark Folder",
                                     );

                                     await FirebaseFirestore.instance
                                         .schoolCollection(FirebaseConstant.studentsMark)
                                         .doc(examTitle) // same exam
                                         .set(
                                       {
                                         teacher.classNo.toString(): {
                                           teacher.division: markModel.toMap(),
                                         }
                                       },
                                       SetOptions(merge: true), // 🔥 keeps other classes safe
                                     );

                                     ref.read(tempMarksProvider.notifier).clear();
                                     Navigator.pop(context);

                                     log(markModel.toMap().toString());
                                   },
                                child: const Text("Save Changes"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _studentTableHeader(),

                          const Divider(height: 20),

                          ...students.map((s) {
                            final isUploaded = tempMarks.containsKey(
                              s.studentId,
                            );

                            return _studentRow(
                              student: s,
                              uploaded: isUploaded,
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => MarkEntryBottomSheet(
                                    student: s,
                                    teacher: teacher,
                                    examTitle: examTitle,
                                    existing: tempMarks[s.studentId],
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              log(e.toString());
              return Text(e.toString());
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(e.toString()),
      ),
    );
  }

  /// ================= UI COMPONENTS =================

  Widget _studentTableHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: const [
          Expanded(
            flex: 5,
            child: Text(
              "NAME",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xff9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "STATUS",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xff9CA3AF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                "ACTION",
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xff9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _examHeader({
    required TeacherModel teacher,
    required String examTitle,
    required int uploaded,
    required int total,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _card(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _headerItem("TEACHER NAME", teacher.teacherName),
                    const SizedBox(width: 60),
                    _headerItem("CLASS", teacher.classNo.toString()),
                    const SizedBox(width: 40),
                    _headerItem("DIVISION", teacher.division),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  "EXAM NAME",
                  style: TextStyle(fontSize: 11, color: Color(0xff9CA3AF)),
                ),
                const SizedBox(height: 4),
                Text(
                  examTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          /// Progress card
          Container(
            width: 260,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xffEEF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "UPLOAD PROGRESS",
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xff2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      "$uploaded / $total",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Students Recorded",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: total == 0 ? 0 : uploaded / total,
                    backgroundColor: const Color(0xffDDE7FF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xff2563EB)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow({
    required StudentsModel student,
    required bool uploaded,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        student.rollNo.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      student.studentName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _statusChip(uploaded),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: uploaded
                      ? TextButton.icon(
                          onPressed: onTap,
                          icon: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Color(0xff2563EB),
                          ),
                          label: const Text(
                            "Edit",
                            style: TextStyle(color: Color(0xff2563EB)),
                          ),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2563EB),
                          ),
                          onPressed: onTap,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add"),
                        ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _statusChip(bool uploaded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: uploaded
            ? const Color(0xffECFDF5) // light green
            : const Color(0xffFFF7ED), // light orange
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        uploaded ? "Uploaded" : "Pending",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: uploaded
              ? const Color(0xff059669) // green text
              : const Color(0xffF97316), // orange text
        ),
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
      ],
    );
  }

  Widget _headerItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xff9CA3AF)),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// ============================================================
/// MARK ENTRY BOTTOM SHEET
/// ============================================================
class MarkEntryBottomSheet extends ConsumerStatefulWidget {
  final StudentsModel student;
  final TeacherModel teacher;
  final String examTitle;
  final StudentMarkModel? existing;

  const MarkEntryBottomSheet({
    super.key,
    required this.student,
    required this.teacher,
    required this.examTitle,
    this.existing,
  });

  @override
  ConsumerState<MarkEntryBottomSheet> createState() =>
      _MarkEntryBottomSheetState();
}

class _MarkEntryBottomSheetState extends ConsumerState<MarkEntryBottomSheet> {
  late List<SubjectMarkModel> subjects;
  late List<TextEditingController> maxControllers;
  late List<TextEditingController> obtControllers;
  late List<TextEditingController> subjectControllers;

  List<SubjectMarkModel> _createTemplateFrom(
      List<SubjectMarkModel> source,
      ) {
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

  bool get isFirstStudent =>
      ref.read(subjectTemplateProvider).isEmpty;

  @override
  void initState() {
    super.initState();

    final template = ref.read(subjectTemplateProvider);

    subjects = widget.existing?.marks ??
        (template.isNotEmpty
            ? _createTemplateFrom(template)
            : [
          SubjectMarkModel(
            subject: "",
            maxMarks: 0,
            obtained: 0,
            grade: '',
          )
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

                      // save template only once
                      if (isFirstStudent) {
                        ref
                            .read(subjectTemplateProvider.notifier)
                            .setTemplate(subjects);
                      }

                      final model = StudentMarkModel(
                        studentName: widget.student.studentName,
                        studentId: widget.student.studentId,
                        delete: false,
                        marks: subjects,
                        markType: "Student Mark",
                      );

                      await ref
                          .read(tempMarksProvider.notifier)
                          .saveStudent(storageKey, model);

                      Navigator.pop(context);
                      return log(model.toMap().toString());
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
    required Function(String) onChanged, bool? enabled
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

/// ================= TABLE TITLE =================
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
