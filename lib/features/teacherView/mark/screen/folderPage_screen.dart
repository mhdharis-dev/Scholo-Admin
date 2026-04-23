import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/exam_folder_controller.dart';
import 'studentsMarksPage_screen.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: examAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            log(e.toString());
            return Center(child: Text(e.toString()));
          },
          data: (docs) {
            final firebaseNames = docs.map((e) => e.id).toList();

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
                  return _newFolder(context);
                }

                final examName = allFolders[index];

                return _folderCard(
                  context,
                  examName: examName,
                  isTemp: tempFolders.contains(examName),
                );
              },
            );
          },
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
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  if (isTemp) {
                    await ref
                        .read(tempExamProvider(widget.teacherId).notifier)
                        .remove(examName);
                  } else {
                    await ref
                        .read(examFolderRepositoryProvider)
                        .softDeleteExam(examName);
                  }
                },
              ),
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
  Widget _newFolder(BuildContext context) {
    return InkWell(
      onTap: () => _createDialog(context),
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
  void _createDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          final suggestionsAsync = ref.watch(
            examNameSuggestionsProvider(widget.teacherId),
          );

          return AlertDialog(
            title: const Text("Create Exam"),
            content: suggestionsAsync.when(
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

                    if (controller.text.isNotEmpty && suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                          maxHeight: 200, // prevents overflow
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;

                  await ref
                      .read(tempExamProvider(widget.teacherId).notifier)
                      .add(name);

                  Navigator.pop(context);
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
