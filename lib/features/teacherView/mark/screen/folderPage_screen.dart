import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/studentMark_model.dart';
import '../../../../models/students_model.dart';
import '../../../../models/teacher_model.dart';
import '../controller/exam_folder_controller.dart';
import '../helper/marksheet_pdf_helper.dart';
import 'studentsMarksPage_screen.dart';
import 'MarkAddingPage_screen.dart';
import '../../../../core/constant/image_constant.dart';

class ExamFolderPageScreen extends ConsumerStatefulWidget {
  final String teacherId;

  const ExamFolderPageScreen({super.key, required this.teacherId});

  @override
  ConsumerState<ExamFolderPageScreen> createState() => _ExamFolderPageState();
}

class _ExamFolderPageState extends ConsumerState<ExamFolderPageScreen> {
  @override
  Widget build(BuildContext context) {
    final tempFolders = ref.watch(tempExamProvider(widget.teacherId));

    final examAsync = ref.watch(examFolderListProvider(widget.teacherId));
    final teacherAsync = ref.watch(teacherProvider(widget.teacherId));
    final studentsAsync = ref.watch(studentsProvider(widget.teacherId));

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  "Exam Folders",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
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
                      ref.invalidate(tempExamProvider(widget.teacherId));
                      ref.invalidate(examFolderListProvider(widget.teacherId));
                      ref.invalidate(teacherProvider(widget.teacherId));
                      ref.invalidate(studentsProvider(widget.teacherId));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: teacherAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (teacher) {
                  final classNoStr = teacher.classNo.toString();
                  final division = teacher.division;

                  return studentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(e.toString())),
                    data: (students) {
                      return examAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) {
                          log(e.toString());
                          return Center(child: Text(e.toString()));
                        },
                        data: (docs) {
                          print("--- DEBUG ExamFolderPageScreen ---");
                          print("Docs count: ${docs.length}");
                          print("Teacher classNo: '$classNoStr', division: '$division'");
                          for (var d in docs) {
                            print("Doc ID: '${d.id}', keys: ${d.data() is Map ? (d.data() as Map).keys.toList() : 'not map'}");
                            print("Doc data: ${d.data()}");
                          }
                          final filteredDocs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return false;

                            final classKey = data.keys.firstWhere(
                              (k) => k.trim() == classNoStr.trim(),
                              orElse: () => '',
                            );
                            if (classKey.isEmpty) return false;

                            final classMap = data[classKey];
                            if (classMap is! Map<String, dynamic>) return false;

                            final divKey = classMap.keys.firstWhere(
                              (k) => k.trim().toLowerCase() == division.trim().toLowerCase(),
                              orElse: () => '',
                            );
                            if (divKey.isEmpty) return false;

                            final divMap = classMap[divKey];
                            if (divMap is! Map<String, dynamic>) return false;

                            return divMap['delete'] != true;
                          }).toList();

                          final firebaseNames = filteredDocs.map((e) => e.id).toList();

                          final allFolders = {...tempFolders, ...firebaseNames}.toList();

                          return GridView.builder(
                            itemCount: allFolders.length + 1,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                            ),
                            itemBuilder: (_, index) {
                              if (index == allFolders.length) {
                                return _newFolder(context, allFolders);
                              }

                              final examName = allFolders[index];

                              return _folderCard(
                                context,
                                examName: examName,
                                isTemp: tempFolders.contains(examName),
                                inFirebase: firebaseNames.contains(examName),
                                classNo: classNoStr,
                                division: division,
                                docs: filteredDocs,
                                students: students,
                                teacher: teacher,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================================
  /// FOLDER CARD
  /// ================================
  Widget _folderCard(
    BuildContext context, {
    required String examName,
    required bool isTemp,
    required bool inFirebase,
    required String classNo,
    required String division,
    required List<QueryDocumentSnapshot> docs,
    required List<StudentsModel> students,
    required TeacherModel teacher,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentsMarksPage(
              teacherId: widget.teacherId,
              examTitle: examName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (inFirebase) ...[
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.download, color: Colors.blue, size: 16),
                    onPressed: () {
                      final doc = docs.firstWhere((d) => d.id == examName);
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return;

                      final classKey = data.keys.firstWhere(
                        (k) => k.trim() == classNo.trim(),
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

                      final divMap = classMap[divKey];
                      if (divMap is! Map<String, dynamic>) return;

                      final List list = divMap["studentsMark"] ?? [];
                      final marks = list
                          .map((e) => StudentMarkModel.fromMap(e))
                          .where((e) => e.delete == false)
                          .toList();

                      final subjectsSet = <String>{};
                      for (final m in marks) {
                        for (final s in m.marks) {
                          if (s.subject.trim().isNotEmpty) {
                            subjectsSet.add(s.subject.trim());
                          }
                        }
                      }
                      final subjectsList = subjectsSet.toList()..sort();

                      MarksheetPdfHelper.downloadMarksheetPdf(
                        marks: marks,
                        students: students,
                        teacher: teacher,
                        subjects: subjectsList,
                        examTitle: examName,
                      );
                    },
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    icon: const Icon(Icons.print, color: Colors.blue, size: 16),
                    onPressed: () {
                      final doc = docs.firstWhere((d) => d.id == examName);
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) return;

                      final classKey = data.keys.firstWhere(
                        (k) => k.trim() == classNo.trim(),
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

                      final divMap = classMap[divKey];
                      if (divMap is! Map<String, dynamic>) return;

                      final List list = divMap["studentsMark"] ?? [];
                      final marks = list
                          .map((e) => StudentMarkModel.fromMap(e))
                          .where((e) => e.delete == false)
                          .toList();

                      final subjectsSet = <String>{};
                      for (final m in marks) {
                        for (final s in m.marks) {
                          if (s.subject.trim().isNotEmpty) {
                            subjectsSet.add(s.subject.trim());
                          }
                        }
                      }
                      final subjectsList = subjectsSet.toList()..sort();

                      MarksheetPdfHelper.printMarksheetPdf(
                        marks: marks,
                        students: students,
                        teacher: teacher,
                        subjects: subjectsList,
                        examTitle: examName,
                      );
                    },
                  ),
                ],
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                  onPressed: () async {
                    if (isTemp) {
                      await ref
                          .read(tempExamProvider(widget.teacherId).notifier)
                          .remove(examName);
                    }
                    if (inFirebase) {
                      await ref
                          .read(examFolderRepositoryProvider)
                          .softDeleteExam(
                            examName: examName,
                            classNo: classNo,
                            division: division,
                          );
                    }
                  },
                ),
              ],
            ),
            Expanded(child: Image.asset(ImageConstant.folderImage)),
            Text(examName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// ================================
  /// NEW FOLDER BUTTON
  /// ================================
  Widget _newFolder(BuildContext context, List<String> existingFolders) {
    return InkWell(
      onTap: () => _createDialog(context, existingFolders),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.create_new_folder_outlined, color: Colors.blue),
              SizedBox(height: 8),
              Text("New Exam Folder"),
            ],
          ),
        ),
      ),
    );
  }

  /// ================================
  /// CREATE DIALOG
  /// ================================
  void _createDialog(BuildContext context, List<String> existingFolders) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final suggestionsAsync = ref.watch(
            examNameSuggestionsProvider,
          );

          return AlertDialog(
            title: const Text("Create Exam"),
            content: SizedBox(
              width: 400,
              child: suggestionsAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),

                error: (e, _) {
                  log(e.toString());
                  return Text("Error: $e");
                },

                data: (firebaseDocs) {
                  final suggestions = firebaseDocs
                      .where((e) => !existingFolders.contains(e))
                      .where(
                        (e) => e.toLowerCase().contains(
                          controller.text.toLowerCase(),
                        ),
                      )
                      .toList();

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: "Exam name"),
                      ),

                      if (suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(
                            maxHeight: 180, // prevents overflow
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ListView(
                            shrinkWrap: true,
                            children: suggestions.map((e) {
                              return ListTile(
                                dense: true,
                                title: Text(e),
                                onTap: () {
                                  controller.text = e;
                                  setState(() {});
                                },
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;

                  await ref
                      .read(tempExamProvider(widget.teacherId).notifier)
                      .add(name);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }
}
