import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import 'package:scholo_admin/features/teacherView/timetable_otherFiles/screen/timetableCreatingPage.dart';

import '../../../../models/daftTimetable_model.dart';
import '../../../../models/period_model.dart';
import '../../../../models/teacher_model.dart';

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

final teacherProvider = StreamProvider.family<TeacherModel, String>((
  ref,
  teacherId,
) {
  return FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .doc(teacherId)
      .snapshots()
      .map((snapshot) {
        if (snapshot.exists) {
          return TeacherModel.fromMap(snapshot.data()!);
        }
        throw Exception("Teacher not found");
      });
});

final draftsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) {
      return FirebaseFirestore.instance
          .schoolCollection(
            FirebaseConstant.draftTimetable,
          ) // Hardcoded per your model/logic
          .where('teacherId', isEqualTo: teacherId)
          .where('delete', isEqualTo: false)   // exclude soft-deleted
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList(),
          );
    });

class TimeTableLayoutMakerPage extends ConsumerStatefulWidget {
  final String teacherId;
  const TimeTableLayoutMakerPage({super.key, required this.teacherId});

  @override
  ConsumerState<TimeTableLayoutMakerPage> createState() =>
      _TimeTableLayoutMakerPageState();
}

class _TimeTableLayoutMakerPageState
    extends ConsumerState<TimeTableLayoutMakerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _timeTableNameController =
      TextEditingController();

  // NEW: State variable to hold the current Draft ID
  String? currentDraftId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDraftSelectionSheet();
    });
  }

  void _showDraftSelectionSheet() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDeleteMode = false;
        Set<String> selectedDraftIds = {};

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return Consumer(
                builder: (context, ref, child) {
                  final draftsAsync = ref.watch(
                    draftsProvider(widget.teacherId),
                  );

                  return Container(
                    padding: const EdgeInsets.all(24),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                      maxWidth: 500,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            "Saved Drafts",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: draftsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, stack) =>
                                Center(child: Text("Error: $err")),
                            data: (drafts) {
                              if (drafts.isEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (Navigator.canPop(dialogContext)) {
                                    ref.invalidate(selectedDayProvider);
                                    ref.invalidate(dayTypeProvider);
                                    ref.invalidate(scheduleProvider);
                                    Navigator.pop(dialogContext);
                                  }
                                });
                                return const Center(
                                  child: Text(
                                    "No drafts available.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              }

                              return ListView.builder(
                                itemCount: drafts.length,
                                itemBuilder: (context, index) {
                                  final draft = drafts[index];

                                  String name =
                                      draft['timetableName'] ??
                                      'Untitled Timetable';
                                  String status = draft['status'] ?? 'layout';
                                  DateTime date = draft['createdDate'] != null
                                      ? (draft['createdDate'] as Timestamp)
                                            .toDate()
                                      : DateTime.now();
                                  String formattedDate =
                                      "${date.day}/${date.month}/${date.year}";

                                  final String draftId =
                                      draft['id']?.toString() ?? '';
                                  final isSelected = selectedDraftIds.contains(
                                    draftId,
                                  );

                                  return Card(
                                    elevation: 0,
                                    color: const Color(0xFFF8FAFC),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isDeleteMode && isSelected
                                            ? Colors.red.shade300
                                            : Colors.grey.shade200,
                                        width: isDeleteMode && isSelected
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: status == 'timetable'
                                                    ? Colors.green.shade100
                                                    : Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status == 'timetable'
                                                    ? 'Timetable Draft'
                                                    : 'Layout Draft',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: status == 'timetable'
                                                      ? Colors.green.shade800
                                                      : Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              "Created: $formattedDate",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: isDeleteMode
                                          ? Icon(
                                              isSelected
                                                  ? Icons.check_box
                                                  : Icons
                                                        .check_box_outline_blank,
                                              color: isSelected
                                                  ? Colors.red
                                                  : Colors.grey,
                                            )
                                          : const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                      onTap: () {
                                        if (isDeleteMode) {
                                          setDialogState(() {
                                            if (isSelected) {
                                              selectedDraftIds.remove(draftId);
                                            } else {
                                              selectedDraftIds.add(draftId);
                                            }
                                          });
                                        } else {
                                          Navigator.pop(dialogContext);
                                          _loadDraft(draft);
                                        }
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  fixedSize: Size.fromHeight(50),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: isDeleteMode
                                      ? const Color(0xFFDF1616)
                                      : const Color(0xFF2563EB),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isDeleteMode
                                    ? (selectedDraftIds.isEmpty
                                          ? null
                                          : () {
                                              showDialog(
                                                context: context,
                                                builder: (confirmContext) => AlertDialog(
                                                  title: const Text(
                                                    "Delete Drafts?",
                                                  ),
                                                  content: Text(
                                                    "Are you sure you want to delete ${selectedDraftIds.length} selected draft(s)? This action cannot be undone.",
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            confirmContext,
                                                          ),
                                                      child: const Text(
                                                        "Cancel",
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFFDF1616,
                                                                ),
                                                          ),
                                                      onPressed: () async {
                                                        Navigator.pop(
                                                          confirmContext,
                                                        ); // Close alert

                                                        // Show loading dialog
                                                        showDialog(
                                                          context: context,
                                                          barrierDismissible:
                                                              false,
                                                          builder: (_) =>
                                                              const Center(
                                                                child:
                                                                    CircularProgressIndicator(),
                                                              ),
                                                        );

                                                        try {
                                                          for (var id in selectedDraftIds) {
                                                            await FirebaseFirestore.instance
                                                                .schoolCollection(FirebaseConstant.draftTimetable)
                                                                .doc(id)
                                                                .update({
                                                              'delete': true,
                                                              'deletedAt': Timestamp.fromDate(DateTime.now()),
                                                            });
                                                          }
                                                        } catch (e) {
                                                          debugPrint(
                                                            "Error deleting drafts: $e",
                                                          );
                                                        }

                                                        if (context.mounted) {
                                                          Navigator.pop(
                                                            context,
                                                          ); // Close loading dialog
                                                        }

                                                        setDialogState(() {
                                                          isDeleteMode = false;
                                                          selectedDraftIds
                                                              .clear();
                                                        });
                                                      },
                                                      child: const Text(
                                                        "Delete",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            })
                                    : () {
                                        ref.invalidate(selectedDayProvider);
                                        ref.invalidate(dayTypeProvider);
                                        ref.invalidate(scheduleProvider);
                                        Navigator.pop(dialogContext);
                                      },
                                child: draftsAsync.maybeWhen(
                                  data: (drafts) {
                                    final label = isDeleteMode
                                        ? (selectedDraftIds.length ==
                                                  drafts.length
                                              ? "Delete All"
                                              : "Delete Selected")
                                        : "Start New Layout";
                                    return Text(
                                      label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    );
                                  },
                                  orElse: () => Text(
                                    isDeleteMode
                                        ? "Delete Selected"
                                        : "Start New Layout",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: isDeleteMode
                                    ? Colors.grey.shade100
                                    : const Color(0xFFFEE2E2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(14),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  isDeleteMode = !isDeleteMode;
                                  selectedDraftIds.clear();
                                });
                              },
                              icon: Icon(
                                isDeleteMode ? Icons.close : Icons.delete,
                                color: isDeleteMode
                                    ? Colors.grey.shade700
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _loadDraft(Map<String, dynamic> draft) {
    try {

      if (draft['delete'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This draft is no longer available.")),
        );
        return;
      }

      // 1. Store the Draft ID so we can Update or Delete it later
      currentDraftId = draft['id'];

      final dayTypes = Map<String, String>.from(draft['dayTypes']);
      final name = draft['timetableName'] ?? '';

      // 2. Rebuild the schedule data into UI compatible maps
      Map<String, List<Map<String, dynamic>>> rebuiltSchedule = {};
      final rawSchedule = draft['scheduleData'] as Map<String, dynamic>? ?? {};

      rawSchedule.forEach((day, slotsList) {
        List<Map<String, dynamic>> daySlots = [];
        for (var slot in (slotsList as List<dynamic>)) {
          // Rebuild multiple teachers if they exist
          List<Map<String, dynamic>>? assignedTeachers;
          if (slot['teacherId'] != null &&
              slot['teacherId'].toString().isNotEmpty) {
            List<String> ids = slot['teacherId'].toString().split(', ');
            List<String> names = slot['teacherName'].toString().split(', ');
            List<String> subjects = slot['subject'].toString().split(' / ');

            assignedTeachers = [];
            for (int i = 0; i < ids.length; i++) {
              assignedTeachers.add({
                'id': ids[i],
                'name': i < names.length ? names[i] : '',
                'subject': i < subjects.length ? subjects[i] : '',
                'color': slot['colorValue'] != null
                    ? Color(slot['colorValue'])
                    : const Color(0xFF2563EB),
              });
            }
          }

          // Build UI Map
          Map<String, dynamic> uiSlot = {
            'name': slot['periodName'] ?? '',
            'type': slot['type'] ?? 'period',
            'start': slot['startTime'] ?? '',
            'end': slot['endTime'] ?? '',
            'mainSubject': slot['mainSubject'],
            'color': slot['colorValue'] != null
                ? Color(slot['colorValue'])
                : (slot['type'] == 'period'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFFFAF3A)),
          };

          if (assignedTeachers != null && assignedTeachers.isNotEmpty) {
            uiSlot['assignedTeachers'] = assignedTeachers;
          }

          daySlots.add(uiSlot);
        }
        rebuiltSchedule[day] = daySlots;
      });

      if (draft['status'] == 'timetable') {
        // Navigate directly to Creating Page if it already has teachers
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TimeTableCreatingPage(
              teacherId: widget.teacherId,
              timetableName: name,
              scheduleData: rebuiltSchedule,
              dayTypes: dayTypes,
              draftId: draft['id'],
            ),
          ),
        );
      } else {
        // Populate the Layout Maker page and set the State
        _timeTableNameController.text = name;
        ref.read(dayTypeProvider.notifier).state = dayTypes;
        ref.read(scheduleProvider.notifier).state = rebuiltSchedule;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading draft: $e")));
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final format = RegExp(r'(\d+):(\d+) (\w+)');
    final match = format.firstMatch(timeStr);
    int hour = int.parse(match!.group(1)!);
    int minute = int.parse(match.group(2)!);
    String ampm = match.group(3)!;
    if (ampm == "PM" && hour < 12) hour += 12;
    if (ampm == "AM" && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $ampm";
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    int totalMinutes = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(
      hour: (totalMinutes ~/ 60) % 24,
      minute: totalMinutes % 60,
    );
  }

  void _updateTimeAndCascade(
    String day,
    int index,
    String key,
    String newValue,
  ) {
    ref.read(scheduleProvider.notifier).update((state) {
      final newState = Map<String, List<Map<String, dynamic>>>.from(state);
      final List<Map<String, dynamic>> daySlots = List.from(newState[day]!);

      daySlots[index][key] = newValue;

      for (int i = index; i < daySlots.length; i++) {
        if (i + 1 < daySlots.length) {
          String currentEnd = daySlots[i]['end'];
          daySlots[i + 1]['start'] = currentEnd;

          TimeOfDay nextStart = _parseTime(daySlots[i + 1]['start']);
          TimeOfDay nextOldEnd = _parseTime(daySlots[i + 1]['end']);
          int nextDuration =
              (nextOldEnd.hour * 60 + nextOldEnd.minute) -
              (_parseTime(state[day]![i + 1]['start']).hour * 60 +
                  _parseTime(state[day]![i + 1]['start']).minute);

          daySlots[i + 1]['end'] = _formatTime(
            _addMinutes(nextStart, nextDuration),
          );
        }
      }

      newState[day] = daySlots;
      return newState;
    });
  }

  void _removeSlot(String day, int index) {
    ref.read(scheduleProvider.notifier).update((state) {
      final newState = Map<String, List<Map<String, dynamic>>>.from(state);
      final daySlots = List<Map<String, dynamic>>.from(newState[day]!);
      daySlots.removeAt(index);
      newState[day] = daySlots;
      return newState;
    });
  }

  void _showNameEditDialog(String day, int index, String currentName) {
    final TextEditingController controller = TextEditingController(
      text: currentName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name", style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter period name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateTimeAndCascade(day, index, 'name', controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addNewSlot(String type, String selectedDay) {
    ref.read(scheduleProvider.notifier).update((state) {
      final newState = Map<String, List<Map<String, dynamic>>>.from(state);

      if (newState[selectedDay]!.isEmpty &&
          selectedDay != 'Monday' &&
          newState['Monday']!.isNotEmpty) {
        newState[selectedDay] = newState['Monday']!
            .map((slot) => Map<String, dynamic>.from(slot))
            .toList();
      }

      final daySlots = newState[selectedDay]!;
      int duration;

      final firstSlotOfType = daySlots.firstWhere(
        (s) => s['type'] == type,
        orElse: () => {},
      );

      if (firstSlotOfType.isNotEmpty) {
        TimeOfDay firstStart = _parseTime(firstSlotOfType['start']);
        TimeOfDay firstEnd = _parseTime(firstSlotOfType['end']);

        int startMinutes = firstStart.hour * 60 + firstStart.minute;
        int endMinutes = firstEnd.hour * 60 + firstEnd.minute;

        duration = endMinutes - startMinutes;
        if (duration < 0) duration += 1440;
      } else {
        duration = type == 'period' ? 45 : 15;
      }

      String startTime = "09:00 AM";
      if (daySlots.isNotEmpty) {
        startTime = daySlots.last['end'];
      }

      String endTime = _formatTime(
        _addMinutes(_parseTime(startTime), duration),
      );

      int count = daySlots.where((s) => s['type'] == type).length + 1;
      String name = type == 'period' ? "Period $count" : "Break $count";

      daySlots.add({
        'type': type,
        'name': name,
        'start': startTime,
        'end': endTime,
        'color': type == 'period'
            ? const Color(0xFF2563EB)
            : const Color(0xFFFFAF3A),
      });

      return newState;
    });
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
              Navigator.pop(context); // Close page
            },
            child: const Text("Discard", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(String day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Clear $day Schedule?"),
        content: const Text(
          "This will remove all period and break slots for this day. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(scheduleProvider.notifier).update((state) {
                final newState = Map<String, List<Map<String, dynamic>>>.from(
                  state,
                );
                newState[day] = [];
                return newState;
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

  void _showCreatingAnimationAndNavigate(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide a valid timetable name.")),
      );
      return;
    }

    final dayTypes = ref.read(dayTypeProvider);
    final schedule = ref.read(scheduleProvider);
    bool hasValidWorkingDay = false;

    for (var entry in dayTypes.entries) {
      if (entry.value == 'Working Day') {
        final daySlots = schedule[entry.key] ?? [];
        final hasPeriod = daySlots.any((slot) => slot['type'] == 'period');
        if (hasPeriod) {
          hasValidWorkingDay = true;
          break;
        }
      }
    }

    if (!hasValidWorkingDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error: You must configure at least 1 Working Day with a minimum of 1 Period.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String finalTimetableName = _timeTableNameController.text.trim();
    final Map<String, List<Map<String, dynamic>>> finalScheduleData = Map.from(schedule);
    final Map<String, String> finalDayTypes = Map.from(dayTypes);

    // Soft delete the draft BEFORE showing the dialog
    if (currentDraftId != null) {
      FirebaseFirestore.instance
          .schoolCollection(FirebaseConstant.draftTimetable)
          .doc(currentDraftId)
          .update({
        'delete': true,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
      });
      currentDraftId = null;
    }

    Timer? timer;
    BuildContext? dialogCtx; // capture dialog context

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        dialogCtx = dialogContext;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                      onPressed: () {
                        timer?.cancel();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Creating Timetable...",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Finalizing configurations and checking conflicts.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );

    timer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      // Close dialog using the captured dialogCtx
      if (dialogCtx != null && Navigator.canPop(dialogCtx!)) {
        Navigator.of(dialogCtx!).pop();
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TimeTableCreatingPage(
            teacherId: widget.teacherId,
            timetableName: finalTimetableName,
            scheduleData: finalScheduleData,
            dayTypes: finalDayTypes,
            draftId: currentDraftId,
          ),
        ),
      );
    });
  }

  // --- UPDATED: SAVE DRAFT ---
  Future<void> _saveDraft() async {
    String name = _timeTableNameController.text.trim();
    if (name.isEmpty) name = 'Untitled Layout'; // Default name if empty

    try {
      final dayTypes = ref.read(dayTypeProvider);
      final schedule = ref.read(scheduleProvider);

      Map<String, List<PeriodSlotModel>> processedSchedule = {};

      schedule.forEach((day, slots) {
        processedSchedule[day] = slots.map((slot) {
          int? slotColor;
          if (slot['color'] != null) {
            slotColor = slot['color'] is Color
                ? (slot['color'] as Color).toARGB32()
                : slot['color'];
          }

          return PeriodSlotModel(
            periodName: slot['name'] ?? '',
            type: slot['type'] ?? 'period',
            startTime: slot['start'] ?? '',
            endTime: slot['end'] ?? '',
            teacherName: null,
            teacherId: null,
            subject: null,
            colorValue: slotColor,
          );
        }).toList();
      });

      final draftModel = DraftTimetableModel(
        teacherId: widget.teacherId,
        timetableName: name,
        status: 'layout',
        createdDate: DateTime.now(),
        dayTypes: dayTypes,
        scheduleData: processedSchedule,
        delete: false,
      );

      if (currentDraftId != null) {
        // FIX: Use FirebaseConstant.draftTimetable
        await FirebaseFirestore.instance
            .schoolCollection(FirebaseConstant.draftTimetable)
            .doc(currentDraftId)
            .update(draftModel.toMap());
      } else {
        // FIX: Use FirebaseConstant.draftTimetable
        final docRef = await FirebaseFirestore.instance
            .schoolCollection(FirebaseConstant.draftTimetable)
            .add(draftModel.toMap());
        currentDraftId = docRef.id;
      }

      if (mounted) {
        Navigator.pop(context); // Close page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Layout draft saved successfully!"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving draft: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              _saveDraft(); // Save the draft with existing data
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

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);

    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              _buildTopHeader(),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _buildDayTabs(ref, selectedDay),
                        const SizedBox(height: 24),
                        _buildMainScheduleCard(selectedDay),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(flex: 1, child: _buildRightPanel()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final teacherAsync = ref.watch(teacherProvider(widget.teacherId));

    return teacherAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => Text("Error: $err"),
      data: (teacher) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D94E6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(child: _buildNameInput()),
            const SizedBox(width: 40),
            _headerInfoItem("CLASS", teacher.classNo.toString()),
            const SizedBox(width: 40),
            _headerInfoItem("DIVISION", teacher.division),
            const SizedBox(width: 40),
            _headerInfoItem(
              "ASSIGNED TEACHER",
              teacher.teacherName,
              teacher: teacher,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TIMETABLE NAME",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _timeTableNameController,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: "e.g., Spring Semester 2024",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Color(0xFFDF1616), fontSize: 10),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a name for the timetable';
            }
            if (value.length < 3) return 'Name is too short';
            return null;
          },
        ),
      ],
    );
  }

  Widget _headerInfoItem(String label, String value, {TeacherModel? teacher}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (teacher != null) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFD1C4E9),
                backgroundImage: (teacher.imageUrl.isNotEmpty)
                    ? NetworkImage(teacher.imageUrl)
                    : null,
                child: (teacher.imageUrl.isEmpty)
                    ? Text(
                        teacher.teacherName.isNotEmpty
                            ? teacher.teacherName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayTabs(WidgetRef ref, String selectedDay) {
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: days.map((day) {
          final isSelected = day == selectedDay;
          return Expanded(
            child: InkWell(
              onTap: () => ref.read(selectedDayProvider.notifier).state = day,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: isSelected ? 14 : 13,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.white,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMainScheduleCard(String day) {
    final dayTypes = ref.watch(dayTypeProvider);
    final isWorkingDay = dayTypes[day] == 'Working Day';
    final allSchedule = ref.watch(scheduleProvider);
    final slots = allSchedule[day] ?? [];

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: isWorkingDay
                        ? const Color(0xFF2563EB)
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "$day Schedule",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildTogglePills(day),
            ],
          ),
          const SizedBox(height: 32),
          if (isWorkingDay) ...[
            _renderSlots(slots, day),
            const SizedBox(height: 24),
            _buildAddSlot(day),
          ] else ...[
            _buildHolidayView(),
          ],
        ],
      ),
    );
  }

  Widget _renderSlots(List<Map<String, dynamic>> slots, String day) {
    List<Widget> rows = [];
    List<Map<String, dynamic>> tempRow = [];

    for (var slot in slots) {
      if (slot['type'] == 'break') {
        if (tempRow.isNotEmpty) {
          rows.add(_buildPeriodRow(tempRow));
          tempRow = [];
        }
        rows.add(_buildBreakTile(slot));
        rows.add(const SizedBox(height: 8));
      } else {
        tempRow.add(slot);
        if (tempRow.length == 2) {
          rows.add(_buildPeriodRow(tempRow));
          rows.add(const SizedBox(height: 8));
          tempRow = [];
        }
      }
    }
    if (tempRow.isNotEmpty) rows.add(_buildPeriodRow(tempRow));
    return Column(children: rows);
  }

  Widget _buildPeriodRow(List<Map<String, dynamic>> rowSlots) {
    return Row(
      children: [
        Expanded(child: _buildPeriodTile(rowSlots[0])),
        const SizedBox(width: 12),
        Expanded(
          child: rowSlots.length > 1
              ? _buildPeriodTile(rowSlots[1])
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildHolidayView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            "Holiday",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No slots available for this date.",
            style: TextStyle(color: Colors.red.shade700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTogglePills(String selectedDay) {
    final dayTypes = ref.watch(dayTypeProvider);
    final String currentStatus = dayTypes[selectedDay] ?? 'Non-Working Day';

    Widget pill(String label) {
      final isSelected = currentStatus == label;
      Color bgColor = isSelected
          ? (label == 'Working Day' ? Colors.green : Colors.red)
          : const Color(0xFFE0F2FE);
      Color textColor = isSelected ? Colors.white : const Color(0xFF0284C7);

      return GestureDetector(
        onTap: () {
          ref
              .read(dayTypeProvider.notifier)
              .update((state) => {...state, selectedDay: label});
          if (label == 'Working Day') {
            final currentSchedule = ref.read(scheduleProvider);
            if (currentSchedule[selectedDay]!.isEmpty &&
                selectedDay != 'Monday') {
              final mondaySchedule = currentSchedule['Monday'];
              if (mondaySchedule != null && mondaySchedule.isNotEmpty) {
                ref.read(scheduleProvider.notifier).update((state) {
                  final newState = Map<String, List<Map<String, dynamic>>>.from(
                    state,
                  );
                  newState[selectedDay] = mondaySchedule
                      .map((slot) => Map<String, dynamic>.from(slot))
                      .toList();
                  return newState;
                });
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill('Working Day'),
        const SizedBox(width: 12),
        pill('Non-Working Day'),
      ],
    );
  }

  Widget _buildPeriodTile(Map<String, dynamic> slot) {
    final String day = ref.watch(selectedDayProvider);
    final List<Map<String, dynamic>> daySlots = ref.read(
      scheduleProvider,
    )[day]!;
    final int index = daySlots.indexOf(slot);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: slot['color'], width: 4)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _parseTime(slot['start']),
              );
              if (picked != null) {
                _updateTimeAndCascade(day, index, 'start', _formatTime(picked));
              }
            },
            child: _timeColumn(slot['start'], "START TIME"),
          ),
          const Spacer(),
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => _showNameEditDialog(day, index, slot['name']),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    slot['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Tap to edit name",
                    style: TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _parseTime(slot['end']),
              );
              if (picked != null) {
                _updateTimeAndCascade(day, index, 'end', _formatTime(picked));
              }
            },
            child: _timeColumn(
              slot['end'],
              "END TIME",
              crossAxis: CrossAxisAlignment.end,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _removeSlot(day, index),
          ),
        ],
      ),
    );
  }

  Widget _timeColumn(
    String time,
    String label, {
    CrossAxisAlignment crossAxis = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxis,
      children: [
        Text(
          time,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakTile(Map<String, dynamic> slot) {
    final String day = ref.watch(selectedDayProvider);
    final int index = ref.read(scheduleProvider)[day]!.indexOf(slot);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _parseTime(slot['start']),
              );
              if (picked != null) {
                _updateTimeAndCascade(day, index, 'start', _formatTime(picked));
              }
            },
            child: Text(
              slot['start'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const Expanded(child: Divider(indent: 20, endIndent: 20)),
          InkWell(
            onTap: () => _showNameEditDialog(day, index, slot['name']),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot['name'],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap to edit name",
                  style: TextStyle(fontSize: 8, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider(indent: 20, endIndent: 20)),
          InkWell(
            onTap: () async {
              TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: _parseTime(slot['end']),
              );
              if (picked != null) {
                _updateTimeAndCascade(day, index, 'end', _formatTime(picked));
              }
            },
            child: Text(
              slot['end'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _removeSlot(day, index),
          ),
        ],
      ),
    );
  }

  Widget _buildAddSlot(String selectedDay) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: _btn(
            label: "Add Break Slot",
            icon: Icons.add_box,
            color: const Color(0xFFFFAF3A),
            textColor: Colors.white,
            onTap: () => _addNewSlot('break', selectedDay),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: _btn(
            label: "Add Period Slot",
            icon: Icons.add_box,
            color: const Color(0xFF2563EB),
            textColor: Colors.white,
            onTap: () => _addNewSlot('period', selectedDay),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    final allSchedule = ref.watch(scheduleProvider);
    final dayTypes = ref.watch(dayTypeProvider);

    int totalWeeklyPeriods = 0;
    int totalWeeklyMinutes = 0;
    int completedWorkingDays = 0;
    int workingDaysCount = 0;

    dayTypes.forEach((day, type) {
      final isWorking = type == 'Working Day';
      final slots = allSchedule[day] ?? [];

      if (isWorking) {
        workingDaysCount++;
        if (slots.isNotEmpty) completedWorkingDays++;

        for (var slot in slots) {
          if (slot['type'] == 'period') totalWeeklyPeriods++;

          TimeOfDay start = _parseTime(slot['start']);
          TimeOfDay end = _parseTime(slot['end']);
          int startMin = start.hour * 60 + start.minute;
          int endMin = end.hour * 60 + end.minute;
          totalWeeklyMinutes += (endMin >= startMin)
              ? (endMin - startMin)
              : (1440 - startMin + endMin);
        }
      }
    });

    double completionPercentage = 0.0;
    if (workingDaysCount > 0) {
      completionPercentage = completedWorkingDays / workingDaysCount;
    }

    String totalWeeklyTimeStr =
        "${totalWeeklyMinutes ~/ 60}h ${totalWeeklyMinutes % 60}m";

    final selectedDay = ref.watch(selectedDayProvider);
    final isWorkingDay = dayTypes[selectedDay] == 'Working Day';
    final slots = allSchedule[selectedDay] ?? [];

    int totalPeriods = 0;
    int totalMinutes = 0;

    if (isWorkingDay) {
      totalPeriods = slots.where((s) => s['type'] == 'period').length;

      for (var slot in slots) {
        if (slot['type'] == 'period' || slot['type'] == 'break') {
          TimeOfDay start = _parseTime(slot['start']);
          TimeOfDay end = _parseTime(slot['end']);

          int startMin = start.hour * 60 + start.minute;
          int endMin = end.hour * 60 + end.minute;

          totalMinutes += (endMin >= startMin)
              ? (endMin - startMin)
              : (1440 - startMin + endMin);
        }
      }
    }

    String timeFormatted = "${totalMinutes ~/ 60}h ${totalMinutes % 60}m";

    return Column(
      children: [
        _sideCard(
          title: "CONFIGURATION SUMMARY",
          child: Column(
            children: [
              _summaryRow("Total Periods", "$totalPeriods Slots"),
              _summaryRow("Total Day Time", timeFormatted),
              const SizedBox(height: 24),
              _buildProgressCard(
                percentage: completionPercentage,
                workingDays: workingDaysCount,
                totalPeriods: totalWeeklyPeriods,
                totalTime: totalWeeklyTimeStr,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sideCard(
          title: "MANAGEMENT ACTIONS",
          child: Column(
            children: [
              _btn(
                label: "Create Layout",
                icon: Icons.check_circle,
                color: const Color(0xFF2563EB),
                textColor: Colors.white,
                onTap: () => _showCreatingAnimationAndNavigate(context),
              ),
              const SizedBox(height: 12),
              _btn(
                label: "Save as Draft",
                icon: Icons.save,
                color: const Color(0xFF3B82F6),
                textColor: Colors.white,
                onTap: () {
                  // _saveDraft();
                  // ref.invalidate(selectedDayProvider);
                  // ref.invalidate(dayTypeProvider);
                  // ref.invalidate(scheduleProvider);
                  // Navigator.of(context).pop();
                  _showSaveDraftConfirmation();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _btn(
                      label: "Clear Day",
                      icon: Icons.refresh,
                      color: const Color(0xFFE2E8F0),
                      textColor: Colors.black87,
                      onTap: () => _showClearConfirmation(selectedDay),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _btn(
                      label: "Cancel",
                      icon: Icons.clear,
                      color: const Color(0xFFDF1616),
                      textColor: Colors.white,
                      onTap: () => _handleCancel(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required double percentage,
    required int workingDays,
    required int totalPeriods,
    required String totalTime,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TIMETABLE COMPLETION",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                "${(percentage * 100).toInt()}%",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Working Days", "$workingDays"),
              _miniStat("Total Periods", "$totalPeriods"),
              _miniStat("Weekly Time", totalTime),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
