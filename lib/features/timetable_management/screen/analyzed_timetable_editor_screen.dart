import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alert_info/alert_info.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constant/firebase_constant.dart';
import '../../../core/config/session_manager.dart';
import '../../../models/teacher_model.dart';
import '../../teachers/controller/teacher_controller.dart';
import '../models/analyzed_timetable_model.dart';

class AnalyzedTimetableEditorScreen extends ConsumerStatefulWidget {
  final String? uploadedFileName;
  final List<AnalyzedClassTimetable>? initialClasses;

  const AnalyzedTimetableEditorScreen({
    super.key,
    this.uploadedFileName,
    this.initialClasses,
  });

  @override
  ConsumerState<AnalyzedTimetableEditorScreen> createState() => _AnalyzedTimetableEditorScreenState();
}

class _AnalyzedTimetableEditorScreenState extends ConsumerState<AnalyzedTimetableEditorScreen> {
  late List<AnalyzedClassTimetable> _classes;
  late int _selectedClassIndex;
  String _selectedStreamFilter = 'All';

  // Teachers list filter
  String _teacherSearchQuery = '';
  String _teacherCategoryFilter = 'All'; // 'All', 'Language', 'Subject'

  bool _isSavingToFirestore = false;

  @override
  void initState() {
    super.initState();
    _classes = widget.initialClasses ?? MasterTimetableParser.parseMasterTimetable();
    _selectedClassIndex = 0;
  }

  AnalyzedClassTimetable get _currentClass => _classes[_selectedClassIndex];

  // Extracts all teachers from Firestore teacherControllerProvider and merges with parsed known teachers
  List<AnalyzedTeacherInfo> _buildUnifiedTeachersList(List<TeacherModel> firestoreTeachers) {
    final List<AnalyzedTeacherInfo> result = [];

    // 1. Process teachers directly fetched from Firestore teachers sub-collection
    for (var t in firestoreTeachers) {
      if (t.delete) continue;
      final isLang = t.isLanguageTeacher || MasterTimetableParser.isLanguageSubject(t.subject);
      final effectiveCode = (t.subjectShort != null && t.subjectShort!.trim().isNotEmpty)
          ? t.subjectShort!.trim()
          : (t.subject.isNotEmpty ? t.subject : (isLang ? 'Language' : 'General'));

      result.add(
        AnalyzedTeacherInfo(
          id: t.id,
          name: t.teacherName,
          subjectCode: effectiveCode,
          subjectName: t.subject.isNotEmpty ? t.subject : (isLang ? 'Language' : 'General'),
          badgeColor: isLang ? MasterTimetableParser.secondLangColor : MasterTimetableParser.getSubjectColor(t.subject),
          isLanguageTeacher: isLang,
          employeeId: t.employeeId,
          mobileNo: t.mobileNo,
          isFromFirestore: true,
        ),
      );

      // Also check otherTeachers array if present in TeacherModel
      if (t.otherTeachers != null) {
        for (var ot in t.otherTeachers!) {
          if (!result.any((ex) => ex.id == ot.teacherId || ex.name.toLowerCase().trim() == ot.teacherName.toLowerCase().trim())) {
            final otIsLang = ot.isLanguageTeacher || MasterTimetableParser.isLanguageSubject(ot.subject);
            final otEffectiveCode = (ot.subjectShort != null && ot.subjectShort!.trim().isNotEmpty)
                ? ot.subjectShort!.trim()
                : (ot.subject.isNotEmpty ? ot.subject : (otIsLang ? 'Language' : 'Subject'));

            result.add(
              AnalyzedTeacherInfo(
                id: ot.teacherId,
                name: ot.teacherName,
                subjectCode: otEffectiveCode,
                subjectName: ot.subject.isNotEmpty ? ot.subject : (otIsLang ? 'Language' : 'Subject'),
                badgeColor: otIsLang ? MasterTimetableParser.secondLangColor : MasterTimetableParser.getSubjectColor(ot.subject),
                isLanguageTeacher: otIsLang,
                employeeId: ot.employeeId,
                mobileNo: ot.mobileNo.toString(),
                isFromFirestore: true,
              ),
            );
          }
        }
      }
    }

    // 2. Supplement with known teachers parsed from the master institutional PDF if not already present
    final knownPdfTeachers = MasterTimetableParser.getKnownTeachers();
    for (var kt in knownPdfTeachers) {
      if (!result.any((item) => item.name.toLowerCase().trim() == kt.name.toLowerCase().trim())) {
        result.add(kt);
      }
    }

    return result;
  }

  // Calculate teacher workload (how many periods they are assigned across this class or all classes)
  int _getTeacherAssignedPeriodsCount(String teacherName) {
    if (teacherName.isEmpty) return 0;
    int count = 0;
    final tnUpper = teacherName.toUpperCase().trim();
    for (var cls in _classes) {
      for (var daySlots in cls.schedule.values) {
        for (var slot in daySlots) {
          if (slot.assignedTeachers.any((t) => t.name.toUpperCase().trim() == tnUpper) ||
              (slot.teacherName != null && slot.teacherName!.toUpperCase().trim() == tnUpper)) {
            count++;
          }
        }
      }
    }
    return count;
  }

  // Handle Drag & Drop of teacher onto a specific period cell
  void _handleTeacherDroppedOnSlot(String day, int slotIndex, AnalyzedTeacherInfo teacher) {
    final slot = _currentClass.schedule[day]![slotIndex];

    if (slot.isBreak) {
      AlertInfo.show(
        context: context,
        text: "Cannot assign teacher to an interval / break",
        typeInfo: TypeInfo.warning,
        backgroundColor: Colors.amber.shade800,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      // Check if already in assigned list
      if (slot.assignedTeachers.any((t) => t.id == teacher.id || t.name.toUpperCase().trim() == teacher.name.toUpperCase().trim())) {
        AlertInfo.show(
          context: context,
          text: "${teacher.name} is already assigned to ${slot.periodName} ($day)",
          typeInfo: TypeInfo.info,
          backgroundColor: const Color(0xFF1193D4),
          textColor: Colors.white,
        );
        return;
      }

      // If slot had 0 assigned teachers, assign as the first teacher
      if (slot.assignedTeachers.isEmpty) {
        slot.assignedTeachers = [teacher];
        slot.teacherName = teacher.name;
        slot.teacherId = teacher.id;
        if (slot.subject == null || slot.subject!.isEmpty || slot.subject == 'Second Language') {
          slot.subject = teacher.subjectCode;
        }
        if (teacher.isLanguageTeacher) {
          slot.mainSubject = "Second Language";
        }
      } else {
        // Multi-teacher assignment (especially for language periods!)
        slot.assignedTeachers.add(teacher);
        slot.teacherName = slot.assignedTeachers.map((t) => t.name).join(', ');
        slot.teacherId = slot.assignedTeachers.map((t) => t.id).join(', ');
        slot.subject = slot.assignedTeachers.map((t) => t.subjectCode).join(' / ');
        if (slot.mainSubject == null || slot.mainSubject!.isEmpty) {
          slot.mainSubject = (teacher.isLanguageTeacher || slot.assignedTeachers.any((t) => t.isLanguageTeacher))
              ? "Second Language"
              : "Combined Subject";
        }
      }
    });

    AlertInfo.show(
      context: context,
      text: "Assigned ${teacher.name} to ${slot.periodName} (${slot.assignedTeachers.length} faculty)",
      typeInfo: TypeInfo.success,
      backgroundColor: const Color(0xFF10B981),
      textColor: Colors.white,
      position: MessagePosition.top,
    );
  }

  // Open multi-teacher selection & period edit dialog
  void _openCellEditDialog(String day, int slotIndex, List<AnalyzedTeacherInfo> allAvailableTeachers) {
    final slot = _currentClass.schedule[day]![slotIndex];

    final List<AnalyzedTeacherInfo> currentSelections = List.from(slot.assignedTeachers);
    // If assignedTeachers was empty but single teacher was on slot, find and add to selections
    if (currentSelections.isEmpty && slot.teacherName != null && slot.teacherName!.isNotEmpty) {
      final existing = allAvailableTeachers.where(
        (t) => t.name.toUpperCase().trim() == slot.teacherName!.toUpperCase().trim(),
      );
      if (existing.isNotEmpty) {
        currentSelections.add(existing.first);
      } else {
        currentSelections.add(AnalyzedTeacherInfo(
          id: slot.teacherId ?? '',
          name: slot.teacherName!,
          subjectCode: slot.subject ?? 'General',
          subjectName: slot.subject ?? 'General',
          badgeColor: slot.color,
          isLanguageTeacher: MasterTimetableParser.isLanguageSubject(slot.subject),
        ));
      }
    }

    final mainSubjectController = TextEditingController(
      text: (slot.mainSubject != null && slot.mainSubject!.isNotEmpty)
          ? slot.mainSubject
          : ((slot.subject != null && slot.subject!.isNotEmpty) ? slot.subject : "Second Language"),
    );
    final startTimeController = TextEditingController(text: slot.startTime);
    final endTimeController = TextEditingController(text: slot.endTime);
    String selectedType = slot.type;
    String dialogSearchQuery = '';
    String dialogCategory = 'All'; // 'All', 'Language', 'Selected'

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Filter available teachers for dialog
          final filtered = allAvailableTeachers.where((t) {
            if (dialogCategory == 'Language' && !t.isLanguageTeacher) return false;
            if (dialogCategory == 'Selected' && !currentSelections.any((s) => s.id == t.id || s.name == t.name)) return false;
            if (dialogSearchQuery.isNotEmpty) {
              final q = dialogSearchQuery.toLowerCase();
              final nameMatch = t.name.toLowerCase().contains(q);
              final codeMatch = t.subjectCode.toLowerCase().contains(q);
              final subMatch = t.subjectName.toLowerCase().contains(q);
              if (!nameMatch && !codeMatch && !subMatch) return false;
            }
            return true;
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF1193D4), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Edit ${slot.periodName} ($day)",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          "${_currentClass.className} • ${slot.startTime} - ${slot.endTime}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // 1. Slot Type Selector
                    const Text("SLOT TYPE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _typeChip("Period", 'period', selectedType, (v) => setDialogState(() => selectedType = v)),
                        _typeChip("Break / Interval", 'break', selectedType, (v) => setDialogState(() => selectedType = v)),
                        _typeChip("PT", 'pt', selectedType, (v) => setDialogState(() => selectedType = v)),
                        _typeChip("Lab", 'lab', selectedType, (v) => setDialogState(() => selectedType = v)),
                      ],
                    ),

                    if (selectedType != 'break') ...[
                      const SizedBox(height: 20),

                      // 2. Currently Selected Faculty Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "ASSIGNED FACULTY (SELECT MULTIPLE FOR LANGUAGE)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB), letterSpacing: 0.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: currentSelections.isNotEmpty ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${currentSelections.length} Selected",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: currentSelections.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (currentSelections.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: currentSelections.map((teacher) {
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: teacher.badgeColor,
                                  radius: 10,
                                  child: Text(
                                    teacher.name.isNotEmpty ? teacher.name[0] : 'T',
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                label: Text(
                                  "${teacher.name} (${teacher.subjectCode})",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: teacher.isLanguageTeacher ? const Color(0xFFF3E8FF) : Colors.white,
                                side: BorderSide(
                                  color: teacher.isLanguageTeacher ? const Color(0xFFC084FC) : Colors.grey.shade300,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () {
                                  setDialogState(() {
                                    currentSelections.removeWhere((item) => item.id == teacher.id && item.name == teacher.name);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "No teacher assigned yet. Select one or multiple teachers below (especially for language periods).",
                                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // If multiple teachers are selected: prompt for Main Subject Name
                      if (currentSelections.length > 1) ...[
                        const SizedBox(height: 16),
                        const Text(
                          "MAIN SUBJECT / GROUP NAME",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: mainSubjectController,
                          decoration: InputDecoration(
                            hintText: "e.g., Second Language",
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 3. Faculty Search & Filter Tabs
                      Row(
                        children: [
                          _filterChipBtn("All Teachers", 'All', dialogCategory, (cat) => setDialogState(() => dialogCategory = cat)),
                          const SizedBox(width: 6),
                          _filterChipBtn(
                            "🌐 Language Teachers",
                            'Language',
                            dialogCategory,
                            (cat) => setDialogState(() => dialogCategory = cat),
                            accentColor: const Color(0xFF9333EA),
                          ),
                          const SizedBox(width: 6),
                          _filterChipBtn(
                            "Selected (${currentSelections.length})",
                            'Selected',
                            dialogCategory,
                            (cat) => setDialogState(() => dialogCategory = cat),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Search field
                      TextField(
                        onChanged: (val) => setDialogState(() => dialogSearchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: "Search faculty name or subject...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF1193D4)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Faculty Scrollable Picker List
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: filtered.isEmpty
                            ? Center(
                                child: Text("No teachers found", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(8),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (ctx, idx) {
                                  final teacher = filtered[idx];
                                  final isSelected = currentSelections.any((s) => s.id == teacher.id && s.name == teacher.name);

                                  return InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        if (isSelected) {
                                          currentSelections.removeWhere((s) => s.id == teacher.id && s.name == teacher.name);
                                        } else {
                                          currentSelections.add(teacher);
                                          if (teacher.isLanguageTeacher && (mainSubjectController.text.isEmpty || mainSubjectController.text == 'Period')) {
                                            mainSubjectController.text = "Second Language";
                                          }
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade200,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Checkbox(
                                            value: isSelected,
                                            activeColor: const Color(0xFF2563EB),
                                            onChanged: (val) {
                                              setDialogState(() {
                                                if (val == true) {
                                                  currentSelections.add(teacher);
                                                } else {
                                                  currentSelections.removeWhere((s) => s.id == teacher.id && s.name == teacher.name);
                                                }
                                              });
                                            },
                                          ),
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: teacher.badgeColor.withValues(alpha: 0.15),
                                            child: Text(
                                              teacher.name.isNotEmpty ? teacher.name[0] : 'T',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: teacher.badgeColor),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  teacher.name,
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                    fontSize: 12,
                                                    color: const Color(0xFF0F172A),
                                                  ),
                                                ),
                                                Text(
                                                  teacher.subjectCode,
                                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (teacher.isLanguageTeacher)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3E8FF),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                "Language",
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF9333EA)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // 4. Timings
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("START TIME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: startTimeController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("END TIME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF64748B))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: endTimeController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1193D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    slot.type = selectedType;
                    slot.startTime = startTimeController.text.trim();
                    slot.endTime = endTimeController.text.trim();

                    if (selectedType == 'break') {
                      slot.subject = 'Break';
                      slot.mainSubject = 'Break';
                      slot.teacherName = null;
                      slot.teacherId = null;
                      slot.color = MasterTimetableParser.breakColor;
                      slot.assignedTeachers = [];
                    } else if (currentSelections.isEmpty) {
                      slot.teacherName = null;
                      slot.teacherId = null;
                      slot.assignedTeachers = [];
                      slot.mainSubject = mainSubjectController.text.trim();
                      slot.subject = mainSubjectController.text.trim();
                    } else if (currentSelections.length == 1) {
                      final t = currentSelections.first;
                      slot.assignedTeachers = [t];
                      slot.teacherName = t.name;
                      slot.teacherId = t.id;
                      slot.subject = t.subjectCode;
                      slot.mainSubject = t.isLanguageTeacher ? "Second Language" : t.subjectCode;
                      slot.color = t.badgeColor;
                    } else {
                      // Multi-teacher assignment (for language periods)
                      slot.assignedTeachers = List.from(currentSelections);
                      slot.teacherName = currentSelections.map((t) => t.name).join(', ');
                      slot.teacherId = currentSelections.map((t) => t.id).join(', ');
                      slot.subject = currentSelections.map((t) => t.subjectCode).join(' / ');
                      slot.mainSubject = mainSubjectController.text.trim().isNotEmpty
                          ? mainSubjectController.text.trim()
                          : "Second Language";
                      slot.color = MasterTimetableParser.secondLangColor;
                    }
                  });
                  Navigator.of(ctx).pop();

                  AlertInfo.show(
                    context: context,
                    text: "Updated ${slot.periodName} ($day)",
                    typeInfo: TypeInfo.success,
                    backgroundColor: const Color(0xFF10B981),
                    textColor: Colors.white,
                  );
                },
                child: const Text("Apply Assignment", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChipBtn(String label, String value, String currentValue, Function(String) onSelect, {Color? accentColor}) {
    final isSelected = value == currentValue;
    final color = accentColor ?? const Color(0xFF1193D4);

    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value, String currentValue, Function(String) onSelect) {
    final isSelected = value == currentValue;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1193D4) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Publish all analyzed classes to Firestore (same save logic as teacher dashboard, for multiple classes at once)
  Future<void> _saveAllTimetablesToFirestore() async {
    setState(() => _isSavingToFirestore = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final schoolId = SessionManager.schoolId;

      for (var cls in _classes) {
        final classNo = cls.classNo.isNotEmpty ? cls.classNo : '11';
        final division = cls.division.isNotEmpty ? cls.division : 'A';
        final timetableName = "${cls.className} Schedule";

        // Convert class schedule into DayScheduleModel and PeriodSlotModel identical to teacher dashboard
        final timetableModel = cls.toFirestoreTimetableModel(schoolId: schoolId);

        // Save to Firestore: schools/{schoolId}/timetable/{classNo} -> divisions/{division}/timetables/{name}
        await firestore.schoolCollection(FirebaseConstant.timetable).doc(classNo).set({
          'divisions': {
            division: {
              'timetables': {
                timetableName: timetableModel.toMap(),
              }
            }
          }
        }, SetOptions(merge: true));
      }

      if (mounted) {
        AlertInfo.show(
          context: context,
          text: "Successfully published all ${_classes.length} class timetables!",
          typeInfo: TypeInfo.success,
          backgroundColor: const Color(0xFF10B981),
          textColor: Colors.white,
          position: MessagePosition.top,
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AlertInfo.show(
          context: context,
          text: "Failed to publish timetables: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          position: MessagePosition.top,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToFirestore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch real-time teachers from Firestore teachers sub-collection
    final teachersAsync = ref.watch(teacherControllerProvider);
    final firestoreTeachers = teachersAsync.value ?? <TeacherModel>[];

    // 2. Build unified teachers list (Firestore teachers + Master PDF teachers)
    final allAvailableTeachers = _buildUnifiedTeachersList(firestoreTeachers);

    // 3. Filter teachers list by category and search query
    final filteredTeachers = allAvailableTeachers.where((t) {
      if (_teacherCategoryFilter == 'Language' && !t.isLanguageTeacher) return false;
      if (_teacherCategoryFilter == 'Subject' && t.isLanguageTeacher) return false;

      if (_teacherSearchQuery.isNotEmpty) {
        final q = _teacherSearchQuery.toLowerCase();
        final nameMatch = t.name.toLowerCase().contains(q);
        final codeMatch = t.subjectCode.toLowerCase().contains(q);
        final subMatch = t.subjectName.toLowerCase().contains(q);
        if (!nameMatch && !codeMatch && !subMatch) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Navigation Bar ──
            _buildTopNavBar(),

            // ── Main Content: Left (Timetable Grid) + Right (Teachers List) ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Class Switcher + Timetable Layout Grid
                  Expanded(
                    flex: 7,
                    child: Container(
                      margin: const EdgeInsets.only(left: 18, top: 14, bottom: 18, right: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Class Switcher Bar (Tabs)
                          _buildClassSwitcherBar(),

                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Active Class Meta Info Banner (Fixed overflow with Wrap)
                          _buildActiveClassBanner(),

                          const SizedBox(height: 16),

                          // Interactive Timetable Layout Matrix
                          Expanded(
                            child: _buildTimetableLayoutMatrix(allAvailableTeachers),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Side: All Teachers List (Fetched from Firestore)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 320, maxWidth: 380),
                    child: Container(
                      margin: const EdgeInsets.only(right: 18, top: 14, bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildTeachersListPanel(filteredTeachers, allAvailableTeachers),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Top Navigation Bar ──
  Widget _buildTopNavBar() {
    final fileName = widget.uploadedFileName ?? "Master_Timetable.pdf";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Back button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text("Back to Timetables", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 16),

          // Title & Source PDF badge
          Expanded(
            child: Row(
              children: [
                const Text(
                  "Analyzed Multi-Class Timetable Editor",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF1D9BF0)),
                      const SizedBox(width: 6),
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D9BF0)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_classes.length} Classes Detected",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                  ),
                ),
              ],
            ),
          ),

          // Save All Button (Saves all classes simultaneously to Firestore)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1193D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _isSavingToFirestore ? null : _saveAllTimetablesToFirestore,
            icon: _isSavingToFirestore
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(
              _isSavingToFirestore ? "Publishing..." : "Publish All (${_classes.length} Timetables)",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Class Switcher Bar (Tabs) ──
  Widget _buildClassSwitcherBar() {
    final streams = ['All', 'Science', 'Computer Science', 'Commerce', 'Humanities'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stream Filter Chips (Wrapped in horizontal scroll to prevent overflow)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text("Streams: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(width: 6),
              ...streams.map((st) {
                final isSelected = _selectedStreamFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st),
                    selected: isSelected,
                    selectedColor: const Color(0xFF1193D4),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (val) {
                      setState(() => _selectedStreamFilter = st);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Class Tabs Horizontal Scroll
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _classes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final cls = _classes[index];
              if (_selectedStreamFilter != 'All' && cls.stream != _selectedStreamFilter) {
                return const SizedBox.shrink();
              }

              final isSelected = index == _selectedClassIndex;
              return InkWell(
                onTap: () => setState(() => _selectedClassIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1193D4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1193D4) : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cls.className,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 3. Active Class Meta Info Banner (Fixed 101px Overflow with Wrap) ──
  Widget _buildActiveClassBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1193D4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_chart_rounded, size: 18, color: Color(0xFF1193D4)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _currentClass.className,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Class ${_currentClass.classNo} - Div ${_currentClass.division}",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1193D4)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Stream: ${_currentClass.stream}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 12),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF15803D)),
                        SizedBox(width: 4),
                        Text(
                          "Tap cell to assign teachers • Drag faculty from right",
                          style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF15803D)),
                    SizedBox(width: 4),
                    Text(
                      "Tap cell to assign teachers • Drag faculty from right",
                      style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── 4. Interactive Timetable Layout Matrix ──
  Widget _buildTimetableLayoutMatrix(List<AnalyzedTeacherInfo> allAvailableTeachers) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final sampleSlots = _currentClass.schedule['Monday'] ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(115),
              border: TableBorder(
                horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              children: [
                // Header Row (Periods & Breaks)
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                  children: [
                    // Day column header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      alignment: Alignment.center,
                      child: const Text("DAY", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF64748B))),
                    ),

                    // Period Headers
                    for (int i = 0; i < sampleSlots.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        color: sampleSlots[i].type == 'break' ? const Color(0xFFFEF9C3).withValues(alpha: 0.5) : null,
                        child: Column(
                          children: [
                            Text(
                              sampleSlots[i].periodName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: sampleSlots[i].type == 'break' ? const Color(0xFFB45309) : const Color(0xFF1E293B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sampleSlots[i].startTime,
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Days Rows: Monday - Friday
                for (var day in days)
                  TableRow(
                    children: [
                      // Day Label Cell
                      Container(
                        height: 82,
                        color: const Color(0xFFF8FAFC),
                        alignment: Alignment.center,
                        child: Text(
                          day.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF0F172A)),
                        ),
                      ),

                      // Period slots
                      for (int slotIdx = 0; slotIdx < (_currentClass.schedule[day]?.length ?? 0); slotIdx++)
                        _buildPeriodCell(day, slotIdx, allAvailableTeachers),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodCell(String day, int slotIdx, List<AnalyzedTeacherInfo> allAvailableTeachers) {
    final slot = _currentClass.schedule[day]![slotIdx];
    final isBreak = slot.type == 'break';
    final isPt = slot.type == 'pt';

    if (isBreak) {
      return Container(
        height: 82,
        color: const Color(0xFFFEF9C3).withValues(alpha: 0.7),
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            slot.periodName.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB45309),
              letterSpacing: 1.5,
            ),
          ),
        ),
      );
    }

    // DragTarget accepts teacher drops directly into the cell!
    return DragTarget<AnalyzedTeacherInfo>(
      onAcceptWithDetails: (details) {
        _handleTeacherDroppedOnSlot(day, slotIdx, details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final hasMultiple = slot.assignedTeachers.length > 1;

        return InkWell(
          onTap: () => _openCellEditDialog(day, slotIdx, allAvailableTeachers),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 82,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: isHovered
                  ? const Color(0xFFE0F2FE)
                  : (isPt ? const Color(0xFFFEF2F2) : Colors.white),
              border: isHovered
                  ? Border.all(color: const Color(0xFF1193D4), width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Subject badge or Multiple Teacher Badge
                if (hasMultiple) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slot.mainSubject ?? 'Second Language',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF7E22CE),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E22CE).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${slot.assignedTeachers.length}",
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF7E22CE)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // List teachers / languages
                  Expanded(
                    child: Text(
                      slot.assignedTeachers.map((t) => "${t.name} (${t.subjectCode})").join('\n'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        height: 1.1,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: slot.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      slot.subject ?? 'Period',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: slot.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Single Teacher assigned
                  if (slot.teacherName != null && slot.teacherName!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.person, size: 10, color: Color(0xFF64748B)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            slot.teacherName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      "Click to assign",
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 5. Right Side: All Teachers List Panel (Fetched from Firestore) ──
  Widget _buildTeachersListPanel(List<AnalyzedTeacherInfo> teachers, List<AnalyzedTeacherInfo> allTeachers) {
    final languageCount = allTeachers.where((t) => t.isLanguageTeacher).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "All Teachers List",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      "Faculty Directory",
                      style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${allTeachers.length} Faculty",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Category Filter Chips: All | Language Teachers | Subject Teachers
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _categoryFilterChip("All (${allTeachers.length})", 'All'),
              const SizedBox(width: 6),
              _categoryFilterChip(
                "🌐 Language ($languageCount)",
                'Language',
                accentColor: const Color(0xFF9333EA),
              ),
              const SizedBox(width: 6),
              _categoryFilterChip(
                "Subject",
                'Subject',
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Search Bar for Teachers
        TextField(
          onChanged: (val) => setState(() => _teacherSearchQuery = val.trim()),
          decoration: InputDecoration(
            hintText: "Search faculty or subject...",
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF1193D4)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),

        const SizedBox(height: 10),

        // Quick tip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF16A34A)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Drag card into slot or click slot to select multiple teachers (for language)",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Teachers Scrollable List
        Expanded(
          child: teachers.isEmpty
              ? Center(
                  child: Text("No matching faculty", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                )
              : ListView.separated(
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final t = teachers[idx];
                    final periodsCount = _getTeacherAssignedPeriodsCount(t.name);

                    // Draggable teacher card!
                    return Draggable<AnalyzedTeacherInfo>(
                      data: t,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16),
                            ],
                            border: Border.all(color: t.badgeColor, width: 2),
                          ),
                          child: Text(
                            t.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.4,
                        child: _buildTeacherRowCard(t, periodsCount),
                      ),
                      child: _buildTeacherRowCard(t, periodsCount),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _categoryFilterChip(String label, String value, {Color? accentColor}) {
    final isSelected = _teacherCategoryFilter == value;
    final color = accentColor ?? const Color(0xFF1193D4);

    return InkWell(
      onTap: () => setState(() => _teacherCategoryFilter = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherRowCard(AnalyzedTeacherInfo t, int periodsCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isLanguageTeacher ? const Color(0xFFE9D5FF) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Avatar with Initial
          CircleAvatar(
            radius: 16,
            backgroundColor: t.badgeColor.withValues(alpha: 0.15),
            child: Text(
              t.name.isNotEmpty ? t.name[0] : 'T',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: t.badgeColor),
            ),
          ),
          const SizedBox(width: 10),

          // Name & Subject Code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: t.badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t.subjectCode,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: t.badgeColor,
                        ),
                      ),
                    ),
                    if (t.isLanguageTeacher) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "Language",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF9333EA),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Workload period count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "$periodsCount slots",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
