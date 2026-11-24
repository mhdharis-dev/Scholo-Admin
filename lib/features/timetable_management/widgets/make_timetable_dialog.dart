import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:alert_info/alert_info.dart';
import '../../../models/class_model.dart';
import '../../../models/teacher_model.dart';
import '../../teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import '../../teachers/controller/teacher_controller.dart';
import '../../teacherView/timetable_otherFiles/screen/timetableLayoutMaker.dart';
import '../screen/analyzed_timetable_editor_screen.dart';

enum MakeTimetableStep {
  selectMode,
  fromScratch,
  pdfAnalyze,
  analyzingProgress,
}

class MakeTimetableDialog extends ConsumerStatefulWidget {
  const MakeTimetableDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MakeTimetableDialog(),
    );
  }

  @override
  ConsumerState<MakeTimetableDialog> createState() => _MakeTimetableDialogState();
}

class _MakeTimetableDialogState extends ConsumerState<MakeTimetableDialog> {
  MakeTimetableStep _currentStep = MakeTimetableStep.selectMode;

  // Selected Class & Teacher
  ClassModel? _selectedClass;
  TeacherModel? _selectedTeacher;
  final TextEditingController _timetableNameController = TextEditingController();

  // Uploaded file for AI analyze
  PlatformFile? _uploadedFile;

  // Analysis progress animation states
  int _analysisStepIndex = 0;
  final List<String> _analysisSteps = [
    "Reading uploaded timetable document structure...",
    "Scanning working days and timetable matrix...",
    "Detecting period slots, break intervals, and timings...",
    "Extracting subject allocations and teacher assignments...",
    "Assembling pre-filled timetable layout...",
  ];

  @override
  void dispose() {
    _timetableNameController.dispose();
    super.dispose();
  }

  Future<void> _pickResourceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        AlertInfo.show(
          context: context,
          text: "Failed to pick file: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _startPdfAnalysis() async {
    if (_uploadedFile == null) {
      AlertInfo.show(
        context: context,
        text: "Please upload a timetable PDF or image file first",
        typeInfo: TypeInfo.error,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _currentStep = MakeTimetableStep.analyzingProgress;
      _analysisStepIndex = 0;
    });

    // Simulate multi-step progressive analysis
    for (int i = 0; i < _analysisSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _analysisStepIndex = i;
      });
    }

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final fileName = _uploadedFile?.name;

    Navigator.of(context).pop(); // Close bottom sheet

    // Navigate directly into AnalyzedTimetableEditorScreen!
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalyzedTimetableEditorScreen(
          uploadedFileName: fileName,
        ),
      ),
    );
  }

  void _proceedFromScratch() {
    if (_selectedClass == null) {
      AlertInfo.show(
        context: context,
        text: "Please select a target Class & Division",
        typeInfo: TypeInfo.error,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
      return;
    }

    if (_selectedTeacher == null) {
      AlertInfo.show(
        context: context,
        text: "Please select or assign a Class Teacher",
        typeInfo: TypeInfo.error,
        backgroundColor: Colors.redAccent,
        textColor: Colors.white,
      );
      return;
    }

    final teacherId = _selectedTeacher!.id;
    Navigator.of(context).pop(); // Close bottom sheet

    // Open layout maker screen for this teacher -> which then goes to assign screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimeTableLayoutMakerPage(teacherId: teacherId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesStreamProvider);
    final teachersAsync = ref.watch(teacherControllerProvider);

    final List<ClassModel> createdClasses = (classesAsync.value ?? <ClassModel>[])
        .where((c) => !c.delete)
        .toList();
    final List<TeacherModel> allTeachers = (teachersAsync.value ?? <TeacherModel>[])
        .where((t) => !t.delete)
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStep(createdClasses, allTeachers),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(List<ClassModel> createdClasses, List<TeacherModel> allTeachers) {
    switch (_currentStep) {
      case MakeTimetableStep.selectMode:
        return _buildSelectModeView();
      case MakeTimetableStep.fromScratch:
        return _buildFromScratchConfigView(createdClasses, allTeachers);
      case MakeTimetableStep.pdfAnalyze:
        return _buildPdfAnalyzeConfigView();
      case MakeTimetableStep.analyzingProgress:
        return _buildAnalyzingProgressView();
    }
  }

  // ── Step 1: Mode Selection (Analyze vs Scratch) ──
  Widget _buildSelectModeView() {
    return Column(
      key: const ValueKey('selectMode'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1193D4), size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Make Timetable",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Choose how you want to create the class schedule",
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(height: 1),
        const SizedBox(height: 20),

        // Option 1: PDF Analyze Option
        _buildModeOptionCard(
          icon: Icons.document_scanner_rounded,
          iconColor: const Color(0xFF1193D4),
          badgeText: "AI Scanner",
          badgeColor: const Color(0xFF1193D4),
          title: "1. PDF / Image Analyze Option",
          description:
              "Upload a timetable PDF or picture. The smart analyzer will scan the document, detect days and period slots, and pre-fill the layout grid automatically.",
          onTap: () {
            setState(() {
              _currentStep = MakeTimetableStep.pdfAnalyze;
            });
          },
        ),

        const SizedBox(height: 16),

        // Option 2: Make from Scratch
        _buildModeOptionCard(
          icon: Icons.grid_view_rounded,
          iconColor: const Color(0xFF10B981),
          badgeText: "Manual Builder",
          badgeColor: const Color(0xFF10B981),
          title: "2. Make with Scratch",
          description:
              "Follow the standard classroom builder flow. Configure periods and break intervals in the layout maker, then drag & drop assign faculty in the schedule creator.",
          onTap: () {
            setState(() {
              _currentStep = MakeTimetableStep.fromScratch;
            });
          },
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildModeOptionCard({
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ── Step 2A: Make from Scratch Configuration ──
  Widget _buildFromScratchConfigView(List<ClassModel> createdClasses, List<TeacherModel> allTeachers) {
    return Column(
      key: const ValueKey('fromScratch'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _currentStep = MakeTimetableStep.selectMode),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Make Timetable from Scratch",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  "Select the target class to launch the layout maker",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),

        // Class & Division Selector
        const Text("Select Class & Division", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _buildClassSelector(createdClasses, allTeachers),

        const SizedBox(height: 16),

        // Teacher Info / Selector
        const Text("Class Teacher", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _buildTeacherSelector(allTeachers),

        const SizedBox(height: 28),

        // Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = MakeTimetableStep.selectMode),
              child: const Text("Back"),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _proceedFromScratch,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text("Launch Layout Maker", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 2B: PDF / Image Analyze Configuration ──
  Widget _buildPdfAnalyzeConfigView() {
    return Column(
      key: const ValueKey('pdfAnalyze'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _currentStep = MakeTimetableStep.selectMode),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Analyze Timetable Document",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Text(
                  "Upload all-classes timetable PDF to auto-detect schedules and faculty",
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 20),

        // File Upload Drop Zone
        const Text("Upload Timetable File (PDF or Image)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _buildFileUploadArea(),

        const SizedBox(height: 16),

        // Multi-Class Detection Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Multi-Class Master Schedule Detection",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "• Extracts all class timetables (Science, CS, Commerce, Humanities)\n"
                "• Detects 7-period daily slots, morning intervals, lunch breaks, and timings\n"
                "• Scans faculty workload, subject codes, and teacher assignments\n"
                "• Opens dedicated multi-class timetable editor with layout & faculty panel",
                style: TextStyle(fontSize: 12, color: Color(0xFF15803D), height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Analyze & Generate Button
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = MakeTimetableStep.selectMode),
              child: const Text("Back"),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1193D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _startPdfAnalysis,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text("Analyze & Open Editor", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 3: Progressive Analysis Animation Screen ──
  Widget _buildAnalyzingProgressView() {
    return Container(
      key: const ValueKey('analyzingProgress'),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1193D4).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF1193D4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Analyzing Timetable...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _analysisSteps[_analysisStepIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1193D4),
            ),
          ),
          const SizedBox(height: 24),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_analysisStepIndex + 1) / _analysisSteps.length,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF1193D4),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Step ${_analysisStepIndex + 1} of ${_analysisSteps.length}",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFileUploadArea() {
    if (_uploadedFile != null) {
      final isPdf = _uploadedFile!.name.toLowerCase().endsWith('.pdf');
      final sizeKb = (_uploadedFile!.size / 1024).toStringAsFixed(1);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                color: isPdf ? Colors.redAccent : const Color(0xFF1193D4),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _uploadedFile!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Text("$sizeKb KB • Ready for analysis", style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _pickResourceFile,
              icon: const Icon(Icons.change_circle_rounded, size: 16),
              label: const Text("Change", style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickResourceFile,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: const Radius.circular(14),
          color: const Color(0xFF1193D4).withValues(alpha: 0.5),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF1193D4), size: 28),
              ),
              const SizedBox(height: 10),
              const Text(
                "Click to upload Timetable PDF or Image",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                "Supports PDF, PNG, JPG, JPEG documents",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassSelector(List<ClassModel> createdClasses, List<TeacherModel> allTeachers) {
    if (createdClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: const Text(
          "No classes created yet. Please create classes first under Classroom Management.",
          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ClassModel>(
          isExpanded: true,
          hint: const Text("Select Class & Division"),
          value: _selectedClass,
          items: createdClasses.map((c) {
            return DropdownMenuItem<ClassModel>(
              value: c,
              child: Text(
                "Class ${c.classNo} - Division ${c.division}${c.teacherName.isNotEmpty ? ' (${c.teacherName})' : ''}",
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedClass = val;
              if (val != null && val.teacherId.isNotEmpty) {
                _selectedTeacher = allTeachers.firstWhere(
                  (t) => t.id == val.teacherId,
                  orElse: () => TeacherModel(
                    id: val.teacherId,
                    employeeId: '',
                    mobileNo: '',
                    teacherName: val.teacherName,
                    classNo: int.tryParse(val.classNo) ?? 0,
                    division: val.division,
                    subject: '',
                    email: '',
                    password: '',
                    address: '',
                    gender: '',
                    imageUrl: '',
                    delete: false,
                    isLanguageTeacher: false,
                    createdDate: DateTime.now(),
                    dateOfBirth: DateTime(1990),
                  ),
                );
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTeacherSelector(List<TeacherModel> allTeachers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TeacherModel>(
          isExpanded: true,
          hint: const Text("Select Class Teacher"),
          value: _selectedTeacher,
          items: allTeachers.map((t) {
            return DropdownMenuItem<TeacherModel>(
              value: t,
              child: Text(
                "${t.teacherName} (Class ${t.classNo}${t.division.isNotEmpty ? '-${t.division}' : ''})",
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedTeacher = val;
            });
          },
        ),
      ),
    );
  }
}
