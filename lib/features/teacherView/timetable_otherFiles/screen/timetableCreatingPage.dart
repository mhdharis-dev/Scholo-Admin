import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
      builder: (context) => AlertDialog(
        title: const Text("Discard Changes?"),
        content: const Text(
          "Are you sure you want to cancel? All progress on this timetable layout will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No, Keep Editing"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
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
      builder: (context) => AlertDialog(
        title: const Text("Edit Layout?"),
        content: const Text(
          "Are you sure you want to Edit? All assignments on this timetable will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No, Keep Doing"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDF1616),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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
      Navigator.of(context).popUntil((route) => route.isFirst);

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
      builder: (context) => AlertDialog(
        title: const Text("Save as Draft?"),
        content: const Text(
          "Do you want to save your progress as a draft? You can resume editing later.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);

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

  // --- CENTERED MULTI-TEACHER SELECTION DIALOG ---
  void _showTeacherSelectionDialog(String day, int index) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: 400,
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

                        List<Widget> listItems = [];

                        // 1. Add Head Teacher (Class Teacher)
                        final headData = {
                          'name': teacher.teacherName,
                          'id': widget.teacherId,
                          'subject': teacher.subject,
                          'color': const Color(0xFF2563EB),
                        };

                        listItems.add(
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            secondary: const CircleAvatar(
                              backgroundColor: Color(0xFFBFDBFE),
                              child: Icon(Icons.star, color: Color(0xFF2563EB), size: 18),
                            ),
                            title: Text(teacher.teacherName,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(teacher.subject,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.bold)),
                            value: isSelected(widget.teacherId),
                            onChanged: (bool? val) => toggleSelection(headData),
                          ),
                        );

                        listItems.add(const Divider());

                        // 2. Add Other Faculty
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

                          listItems.add(
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: CircleAvatar(
                                backgroundColor: c.withValues(alpha: 0.2),
                                child: Text(ot.teacherName[0],
                                    style: TextStyle(color: c, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(ot.teacherName,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(ot.subject,
                                  style: TextStyle(
                                      fontSize: 10, color: c, fontWeight: FontWeight.bold)),
                              value: isSelected(ot.teacherId),
                              onChanged: (bool? val) => toggleSelection(otData),
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Select Teacher(s)",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(child: ListView(children: listItems)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  // Apply the selections back to the main grid state
                                  setState(() {
                                    if (currentSelections.isEmpty) {
                                      _gridData[day]![index].remove('assignedTeachers');
                                    } else {
                                      _gridData[day]![index]['assignedTeachers'] =
                                          currentSelections;
                                    }
                                  });
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text("Apply Assignment",
                                    style: TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold)),
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
              var temp = List<Map<String, dynamic>>.from(
                slot['assignedTeachers'],
              );
              _gridData[sourceDay]![sourceIndex]['assignedTeachers'] = temp;
            } else {
              _gridData[sourceDay]![sourceIndex].remove('assignedTeachers');
            }
            _gridData[day]![index]['assignedTeachers'] =
                draggedData['teachersData'];
          } else {
            _gridData[day]![index]['assignedTeachers'] = [
              {
                'name': draggedData['name'],
                'id': draggedData['teacherId'],
                'subject': draggedData['subject'],
                'color': draggedData['color'],
              },
            ];
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
    String displaySubject = assignedTeachers
        .map((t) => t['subject'])
        .join(' / ');
    String displayTeacher = assignedTeachers.map((t) => t['name']).join(', ');
    Color displayColor = assignedTeachers.first['color'] as Color;

    final dragData = {
      'teachersData': assignedTeachers,
      'sourceDay': sourceDay,
      'sourceIndex': sourceIndex,
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
                        ),
                      ),
                    ),
                  );
                }
              }
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
  ) {
    return Draggable<Map<String, dynamic>>(
      data: teacherData,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(width: 280, child: uiChild),
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
                          if (isHeadTeacher)
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: Color(0xFFF59E0B),
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
