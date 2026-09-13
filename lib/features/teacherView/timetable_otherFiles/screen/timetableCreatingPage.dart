import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/otherTeacher_model.dart';
import '../../../../models/daftTimetable_model.dart';
import '../../../../models/dayShedule_model.dart';
import '../../../../models/period_model.dart';
import '../../../../models/timeTable_model.dart';
import '../controller/timetable_adding_controller.dart';
import '../repository/timetable_adding_repository.dart';

final selectedDayProvider = StateProvider<String>((ref) => 'Monday');

final dayTypeProvider = StateProvider<Map<String, String>>((ref) {
  return {
    'Sunday': 'Non-Working Day',
    'Monday': 'Non-Working Day',
    'Tuesday': 'Non-Working Day',
    'Wednesday': 'Non-Working Day',
    'Thursday': 'Non-Working Day',
    'Friday': 'Non-Working Day',
    'Saturday': 'Non-Working Day',
  };
});

final scheduleProvider = StateProvider<Map<String, List<Map<String, dynamic>>>>(
  (ref) {
    return {
      'Sunday': [],
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    };
  },
);

class TimeTableCreatingPage extends ConsumerStatefulWidget {
  final String teacherId;
  final String timetableName;
  final Map<String, List<Map<String, dynamic>>> scheduleData;
  final Map<String, String> dayTypes;
  final String? draftId; // <-- NEW: Added to track if we loaded a draft

  const TimeTableCreatingPage({
    super.key,
    required this.teacherId,
    required this.timetableName,
    required this.scheduleData,
    required this.dayTypes,
    this.draftId, // <-- NEW
  });

  @override
  ConsumerState<TimeTableCreatingPage> createState() =>
      _TimeTableCreatingPageState();
}

class _TimeTableCreatingPageState extends ConsumerState<TimeTableCreatingPage> {
  bool _isCoverageExpanded = false;
  late TextEditingController _titleController;

  late Map<String, List<Map<String, dynamic>>> _gridData;
  String? currentDraftId; // <-- NEW: State variable to track the draft ID

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.timetableName);
    currentDraftId = widget.draftId; // <-- Assign the ID from the previous page

    _gridData = {};
    widget.scheduleData.forEach((day, slots) {
      _gridData[day] = slots.map((s) => Map<String, dynamic>.from(s)).toList();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<String> get _workingDays {
    return [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ].where((day) => widget.dayTypes[day] == 'Working Day').toList();
  }

  String _calcDuration(String start, String end) {
    TimeOfDay parseTime(String t) {
      final match = RegExp(r'(\d+):(\d+) (\w+)').firstMatch(t)!;
      int h = int.parse(match.group(1)!);
      int m = int.parse(match.group(2)!);
      if (match.group(3) == "PM" && h < 12) h += 12;
      if (match.group(3) == "AM" && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: m);
    }

    final s = parseTime(start);
    final e = parseTime(end);
    int diff = (e.hour * 60 + e.minute) - (s.hour * 60 + s.minute);
    if (diff < 0) diff += 1440;
    return diff.toString();
  }

  Future<void> _publishTimetable() async {
    // 1. Validation Logic
    bool isFullyAssigned = true;
    for (var day in _workingDays) {
      for (var slot in _gridData[day] ?? []) {
        if (slot['type'] == 'period' &&
            (!slot.containsKey('assignedTeachers') ||
                (slot['assignedTeachers'] as List).isEmpty)) {
          isFullyAssigned = false;
          break;
        }
      }
      if (!isFullyAssigned) break;
    }

    if (!isFullyAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please assign a teacher to every period slot."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide a valid Timetable Title."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Prepare Data Models
    final teacherAsync = ref.read(teacherStreamProvider(widget.teacherId));
    final teacher = teacherAsync.value;

    if (teacher == null) return;

    int overallTotalPeriods = 0;
    Map<String, DayScheduleModel> processedWorkingDays = {};

    for (String day in _workingDays) {
      List<Map<String, dynamic>> rawSlots = _gridData[day] ?? [];
      int dailyPeriods = rawSlots.where((s) => s['type'] == 'period').length;
      overallTotalPeriods += dailyPeriods;

      List<PeriodSlotModel> processedSlots = rawSlots.map((slot) {
        List<dynamic>? teachers = slot['assignedTeachers'];
        return PeriodSlotModel(
          periodName: slot['name'] ?? '',
          type: slot['type'] ?? 'period',
          startTime: slot['start'] ?? '',
          endTime: slot['end'] ?? '',
          teacherName: teachers?.map((t) => t['name']).join(', '),
          teacherId: teachers?.map((t) => t['id']).join(', '),
          subject: teachers?.map((t) => t['subject']).join(' / '),
          mainSubject: slot['mainSubject'] as String?,
          colorValue: teachers?.isNotEmpty == true
              ? (teachers!.first['color'] as Color).toARGB32()
              : null,
        );
      }).toList();

      processedWorkingDays[day] = DayScheduleModel(
        status: 'Working Day',
        totalPeriods: dailyPeriods,
        periods: processedSlots,
      );
    }

    final timetableModel = TimetableModel(
      timetableName: _titleController.text.trim(),
      classTeacherId: widget.teacherId,
      classTeacherName: teacher.teacherName,
      classNo: teacher.classNo.toString(),
      division: teacher.division,
      totalWorkingDays: _workingDays.length,
      totalPeriods: overallTotalPeriods,
      createdDate: DateTime.now(),
      delete: false,
      workingDays: processedWorkingDays,
    );

    // 3. Call Controller
    // The controller handles the Loading Dialog and Firestore logic
    await ref.read(timetableControllerProvider.notifier).publishTimetable(
      context: context,
      classNo: teacher.classNo.toString(),
      division: teacher.division,
      timetableName: _titleController.text.trim(),
      model: timetableModel,
      currentDraftId: currentDraftId,
      onSuccess: () {
        // Reset providers and go home
        ref.invalidate(selectedDayProvider);
        // Invalidate any other specific creation providers here
        Navigator.of(context).popUntil((route) => route.isFirst);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Timetable successfully published!"),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  void _handleCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Discard Changes?"),
        content: const Text(
          "Are you sure you want to cancel? All progress on this timetable layout will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("No, Keep Editing"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              _saveDraft();
            },
            child: const Text("Save Draft"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDF1616),
            ),
            onPressed: () {
              ref.invalidate(selectedDayProvider);
              ref.invalidate(dayTypeProvider);
              ref.invalidate(scheduleProvider);
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context);       // Close page
            },
            child: const Text("Discard", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleEdit(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Layout?"),
        content: const Text(
          "Are you sure you want to Edit? All assignments on this timetable will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("No, Keep Doing"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDF1616),
            ),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context);       // Close page
            },
            child: const Text(
              "Yes, Edit",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Assignments?"),
        content: const Text(
          "This will remove all teachers assigned to the timetable grid. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                for (var d in _workingDays) {
                  for (var s in _gridData[d]!) {
                    s.remove('assignedTeachers');
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text(
              "Clear Everything",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: SAVE DRAFT ---
  Future<void> _saveDraft() async {
    // 1. Convert current _gridData into the Model format
    Map<String, List<PeriodSlotModel>> processedSchedule = {};

    _gridData.forEach((day, slots) {
      processedSchedule[day] = slots.map((slot) {
        int? slotColor;
        if (slot['color'] != null) {
          slotColor = slot['color'] is Color
              ? (slot['color'] as Color).toARGB32()
              : slot['color'];
        }

        List<dynamic>? teachers = slot['assignedTeachers'];
        String? joinedNames;
        String? joinedIds;
        String? joinedSubjects;

        if (teachers != null && teachers.isNotEmpty) {
          joinedNames = teachers.map((t) => t['name']).join(', ');
          joinedIds = teachers.map((t) => t['id']).join(', ');
          joinedSubjects = teachers.map((t) => t['subject']).join(' / ');
          slotColor ??= teachers.first['color'] is Color
                ? (teachers.first['color'] as Color).toARGB32()
                : teachers.first['color'];
        }

        return PeriodSlotModel(
          periodName: slot['name'] ?? '',
          type: slot['type'] ?? 'period',
          startTime: slot['start'] ?? '',
          endTime: slot['end'] ?? '',
          teacherName: joinedNames,
          teacherId: joinedIds,
          subject: joinedSubjects,
          mainSubject: slot['mainSubject'] as String?,
          colorValue: slotColor,
        );
      }).toList();
    });

    // 2. Create the Draft Model
    final draftModel = DraftTimetableModel(
      teacherId: widget.teacherId,
      timetableName: _titleController.text.trim().isEmpty
          ? 'Untitled Draft'
          : _titleController.text.trim(),
      status: 'timetable',
      createdDate: DateTime.now(),
      dayTypes: widget.dayTypes,
      scheduleData: processedSchedule,
      delete: false,
    );

    // 3. Call the Controller to handle the Save/Update logic
    final newId = await ref.read(timetableControllerProvider.notifier).saveDraft(
      context: context,
      model: draftModel,
      currentDraftId: currentDraftId,
    );

    // 4. On success, clean up and navigate
    if (newId != null && mounted) {
      // Update local currentDraftId in case we want to stay on page (optional)
      setState(() => currentDraftId = newId);

      // Invalidate setup-related providers
      ref.invalidate(selectedDayProvider);
      // Add other setup providers to invalidate here if necessary

      // Navigate back to the start
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Draft saved and closed successfully!"),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showSaveDraftConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Save as Draft?"),
        content: const Text(
          "Do you want to save your progress as a draft? You can resume editing later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              _saveDraft();
            },
            child: const Text(
              "Save Draft",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTeacherCard({
    required Map<String, dynamic> teacherData,
    required bool isSelected,
    required bool isClassTeacher,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    String displaySubject = teacherData['subject'].toUpperCase();
    if (displaySubject == 'PET' || displaySubject == 'P.E.T') {
      displaySubject = 'P E T';
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Circular Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: isClassTeacher
                  ? Icon(Icons.star_border_rounded, color: accentColor, size: 22)
                  : Text(
                      teacherData['name'].isNotEmpty
                          ? (teacherData['name'].toUpperCase() == 'RAMESH'
                              ? 'r'
                              : teacherData['name'][0].toUpperCase())
                          : '?',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacherData['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displaySubject,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // --- CENTERED MULTI-TEACHER SELECTION DIALOG ---
  void _showTeacherSelectionDialog(String day, int index) {
    final mainSubjectController = TextEditingController(
      text: _gridData[day]![index]['mainSubject'] as String? ?? '',
    );
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias, // Clip shaded bottom bar to dialog corners
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 480,
            ),
            child: Consumer(
              builder: (context, ref, child) {
                // Use the refactored stream provider
                final teacherAsync = ref.watch(teacherStreamProvider(widget.teacherId));

                return teacherAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text(
                      "Error loading teachers: $err",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  data: (teacher) {
                    final colors = [
                      const Color(0xFF10B981),
                      const Color(0xFFF59E0B),
                      const Color(0xFF0D68E8),
                      const Color(0xFFA855F7),
                      const Color(0xFFDC159F),
                    ];

                    // Local copy of selections to manage within the dialog state
                    List<Map<String, dynamic>> currentSelections =
                    _gridData[day]![index]['assignedTeachers'] != null
                        ? List<Map<String, dynamic>>.from(
                      _gridData[day]![index]['assignedTeachers'],
                    )
                        : [];

                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        bool isSelected(String id) =>
                            currentSelections.any((t) => t['id'] == id);

                        void toggleSelection(Map<String, dynamic> data) {
                          setDialogState(() {
                            if (isSelected(data['id'])) {
                              currentSelections.removeWhere((t) => t['id'] == data['id']);
                            } else {
                              currentSelections.add(data);
                            }
                          });
                        }

                        final query = searchController.text.toLowerCase().trim();

                        // Filter Class Teacher
                        bool showHeadTeacher = false;
                        final headData = {
                          'name': teacher.teacherName,
                          'id': widget.teacherId,
                          'subject': teacher.subject,
                          'color': const Color(0xFF2563EB),
                        };
                        if (query.isEmpty ||
                            (headData['name'] as String).toLowerCase().contains(query) ||
                            (headData['subject'] as String).toLowerCase().contains(query)) {
                          showHeadTeacher = true;
                        }

                        // Filter Other Teachers
                        final filteredOtherTeachersList = <Map<String, dynamic>>[];
                        final otherTeachers = teacher.otherTeachers ?? [];
                        for (int i = 0; i < otherTeachers.length; i++) {
                          final ot = otherTeachers[i];
                          final c = colors[i % colors.length];
                          final otData = {
                            'name': ot.teacherName,
                            'id': ot.teacherId,
                            'subject': ot.subject,
                            'color': c,
                          };
                          if (query.isEmpty ||
                              (otData['name'] as String).toLowerCase().contains(query) ||
                              (otData['subject'] as String).toLowerCase().contains(query)) {
                            filteredOtherTeachersList.add(otData);
                          }
                        }

                        List<Widget> listItems = [];

                        // 1. Add Head Teacher (Class Teacher)
                        if (showHeadTeacher) {
                          listItems.add(
                            _buildDialogTeacherCard(
                              teacherData: headData,
                              isSelected: isSelected(widget.teacherId),
                              isClassTeacher: true,
                              accentColor: const Color(0xFF2563EB),
                              onTap: () => toggleSelection(headData),
                            ),
                          );
                        }

                        // 2. Add Other Faculty
                        for (final otData in filteredOtherTeachersList) {
                          listItems.add(
                            _buildDialogTeacherCard(
                              teacherData: otData,
                              isSelected: isSelected(otData['id']),
                              isClassTeacher: false,
                              accentColor: otData['color'],
                              onTap: () => toggleSelection(otData),
                            ),
                          );
                        }

                        if (listItems.isEmpty) {
                          listItems.add(
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                  "No teachers found matching search",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Sticky Header
                            Padding(
                              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Select Teacher(s)",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => Navigator.pop(dialogContext),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            // 2. Scrollable Body
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Search bar
                                    TextFormField(
                                      controller: searchController,
                                      onChanged: (val) {
                                        setDialogState(() {});
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Search by name or subject...",
                                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                        prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ...listItems,
                                    const SizedBox(height: 24),
                                    if (currentSelections.length > 1) ...[
                                      const Text(
                                        "ENTER MAIN SUBJECT NAME",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: mainSubjectController,
                                        decoration: InputDecoration(
                                          hintText: "e.g., Second Language",
                                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // 3. Shaded Sticky Footer
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            Container(
                              color: const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.all(24),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    if (currentSelections.length > 1 &&
                                        mainSubjectController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Please enter a main subject name"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    // Apply the selections back to the main grid state
                                    setState(() {
                                      if (currentSelections.isEmpty) {
                                        _gridData[day]![index].remove('assignedTeachers');
                                        _gridData[day]![index].remove('mainSubject');
                                      } else {
                                        _gridData[day]![index]['assignedTeachers'] =
                                            currentSelections;
                                        if (currentSelections.length == 1) {
                                          _gridData[day]![index]['mainSubject'] =
                                              currentSelections[0]['subject'];
                                        } else {
                                          _gridData[day]![index]['mainSubject'] =
                                              mainSubjectController.text.trim();
                                        }
                                      }
                                    });
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text("Apply Assignment",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Watch the controller state
    final controllerState = ref.watch(timetableControllerProvider);

    // 2. Determine if the UI should be "busy"
    final isLoading = controllerState is AsyncLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // 3. Use an AbsorbPointer to prevent accidental clicks while saving/publishing
      body: AbsorbPointer(
        absorbing: isLoading,
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Create Timetable",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTopInfoBar(),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 19, child: _buildDynamicTimetableGrid()),
                        const SizedBox(width: 24),
                        Expanded(flex: 7, child: _buildRightSidebar()),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Global Loading Overlay
            if (isLoading)
              Container(
                color: Colors.white.withValues(alpha: 0.6),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TOP INFO BAR & EDITABLE TITLE
  // ==========================================
  Widget _buildTopInfoBar() {
    // Use the refactored teacherStreamProvider from your repository
    final teacherAsync = ref.watch(teacherStreamProvider(widget.teacherId));

    return teacherAsync.when(
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
        child: Text("Error loading teacher info: $err", style: const TextStyle(color: Colors.red)),
      ),
      data: (teacher) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TIMETABLE TITLE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 24,
                    child: TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        fillColor: Colors.white,
                        isDense: true,
                        hintText: "Enter Timetable Title...",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _divider(),
            Expanded(
              flex: 1,
              child: _headerInfoItem("CLASS", "Class ${teacher.classNo}"),
            ),
            _divider(),
            Expanded(
              flex: 1,
              child: _headerInfoItem("DIVISION", teacher.division),
            ),
            _divider(),
            Expanded(
              flex: 2,
              child: _headerInfoItem("CLASS TEACHER", teacher.teacherName),
            ),
            Expanded(
              flex: 2,
              child: _btn(
                label: 'Edit Layout',
                icon: Icons.edit,
                color: Colors.blue,
                textColor: Colors.white,
                onTap: () => _handleEdit(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 35,
      width: 1,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.only(top: 4, left: 24, right: 24),
    );
  }

  Widget _headerInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ==========================================
  // DYNAMIC TIMETABLE GRID & DRAG/DROP
  // ==========================================
  Widget _buildDynamicTimetableGrid() {
    final workingDays = _workingDays;

    if (workingDays.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text("No working days configured for this layout."),
        ),
      );
    }

    final templateDay = workingDays.first;
    final templateSlots = _gridData[templateDay] ?? [];
    List<Widget> rows = [];
    rows.add(_buildDayHeaders(workingDays));

    for (int i = 0; i < templateSlots.length; i++) {
      final slotTemp = templateSlots[i];
      final isBreak = slotTemp['type'] == 'break';
      final isLast = i == templateSlots.length - 1;

      if (isBreak) {
        String duration = _calcDuration(slotTemp['start'], slotTemp['end']);
        rows.add(
          _buildBreakRow(
            slotTemp['name'].toString().toUpperCase(),
            "${slotTemp['name'].toString().toUpperCase()} - $duration MINUTES",
            const Color(0xFF3B82F6),
            isLast: isLast,
          ),
        );
      } else {
        List<Widget> cells = [];
        for (String day in workingDays) {
          final daySlots = _gridData[day] ?? [];
          if (i < daySlots.length) {
            cells.add(_buildDraggableCell(day, i, daySlots[i]));
          } else {
            cells.add(const Expanded(child: SizedBox()));
          }
        }
        rows.add(
          _buildTimeRow(
            startTime: slotTemp['start'],
            endTime: slotTemp['end'],
            title: slotTemp['name'],
            cells: cells,
            isLast: isLast,
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildDraggableCell(String day, int index, Map<String, dynamic> slot) {
    final bool isAssigned =
        slot.containsKey('assignedTeachers') &&
        (slot['assignedTeachers'] as List).isNotEmpty;

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (draggedDetails) {
        final draggedData = draggedDetails.data;
        setState(() {
          if (draggedData.containsKey('sourceDay')) {
            final sourceDay = draggedData['sourceDay'];
            final sourceIndex = draggedData['sourceIndex'];

            if (isAssigned) {
              var tempTeachers = List<Map<String, dynamic>>.from(
                slot['assignedTeachers'],
              );
              var tempMainSubject = slot['mainSubject'];
              _gridData[sourceDay]![sourceIndex]['assignedTeachers'] = tempTeachers;
              _gridData[sourceDay]![sourceIndex]['mainSubject'] = tempMainSubject;
            } else {
              _gridData[sourceDay]![sourceIndex].remove('assignedTeachers');
              _gridData[sourceDay]![sourceIndex].remove('mainSubject');
            }
            _gridData[day]![index]['assignedTeachers'] =
                draggedData['teachersData'];
            _gridData[day]![index]['mainSubject'] =
                draggedData['mainSubject'];
          } else {
            _gridData[day]![index]['assignedTeachers'] = [
              {
                'name': draggedData['name'],
                'id': draggedData['teacherId'],
                'subject': draggedData['subject'],
                'color': draggedData['color'],
              },
            ];
            _gridData[day]![index]['mainSubject'] = draggedData['subject'];
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: isAssigned
              ? GestureDetector(
                  onTap: () => _showTeacherSelectionDialog(day, index),
                  child: _draggableClassCard(
                    slot['assignedTeachers'],
                    day,
                    index,
                  ),
                )
              : _buildEmptySlotCard(
                  onTap: () => _showTeacherSelectionDialog(day, index),
                ),
        );
      },
    );
  }

  Widget _draggableClassCard(
    List<dynamic> assignedTeachers,
    String sourceDay,
    int sourceIndex,
  ) {
    final mainSubject = _gridData[sourceDay]![sourceIndex]['mainSubject'] as String?;
    String displaySubject = (mainSubject != null && mainSubject.isNotEmpty)
        ? mainSubject
        : assignedTeachers.map((t) => t['subject']).join(' / ');
    String displayTeacher = assignedTeachers.map((t) => t['name']).join(', ');
    Color displayColor = assignedTeachers.first['color'] as Color;

    final dragData = {
      'teachersData': assignedTeachers,
      'sourceDay': sourceDay,
      'sourceIndex': sourceIndex,
      'mainSubject': _gridData[sourceDay]![sourceIndex]['mainSubject'],
    };

    Widget cardContent = Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(color: displayColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displaySubject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: displayColor == const Color(0xFF94A3B8)
                        ? const Color(0xFF475569)
                        : displayColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  displayTeacher,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onPanDown: (_) {},
            child: IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _gridData[sourceDay]![sourceIndex].remove('assignedTeachers');
                });
              },
            ),
          ),
        ],
      ),
    );

    return Draggable<Map<String, dynamic>>(
      data: dragData,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 150, child: cardContent),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          setState(() {
            _gridData[sourceDay]![sourceIndex].remove('assignedTeachers');
          });
        }
      },
      child: cardContent,
    );
  }

  Widget _buildDayHeaders(List<String> days) {
    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 100),
          ...days.map(
            (day) => Expanded(
              child: Center(
                child: Text(
                  day.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required String startTime,
    required String endTime,
    required String title,
    required List<Widget> cells,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey.shade100,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 100,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$startTime - ',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        endTime,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(width: 1, color: Colors.grey.shade100),
            ...cells.map(
              (cell) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: cell,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakRow(
    String label,
    String title,
    Color color, {
    bool isLast = false,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade100),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RIGHT SIDEBAR & TEACHER DRAGGABLES
  // ==========================================
  Widget _buildRightSidebar() {
    return Column(
      children: [
        _buildCoverageCard(),
        const SizedBox(height: 24),
        _buildFacultyCard(),
        const SizedBox(height: 24),
        _buildActionCard(),
      ],
    );
  }

  Widget _buildCoverageCard() {
    int totalWorkingDays = _workingDays.length;
    int totalPeriods = 0;
    int filledPeriods = 0;

    for (var day in _workingDays) {
      for (var slot in _gridData[day] ?? []) {
        if (slot['type'] == 'period') {
          totalPeriods++;
          if (slot.containsKey('assignedTeachers') &&
              (slot['assignedTeachers'] as List).isNotEmpty) {
            filledPeriods++;
          }
        }
      }
    }

    double percentage = totalPeriods == 0 ? 0 : filledPeriods / totalPeriods;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TIMETABLE COVERAGE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(
                    () => _isCoverageExpanded = !_isCoverageExpanded,
                  ),
                  icon: Icon(
                    _isCoverageExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "${(percentage * 100).toInt()}%",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "$filledPeriods/$totalPeriods slots filled",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF3B82F6),
                ),
              ),
            ),
            if (_isCoverageExpanded) ...[
              const SizedBox(height: 24),
              _coverageStat(
                "Total Periods",
                "$totalPeriods",
                const Color(0xFFA855F7),
              ),
              const SizedBox(height: 12),
              _coverageStat(
                "Total Working Days",
                "$totalWorkingDays",
                const Color(0xFF10B981),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coverageStat(String label, String value, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
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

  void _showAddTeacherBottomSheet(
    TeacherModel mainTeacher, {
    OtherTeacherModel? editTeacher,
    bool isEditingClassTeacher = false,
  }) async {
    TeacherModel? selectedTeacher;
    final subjectController = TextEditingController(
      text: isEditingClassTeacher
          ? mainTeacher.subject
          : (editTeacher?.subject ?? ""),
    );

    // Fetch Teachers List
    final snapshot = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .where("delete", isEqualTo: false)
        .get();

    final allTeachers = snapshot.docs.map((e) {
      final map = Map<String, dynamic>.from(e.data());
      if (map['id'] == null || map['id'].toString().isEmpty) {
        map['id'] = e.id;
      }
      return TeacherModel.fromMap(map);
    }).toList();

    if (isEditingClassTeacher) {
      selectedTeacher = mainTeacher;
    } else if (editTeacher != null) {
      final matches = allTeachers.where((t) =>
          (t.id.isNotEmpty && t.id == editTeacher.teacherId) ||
          (t.teacherName.isNotEmpty && t.teacherName.trim().toLowerCase() == editTeacher.teacherName.trim().toLowerCase()));
      if (matches.isNotEmpty) {
        selectedTeacher = matches.first;
      }
    }

    // Already added teacher IDs
    final existingIds =
        mainTeacher.otherTeachers?.map((e) => e.teacherId).toList() ?? [];

    // Filter teachers
    final teacherList = isEditingClassTeacher
        ? [mainTeacher]
        : allTeachers.where((t) {
            if (editTeacher != null &&
                ((t.id.isNotEmpty && t.id == editTeacher.teacherId) ||
                 (t.teacherName.isNotEmpty && t.teacherName.trim().toLowerCase() == editTeacher.teacherName.trim().toLowerCase()))) {
              return true;
            }
            return t.id != widget.teacherId && !existingIds.contains(t.id);
          }).toList();

    if (!mounted) return;

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
                      Text(
                        (editTeacher == null && !isEditingClassTeacher)
                            ? "Add Other Teacher"
                            : isEditingClassTeacher
                                ? "Edit Class Teacher"
                                : "Edit Other Teacher",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Teacher Dropdown
                      DropdownButtonFormField<TeacherModel>(
                        initialValue: teacherList.contains(selectedTeacher)
                            ? selectedTeacher
                            : teacherList.where((t) => t == selectedTeacher).firstOrNull,
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
                        onChanged: isEditingClassTeacher
                            ? null
                            : (value) {
                                setState(() {
                                  selectedTeacher = value;
                                  if (subjectController.text.isEmpty) {
                                    subjectController.text = selectedTeacher?.subject ?? "";
                                  }
                                });
                              },
                      ),
                      const SizedBox(height: 15),

                      // Subject Field
                      SizedBox(
                        height: 65,
                        width: double.infinity,
                        child: TextFormField(
                          controller: subjectController,
                          onChanged: (txt) {
                            setState(() {});
                          },
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            labelText: "Enter Subject",
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
                      ),
                      const SizedBox(height: 15),

                      // Info Card
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
                            ],
                          ),
                        ),
                      const SizedBox(height: 25),

                      // Submit Button
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
                                  .schoolCollection(FirebaseConstant.teacher)
                                  .doc(widget.teacherId);

                              if (isEditingClassTeacher) {
                                await docRef.update({
                                  "subject": subjectController.text.trim(),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "${subjectController.text.trim()} Teacher Updated Successfully",
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              final snap = await docRef.get();
                              if (!snap.exists) return;

                              final teacherData = TeacherModel.fromMap(
                                snap.data()!,
                              );

                              final list = teacherData.otherTeachers ?? [];

                              final updatedOtherTeacher = OtherTeacherModel(
                                email: selectedTeacher!.email,
                                imageUrl: selectedTeacher!.imageUrl,
                                teacherName: selectedTeacher!.teacherName,
                                teacherId: selectedTeacher!.id,
                                subject: subjectController.text.trim(),
                                employeeId: selectedTeacher!.employeeId,
                                mobileNo: int.tryParse(selectedTeacher!.mobileNo) ?? 0,
                                isPermanent: true,
                                isLanguageTeacher: selectedTeacher!.isLanguageTeacher,
                              );

                              List<OtherTeacherModel> updatedList = [];
                              if (editTeacher == null) {
                                updatedList = [...list, updatedOtherTeacher];
                              } else {
                                updatedList = list.map<OtherTeacherModel>((t) {
                                  if (t.teacherId == editTeacher.teacherId) {
                                    return updatedOtherTeacher;
                                  }
                                  return t;
                                }).toList();
                              }

                              await docRef.update({
                                "otherTeachers": updatedList
                                    .map((e) => e.toMap())
                                    .toList(),
                              });

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      editTeacher == null
                                          ? "New ${subjectController.text.trim()} Teacher Added Successfully"
                                          : "${subjectController.text.trim()} Teacher Updated Successfully",
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Error adding teacher: $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          child: Text(
                            (editTeacher == null && !isEditingClassTeacher)
                                ? "Add Teacher"
                                : "Update Teacher",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
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

  Widget _buildFacultyCard() {
    // Use the refactored stream provider
    final teacherAsync = ref.watch(teacherStreamProvider(widget.teacherId));

    // Logic remains here as it depends on the local _gridData state
    int getTeacherPeriodCount(String teacherId) {
      int count = 0;
      for (var day in _workingDays) {
        for (var slot in _gridData[day] ?? []) {
          if (slot.containsKey('assignedTeachers')) {
            List<dynamic> teachers = slot['assignedTeachers'];
            if (teachers.any((t) => t['id'] == teacherId)) count++;
          }
        }
      }
      return count;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FACULTY AVAILABILITY",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "ASSIGNED",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          teacherAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("Error: $err", style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
            data: (teacher) {
              final colors = [
                const Color(0xFF10B981),
                const Color(0xFFF59E0B),
                const Color(0xFF0D68E8),
                const Color(0xFFA855F7),
                const Color(0xFFDC159F),
              ];

              final headTeacherDragData = {
                'name': teacher.teacherName,
                'teacherId': widget.teacherId,
                'subject': teacher.subject,
                'color': const Color(0xFF2563EB),
                'imageUrl': teacher.imageUrl,
              };

              List<Widget> teacherWidgets = [];

              // 1. Add Head Teacher (Class Teacher)
              teacherWidgets.add(
                _draggableFacultyItem(
                  headTeacherDragData,
                  _facultyItemUi(
                    teacher.teacherName,
                    teacher.subject,
                    teacher.imageUrl,
                    const Color(0xFF2563EB),
                    isHeadTeacher: true,
                    periodCount: getTeacherPeriodCount(widget.teacherId),
                    onEdit: () => _showAddTeacherBottomSheet(
                      teacher,
                      isEditingClassTeacher: true,
                    ),
                  ),
                  _facultyItemUi(
                    teacher.teacherName,
                    teacher.subject,
                    teacher.imageUrl,
                    const Color(0xFF2563EB),
                    isHeadTeacher: true,
                    periodCount: getTeacherPeriodCount(widget.teacherId),
                    onEdit: null,
                    showCount: false,
                  ),
                ),
              );

              // 2. Add Other Teachers
              final otherTeachersList = teacher.otherTeachers ?? [];
              if (otherTeachersList.isNotEmpty) {
                teacherWidgets.add(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Colors.grey.shade200),
                  ),
                );

                for (int i = 0; i < otherTeachersList.length; i++) {
                  final ot = otherTeachersList[i];
                  final tColor = colors[i % colors.length];
                  final otDragData = {
                    'name': ot.teacherName,
                    'teacherId': ot.teacherId,
                    'subject': ot.subject,
                    'color': tColor,
                    'imageUrl': ot.imageUrl,
                  };
                  teacherWidgets.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _draggableFacultyItem(
                        otDragData,
                        _facultyItemUi(
                          ot.teacherName,
                          ot.subject,
                          ot.imageUrl,
                          tColor,
                          periodCount: getTeacherPeriodCount(ot.teacherId),
                          onEdit: () => _showAddTeacherBottomSheet(
                            teacher,
                            editTeacher: ot,
                          ),
                        ),
                        _facultyItemUi(
                          ot.teacherName,
                          ot.subject,
                          ot.imageUrl,
                          tColor,
                          periodCount: getTeacherPeriodCount(ot.teacherId),
                          onEdit: null,
                          showCount: false,
                        ),
                      ),
                    ),
                  );
                }
              }

              // 3. Add "add Teacher " button tile
              teacherWidgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Colors.grey.shade200),
                ),
              );
              teacherWidgets.add(
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showAddTeacherBottomSheet(teacher),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 8),
                          Text(
                            "add Teacher ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              return Column(children: teacherWidgets);
            },
          ),
        ],
      ),
    );
  }

  Widget _draggableFacultyItem(
    Map<String, dynamic> teacherData,
    Widget uiChild,
    Widget feedbackChild,
  ) {
    return Draggable<Map<String, dynamic>>(
      data: teacherData,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 280, child: feedbackChild),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: uiChild),
      child: uiChild,
    );
  }

  Widget _facultyItemUi(
    String name,
    String subject,
    String? imgUrl,
    Color statusColor, {
    bool isHeadTeacher = false,
    int periodCount = 0,
    VoidCallback? onEdit,
    bool showCount = true,
  }) {
    return Container(
      padding: isHeadTeacher ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isHeadTeacher
          ? BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isHeadTeacher
                      ? const Color(0xFFBFDBFE)
                      : const Color(0xFFE2E8F0),
                  backgroundImage: (imgUrl != null && imgUrl.isNotEmpty)
                      ? NetworkImage(imgUrl)
                      : null,
                  child: (imgUrl == null || imgUrl.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 14,
                            color: isHeadTeacher
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFF475569),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isHeadTeacher
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              if (onEdit != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit, size: 16, color: Color(0xFF3B82F6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
              ],
              if (showCount) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHeadTeacher
                        ? Colors.blue.shade200
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    periodCount.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isHeadTeacher
                        ? Colors.blue.shade900
                        : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.drag_indicator,
                size: 18,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    // Check the controller state to disable buttons during loading
    final isLoading = ref.watch(timetableControllerProvider) is AsyncLoading;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Adding a subtle shadow or border makes it pop against the background
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "EDITOR TIP",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You can drag and drop slots to add or swap teachers. Tap a slot to select multiple teachers (e.g., for language periods).",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Publish Button
          _btn(
            label: "Publish Timetable",
            icon: Icons.check_circle,
            color: Colors.green,
            textColor: Colors.white,
            // Disable tap if loading
            onTap: isLoading ? null : () => _publishTimetable(),
          ),
          const SizedBox(height: 12),

          // 2. Save Draft Button
          _btn(
            label: "Save Draft",
            icon: Icons.save,
            color: const Color(0xFF3B82F6),
            textColor: Colors.white,
            onTap: isLoading ? null : () => _showSaveDraftConfirmation(),
          ),
          const SizedBox(height: 12),

          // 3. Row for Clear and Cancel
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _btn(
                  label: "Clear All",
                  icon: Icons.refresh,
                  color: const Color(0xFFE2E8F0),
                  textColor: const Color(0xFF475569),
                  onTap: isLoading ? null : () => _showClearAllConfirmation(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _btn(
                  label: "Cancel",
                  icon: Icons.clear,
                  color: const Color(0xFFFEE2E2), // Light red background
                  textColor: const Color(0xFFEF4444), // Strong red text
                  onTap: isLoading ? null : () => _handleCancel(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SHARED UTILITY WIDGETS
// ==========================================
Widget _btn({
  required String label,
  required IconData icon,
  required Color color,
  required Color textColor,
  VoidCallback? onTap,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: textColor),
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

Widget _buildEmptySlotCard({VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: CustomPaint(
      painter: DashedRectPainter(
        color: Colors.grey.shade300,
        strokeWidth: 1.5,
        gap: 5.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(Icons.add, size: 16, color: Colors.grey.shade400),
          ),
        ),
      ),
    ),
  );
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(8),
        ),
      );
    Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
