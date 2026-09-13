import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';

import '../controller/otherFiles_adding_controller.dart';
import '../../../../auth/controller/login_controller.dart';
import '../../../../core/config/session_manager.dart';


class OtherFilesAddingScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final int classNo;
  final String division;

  const OtherFilesAddingScreen({
    super.key,
    required this.teacherId,
    required this.classNo,
    required this.division,
  });

  @override
  ConsumerState<OtherFilesAddingScreen> createState() =>
      _OtherFileAddingScreenState();
}

class _OtherFileAddingScreenState
    extends ConsumerState<OtherFilesAddingScreen> {
  final TextEditingController titleController = TextEditingController();

  Uint8List? selectedFileBytes;
  String? selectedFileName;

  @override
  Widget build(BuildContext context) {
    ref.listen(otherFilesAddingControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (_) {
          if (previous?.isLoading == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("File uploaded successfully"),
                backgroundColor: Colors.green,
              ),
            );

            Navigator.pop(context); // 🔥 Auto Navigate
          }
        },
        error: (e, _) {
          print(e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        },
      );
    });

    final uploadState = ref.watch(otherFilesAddingControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF3F5F9),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add New File",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Streamline class distribution and schedule updates seamlessly",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 25),

                const Text(
                  "TITLE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: "e.g., Class 10-A Weekly Schedule",
                    filled: true,
                    fillColor: const Color(0xffF5F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  "UPLOAD FILE (PDF, Image, Document)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      withData: true, // 🔥 important for web
                    );

                    if (result != null) {
                      final file = result.files.single;

                      setState(() {
                        selectedFileBytes = file.bytes;
                        selectedFileName = file.name;
                      });

                      // 🔥 For web use file.bytes instead of path
                      print("File name: ${file.name}");
                      print("File size: ${file.size}");
                    }
                  },
                  child: DottedBorder(
                    options: RoundedRectDottedBorderOptions(
                      radius: const Radius.circular(16),
                      color: const Color(0xff6C8EF5),
                      strokeWidth: 1.5,
                      dashPattern: const [6, 4],
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 45),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.upload_file_rounded,
                            size: 45,
                            color: Color(0xff4C6FFF),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedFileBytes == null
                                ? "Click to upload your file here (PDF, Image, Doc)"
                                : '$selectedFileName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Discard",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 15),

                    uploadState.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            onPressed: () {
                              /// 🔥 VALIDATION
                              if (titleController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Title cannot be empty"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (selectedFileBytes == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Please select a PDF file"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final school = ref.read(schoolStreamProvider).asData?.value;
                              final principalName = school?.principalName.trim() ?? '';
                              final schoolName = school?.schoolName.trim() ?? '';
                              final adminUploaderName = principalName.isNotEmpty
                                  ? "$principalName (Principal)"
                                  : (schoolName.isNotEmpty ? "$schoolName (Principal)" : "Principal");
                              final adminUploaderId = (school?.schoolId.isNotEmpty == true)
                                  ? school!.schoolId
                                  : (SessionManager.schoolId.isNotEmpty ? SessionManager.schoolId : widget.teacherId);

                              ref
                                  .read(
                                    otherFilesAddingControllerProvider.notifier,
                                  )
                                  .uploadFile(
                                    teacherId: widget.teacherId,
                                    title: titleController.text.trim(),
                                    subtitle: "Notes",
                                    fileBytes: selectedFileBytes!,
                                    fileName: selectedFileName!,
                                    classNo: widget.classNo,
                                    division: widget.division,
                                    uploaderName: adminUploaderName,
                                    uploaderId: adminUploaderId,
                                    isCameraInstant: false,
                                  );
                            },
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text(
                              "Upload File",
                              style: TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff4C6FFF),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
