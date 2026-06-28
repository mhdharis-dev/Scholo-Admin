import 'dart:developer';
import 'dart:io';
import 'package:go_router/go_router.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:scholo_admin/core/constant/firebase_constant.dart';
import '../../teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import 'package:scholo_admin/models/students_model.dart';
import 'package:scholo_admin/models/class_model.dart';
import 'package:scholo_admin/core/widgets/phone_field.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/cloudinaryServies/cloudinary_service.dart';
import '../../../core/constant/image_constant.dart';
import '../../../models/event_model.dart';
import '../../../models/fees_model.dart';
import '../../../models/teacher_model.dart';
import 'package:alert_info/alert_info.dart';

// -----------------------------------------------------------------------------
// RIVERPOD PROVIDERS
// -----------------------------------------------------------------------------

class AttendanceSummary {
  final int totalStudents;
  final int presentStudents;
  final int absentStudents;

  AttendanceSummary({
    required this.totalStudents,
    required this.presentStudents,
    required this.absentStudents,
  });

  double get percent {
    if (totalStudents == 0) return 0;
    return presentStudents / totalStudents;
  }
}

final teachersDropdownProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .where('delete', isEqualTo: false)
      .get();

  return snapshot.docs
      .map((doc) {
        final data = doc.data();
        final classNo = data['classNo'];

        // 🔹 Convert to int safely
        final intClass = classNo is int
            ? classNo
            : int.tryParse(classNo.toString()) ?? 0;

        return {
          'id': doc.id,
          'name': data['teacherName'] ?? '',
          'classNo': intClass.toString(),
          'division': data['division'] ?? 'Not',
        };
      })
      // 🔥 FILTER: classNo != 0
      .where((t) => t['classNo'] != '0')
      .toList();
});

final studentImageUploadProvider = Provider<Future<String> Function(File)>((
  ref,
) {
  return (File file) async {
    final response = await CloudinaryService. studentProfile.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return response.secureUrl;
  };
});

final teacherImageUploadProvider = Provider<Future<String> Function(File)>((
  ref,
) {
  return (File file) async {
    final response = await CloudinaryService.teacherProfile.uploadFile(
      CloudinaryFile.fromFile(
        file.path,
        resourceType: CloudinaryResourceType.Image,
      ),
    );

    return response.secureUrl;
  };
});

final feeDescriptionsProvider = FutureProvider<List<String>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.fees)
      .get();

  final Set<String> descriptions = {};

  for (final doc in snapshot.docs) {
    descriptions.add(doc.id); // using docId as description
  }

  return descriptions.toList();
});

final saveFeeProvider = Provider<Future<void> Function(FeeModel)>((ref) {
  return (FeeModel fee) async {
    final docRef = FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.fees)
        .doc(fee.description);

    await docRef.set({
      fee.classNo.toString(): {fee.division: fee.toMap()},
    }, SetOptions(merge: true));
  };
});

final upcomingEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final now = DateTime.now();

  final snapshot = await ref
      .read(eventFirestoreProvider)
      .where('delete', isEqualTo: false)
      .where('endDateTime', isGreaterThanOrEqualTo: now) // ✅ DateTime
      .orderBy('endDateTime')
      .limit(5)
      .get();

  return snapshot.docs.map((doc) => doc.data()).toList();
});

final eventFirestoreProvider = Provider<CollectionReference<EventModel>>((ref) {
  return FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.events)
      .withConverter<EventModel>(
        fromFirestore: (snap, _) => EventModel.fromMap(snap.data()!),
        toFirestore: (event, _) => event.toMap(),
      );
});

final totalStudentsProvider = FutureProvider<int>((ref) async {
  final snap = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.student)
      .where('delete', isEqualTo: false)
      .get();

  return snap.docs.length;
});

final feesCollectedProvider = FutureProvider<double>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.fees)
      .get();

  double totalCollected = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    // Loop class level (eg: 11)
    for (final classEntry in data.entries) {
      if (classEntry.value is Map<String, dynamic>) {
        final classMap = classEntry.value as Map<String, dynamic>;

        // Loop division level (eg: C)
        for (final divisionEntry in classMap.entries) {
          if (divisionEntry.value is Map<String, dynamic>) {
            final divisionMap = divisionEntry.value as Map<String, dynamic>;

            final totalAmount = (divisionMap['totalAmount'] ?? 0).toDouble();

            totalCollected += totalAmount;
          }
        }
      }
    }
  }

  return totalCollected;
});

final pendingFeesProvider = FutureProvider<double>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.fees)
      .get();

  double totalPending = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    // Loop class (eg: 11)
    for (final classEntry in data.entries) {
      if (classEntry.value is Map<String, dynamic>) {
        final classMap = classEntry.value as Map<String, dynamic>;

        // Loop division (eg: C)
        for (final divisionEntry in classMap.entries) {
          if (divisionEntry.value is Map<String, dynamic>) {
            final divisionMap = divisionEntry.value as Map<String, dynamic>;

            final fee = (divisionMap['fee'] ?? 0).toDouble();

            final students = (divisionMap['students'] ?? []) as List;

            int pendingCount = 0;

            for (final s in students) {
              if (s is Map && s['collected'] == false) {
                pendingCount++;
              }
            }

            totalPending += pendingCount * fee;
          }
        }
      }
    }
  }

  return totalPending;
});

final teachersProvider = FutureProvider<List<TeacherModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .orderBy('teacherName')
      .limit(10)
      .get();
  final teachers = snapshot.docs
      .map((doc) => TeacherModel.fromMap(doc.data()))
      .where((t) => t.classNo != 0)
      .where((t) => t.teacherName.isNotEmpty)
      .toList();
  return teachers.take(5).toList();
});

final studentsProvider = FutureProvider<List<StudentsModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.student)
      .orderBy('studentName')
      .limit(10)
      .get();
  final students = snapshot.docs
      .map((doc) => StudentsModel.fromMap(doc.data()))
      .where((t) => t.studentName.isNotEmpty)
      .toList();
  return students.take(5).toList();
});

final activeTeachersProvider = FutureProvider<List<TeacherModel>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .schoolCollection(FirebaseConstant.teacher)
      .where('delete', isEqualTo: false) // active only
      .orderBy('teacherName')
      .get();

  return snapshot.docs
      .map((doc) => TeacherModel.fromMap(doc.data()))
      .where((t) => t.teacherName.isNotEmpty)
      .where((t) => t.classNo != 0) // exclude class 0
      .take(8) // dashboard limit
      .toList();
});

final addTeacherProvider = Provider<Future<void> Function(TeacherModel)>((ref) {
  return (TeacherModel teacher) async {
    final doc = FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .doc(); // 🔥 auto ID

    await doc.set(teacher.copyWith(id: doc.id).toMap());
  };
});

final todayAttendanceProvider =
    StreamProvider.family<AttendanceSummary, int>((ref, totalStudents) {
  final firestore = FirebaseFirestore.instance;

  final now = DateTime.now();
  final dateKey =
      " ${now.day.toString().padLeft(2, '0')}-"
      "${now.month.toString().padLeft(2, '0')}-"
      "${now.year}";

  log("📅 Attendance DateKey => $dateKey");
  log("👨‍🎓 Total students in school => $totalStudents");

  return firestore
      .schoolCollection(FirebaseConstant.attendance)
      .doc(dateKey)
      .snapshots()
      .map((doc) {
    log("📄 Document snapshot received - exists: ${doc.exists}");

    if (!doc.exists) {
      log("⚠️ Attendance document NOT FOUND for today - returning empty attendance");
      return AttendanceSummary(
        totalStudents: totalStudents,
        presentStudents: 0,
        absentStudents: totalStudents,
      );
    }

    final data = doc.data();
    log("📦 Raw attendance data: $data");

    int present = 0;

    if (data is Map<String, dynamic>) {
      for (final classEntry in data.entries) {
        if (classEntry.value is! Map<String, dynamic>) {
          continue;
        }

        final classMap = classEntry.value as Map<String, dynamic>;

        for (final divisionEntry in classMap.entries) {
          if (divisionEntry.value is! List) {
            continue;
          }

          final studentList = divisionEntry.value as List;

          for (final studentEntry in studentList) {
            if (studentEntry is! Map<String, dynamic>) {
              continue;
            }

            final status = (studentEntry['status'] ?? '').toString().toLowerCase().trim();
            final studentName = studentEntry['studentName'] ?? 'Unknown';

            log("👤 Student: $studentName → status: $status");

            if (status == 'present' ||
                status.contains('half') ||
                status.contains('morning') ||
                status.contains('evening')) {
              present++;
            }
          }
        }
      }
    }

    final absent = totalStudents - present;
    log("📊 FINAL RESULT → Present: $present | Absent: $absent | Total: $totalStudents");

    return AttendanceSummary(
      totalStudents: totalStudents,
      presentStudents: present,
      absentStudents: absent,
    );
  }).handleError((error, stackTrace) {
    log("❌ ERROR in attendance stream: $error");
    log("❌ Stack trace: $stackTrace");

    return AttendanceSummary(
      totalStudents: totalStudents,
      presentStudents: 0,
      absentStudents: totalStudents,
    );
  });
});

final unmarkedClassesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final firestore = FirebaseFirestore.instance;

  final now = DateTime.now();
  final dateKey =
      " ${now.day.toString().padLeft(2, '0')}-"
      "${now.month.toString().padLeft(2, '0')}-"
      "${now.year}";

  log("🔍 unmarkedClassesProvider: Fetching teachers, students and attendance for dateKey => '$dateKey'");

  final teachersSnap = await firestore
      .schoolCollection(FirebaseConstant.teacher)
      .where('delete', isEqualTo: false)
      .where('classNo', isNotEqualTo: 0)
      .get();

  final studentsSnap = await firestore
      .schoolCollection(FirebaseConstant.student)
      .where('delete', isEqualTo: false)
      .get();

  final activeClasses = studentsSnap.docs.map((doc) {
    final data = doc.data();
    final classNoRaw = data['classNo'];
    final int classNoInt = classNoRaw is int ? classNoRaw : (int.tryParse(classNoRaw?.toString() ?? '') ?? 0);
    final division = data['division']?.toString().toUpperCase().trim() ?? '';
    return "$classNoInt-$division";
  }).toSet();

  final attendanceDoc = await firestore
      .schoolCollection(FirebaseConstant.attendance)
      .doc(dateKey)
      .get();

  log("🔍 unmarkedClassesProvider: attendanceDoc exists today => ${attendanceDoc.exists}");

  // If no attendance document exists today, ALL valid classes with students are unmarked
  if (!attendanceDoc.exists) {
    log("📋 No attendance document today - all valid classes with students are unmarked");
    final unmarkedList = <Map<String, dynamic>>[];
    for (final t in teachersSnap.docs) {
      final data = t.data();
      final classNoRaw = data['classNo'];
      final int classNoInt = classNoRaw is int ? classNoRaw : (int.tryParse(classNoRaw?.toString() ?? '') ?? 0);
      final divisionRaw = data['division']?.toString().trim() ?? '';
      final division = divisionRaw.toUpperCase();
      
      if (division.toLowerCase() == 'nil' || division.isEmpty || classNoInt == 0) {
        continue;
      }
      
      final key = "$classNoInt-$division";
      if (!activeClasses.contains(key)) {
        continue;
      }

      final String classLabel;
      if (classNoInt == -2) {
        classLabel = 'LKG';
      } else if (classNoInt == -1) {
        classLabel = 'UKG';
      } else {
        classLabel = classNoInt.toString();
      }
      
      unmarkedList.add({
        'label': 'Class $classLabel-$divisionRaw',
        'teacherId': t.id,
      });
    }
    return unmarkedList;
  }

  // Otherwise, check which classes are unmarked
  final attendanceData = attendanceDoc.data()!;
  log("🔍 unmarkedClassesProvider: raw attendance keys => ${attendanceData.keys.toList()}");
  
  List<Map<String, dynamic>> unmarked = [];

  for (final t in teachersSnap.docs) {
    final data = t.data();

    final classNoRaw = data['classNo'];
    final int classNoInt = classNoRaw is int ? classNoRaw : (int.tryParse(classNoRaw?.toString() ?? '') ?? 0);
    final divisionRaw = data['division']?.toString().trim() ?? '';
    final division = divisionRaw.toUpperCase();

    if (division.toLowerCase() == 'nil' || division.isEmpty || classNoInt == 0) {
      continue;
    }

    final key = "$classNoInt-$division";
    if (!activeClasses.contains(key)) {
      continue;
    }

    final classMap = attendanceData[classNoInt.toString()];
    
    // Check if there is list of students recorded under classMap[division] and it's not empty
    bool isMarked = false;
    if (classMap is Map<String, dynamic>) {
      final divData = classMap[division];
      if (divData != null) {
        isMarked = true;
      }
    }

    log("🔍 unmarkedClassesProvider: Class $classNoInt-$division => isMarked: $isMarked");

    if (!isMarked) {
      final String classLabel;
      if (classNoInt == -2) {
        classLabel = 'LKG';
      } else if (classNoInt == -1) {
        classLabel = 'UKG';
      } else {
        classLabel = classNoInt.toString();
      }

      unmarked.add({
        'label': 'Class $classLabel-$divisionRaw',
        'teacherId': t.id,
      });
    }
  }

  log("🔍 unmarkedClassesProvider: Final unmarked count => ${unmarked.length}");
  return unmarked;
});
final cleanExpiredSubstitutionsProvider =
StreamProvider<void>((ref) async* {
  final firestore = FirebaseFirestore.instance;

  final snapshot =
  await firestore.schoolCollection(FirebaseConstant.teacher).get();

  final now = DateTime.now();

  for (final doc in snapshot.docs) {
    final data = doc.data();

    List otherTeachers = data['otherTeachers'] ?? [];

    List updatedList = otherTeachers.where((t) {
      if (t['isPermanent'] == false && t['substitutedDate'] != null) {
        final subDate = (t['substitutedDate'] as Timestamp).toDate();

        return subDate.isAfter(now); // keep only valid
      }
      return true;
    }).toList();

    if (updatedList.length != otherTeachers.length) {
      await doc.reference.update({
        "otherTeachers": updatedList,
      });
    }
  }
});
// -----------------------------------------------------------------------------
// DASHBOARD SCREEN
// -----------------------------------------------------------------------------
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime focusedDay = DateTime.now();

  String _classNoToString(int classNoInt) {
    if (classNoInt == -2) return 'LKG';
    if (classNoInt == -1) return 'UKG';
    if (classNoInt == 0) return 'Other';
    return classNoInt.toString();
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateGeneratedCredentials);
    _teacherIdController.addListener(_updateGeneratedCredentials);
    _admissionController.addListener(_updateGeneratedCredentials);
  }

  void _updateGeneratedCredentials() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _emailController.clear();
      _passwordController.clear();
      return;
    }

    final firstName = name.split(' ').first.toLowerCase();

    if (_admissionController.text.isNotEmpty) {
      final id = _admissionController.text.trim();
      _emailController.text = "$firstName$id@scholo.com";
      _passwordController.text = "$firstName@$id";
    } else if (_teacherIdController.text.isNotEmpty) {
      final id = _teacherIdController.text.trim();
      _emailController.text = "$firstName$id@scholo.com";
      _passwordController.text = "$firstName@$id";
    }
  }

  File? _selectedFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  final _teacherIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  final _subjectController = TextEditingController();
  final _addressController = TextEditingController();
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  final _rollController = TextEditingController();
  final _admissionController = TextEditingController();
  final _parentController = TextEditingController();

  String? _selectedClass;
  String? _selectedDiv;
  String? _selectedGender;
  String? _selectedTeacherName;
  String? _selectedTeacherId;
  String? _classNo;
  String? _division;
  //------------------------------event add--------------------------------------------
  final List<Color> eventColors = const [
    Color(0xff2970FF), // Blue
    Color(0xff22C55E), // Green
    Color(0xffFACC15), // Yellow
    Color(0xffF97316), // Orange
    Color(0xffEF4444), // Red
    Color(0xffA855F7), // Purple
    Color(0xff64748B), // Grey
  ];

  List<String> allClasses = [];

  Widget _inputBox({required Widget child, double height = 50}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff4f7fa),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE2E8F0), width: 1),
      ),
      child: child,
    );
  }

  void _showSnack(String message, {bool success = false}) {
    AlertInfo.show(
      context: context,
      text: message,
      typeInfo: success ? TypeInfo.success : TypeInfo.error,
      iconColor: Colors.white,
      backgroundColor: success ? const Color(0xFF27AE60) : Colors.redAccent,
      textColor: Colors.white,
      position: MessagePosition.top,
    );
  }

  void _showAddEditEventDialog({EventModel? existingEvent}) {
    final isEdit = existingEvent != null;

    final titleController = TextEditingController(
      text: existingEvent?.title ?? "",
    );
    final descController = TextEditingController(
      text: existingEvent?.description ?? "",
    );

    DateTime? startDate = existingEvent?.startDateTime;
    DateTime? endDate = existingEvent?.endDateTime;

    TimeOfDay? startTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.startDateTime)
        : null;

    TimeOfDay? endTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.endDateTime)
        : null;

    Color? selectedColor = existingEvent != null
        ? _parseColor(existingEvent.color)
        : null;

    // classes selected
    List<String> selectedClasses = existingEvent != null
        ? List<String>.from(existingEvent.classes)
        : [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 650,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER ------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEdit ? "Edit Event" : "Add New Event",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 25),

                        // EVENT TITLE
                        const Text(
                          "Event Title",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _inputBox(
                          child: TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              hintText: "e.g., Annual Sports Day",
                              border: InputBorder.none,
                              fillColor: Color(0xfff4f7fa),
                              hoverColor: Color(0xfff4f7fa),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // EVENT DESCRIPTION
                        const Text(
                          "Event Description",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _inputBox(
                          height: 90,
                          child: TextField(
                            controller: descController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: "Provide a brief summary of the event.",
                              border: InputBorder.none,
                              fillColor: Color(0xfff4f7fa),
                              hoverColor: Color(0xfff4f7fa),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // DATE ROW ------------------------
                        Row(
                          children: [
                            // Start Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Start date",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              startDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => startDate = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            startDate == null
                                                ? "Select a date"
                                                : DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(startDate!),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Start Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Start time",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime:
                                              startTime ?? TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setState(() => startTime = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            startTime == null
                                                ? "--:-- --"
                                                : startTime!.format(context),
                                          ),
                                          const Icon(Icons.schedule, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // End Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "End date",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              endDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(() => endDate = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            endDate == null
                                                ? "Select a date"
                                                : DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(endDate!),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // End Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "End time",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime:
                                              endTime ?? TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setState(() => endTime = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            endTime == null
                                                ? "--:-- --"
                                                : endTime!.format(context),
                                          ),
                                          const Icon(Icons.schedule, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // COLOR SELECTOR -----------------------
                        const Text(
                          "Event Color",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: eventColors.map((color) {
                            final isSelected = selectedColor == color;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedColor = color),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xff4583FF)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 30),

                        // CLASS SELECTION -----------------------
                        const Text(
                          "Class selection",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // ALL
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (selectedClasses.length == allClasses.length) {
                                    // ✅ already all selected → unselect all
                                    selectedClasses.clear();
                                  } else {
                                    // ✅ not all selected → select all
                                    selectedClasses = List.from(allClasses);
                                  }
                                });
                              },
                              child: _classChip(
                                "ALL",
                                selectedClasses.length == allClasses.length,
                              ),
                            ),
                            ...allClasses
                                .map(
                                  (cls) => GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (selectedClasses.contains(cls)) {
                                          selectedClasses.remove(cls);
                                        } else {
                                          selectedClasses.add(cls);
                                        }
                                      });
                                    },
                                    child: _classChip(
                                      cls,
                                      selectedClasses.contains(cls),
                                    ),
                                  ),
                                )
                                ,
                          ],
                        ),

                        const SizedBox(height: 35),
                        Container(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 22),

                        // BUTTONS ROW -----------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff2970FF),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                if (titleController.text.trim().isEmpty) {
                                  return _showSnack("Enter event title");
                                }
                                if (descController.text.trim().isEmpty) {
                                  return _showSnack("Enter description");
                                }
                                if (startDate == null ||
                                    startTime == null ||
                                    endDate == null ||
                                    endTime == null) {
                                  return _showSnack("Select date & time");
                                }
                                if (selectedColor == null) {
                                  return _showSnack("Select a color");
                                }
                                if (selectedClasses.isEmpty) {
                                  return _showSnack("Select at least 1 class");
                                }

                                final startDateTime = DateTime(
                                  startDate!.year,
                                  startDate!.month,
                                  startDate!.day,
                                  startTime!.hour,
                                  startTime!.minute,
                                );

                                final endDateTime = DateTime(
                                  endDate!.year,
                                  endDate!.month,
                                  endDate!.day,
                                  endTime!.hour,
                                  endTime!.minute,
                                );

                                final colorString =
                                    "0x${selectedColor!.toARGB32().toRadixString(16)}";

                                final event = EventModel(
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  color: colorString,
                                  startDateTime: startDateTime,
                                  endDateTime: endDateTime,
                                  classes: selectedClasses,
                                  createdAt: DateTime.now(),
                                  delete: false,
                                );

                                try {
                                  final eventsRef = ref.read(
                                    eventFirestoreProvider,
                                  );

                                  final newDocId = titleController.text.trim();
                                  final oldDocId = existingEvent?.title;

                                  if (isEdit &&
                                      oldDocId != null &&
                                      oldDocId != newDocId) {
                                    // 🔥 Title changed → delete old doc
                                    await eventsRef.doc(oldDocId).delete();
                                  }

                                  // ✅ SAVE USING TITLE AS DOC ID
                                  await eventsRef.doc(newDocId).set(event);

                                  Navigator.pop(context);
                                  _showSnack(
                                    isEdit
                                        ? "Event updated successfully"
                                        : "Event saved successfully",
                                    success: true,
                                  );
                                } catch (e) {
                                  _showSnack("Failed to save event");
                                }
                              },
                              child: Text(
                                isEdit ? "Update Event" : "Save Event",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _classChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xff4583FF) : Colors.grey.shade300,
        ),
        color: selected ? const Color(0xffE8F0FF) : const Color(0xfff4f7fa),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: selected ? const Color(0xff2970FF) : Colors.black87,
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      String value = colorString;
      if (value.startsWith('0x')) {
        value = value.substring(2);
      } else if (value.startsWith('#')) {
        value = value.substring(1);
      }
      final intColor = int.parse(value, radix: 16);
      return Color(intColor);
    } catch (_) {
      return const Color(0xff2970FF);
    }
  }

  //------------------------------fee add--------------------------------------------

  List<String> feeClasses = [];

  void _showAddFeeBottomSheet() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    List<String> selectedClasses = [];
    List<Map<String, dynamic>> allStudents = [];
    List<Map<String, dynamic>> filteredStudents = [];
    int studentCount = 0;
    int totalAmount = 0;

    /// 🔹 FETCH ALL STUDENTS (ADMIN ACTION)
    final snapshot = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .get();

    allStudents = snapshot.docs.map((doc) {
      return {
        "name": doc["studentName"],
        "id": doc["studentId"],
        "classNo": doc["classNo"].toString(),
        "division": doc["division"],
        "status": "unpaid",
        "collected": false,
      };
    }).toList();

    void updateStudents(
      String feeText,
      void Function(void Function()) setState,
    ) {
      setState(() {
        filteredStudents = allStudents.where((s) {
          return selectedClasses.contains(s['classNo']);
        }).toList();

        studentCount = filteredStudents.length;

        final fee = int.tryParse(feeText) ?? 0;
        totalAmount = fee * studentCount;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 20,
                      color: Colors.black26,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// TITLE
                      const Text(
                        "Add Fee",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// DESCRIPTION (WITH SUGGESTIONS)
                      _descriptionField(
                        context: context,
                        controller: descriptionController,
                        onSelectSuggestion: (selected) async {
                          final snap = await FirebaseFirestore.instance
                              .schoolCollection(FirebaseConstant.fees)
                              .doc(selected)
                              .get();

                          if (snap.exists) {
                            final data = snap.data();
                            if (data != null && data.isNotEmpty) {
                              final firstClass = data.values.first;
                              if (firstClass is Map &&
                                  firstClass['ALL'] != null) {
                                amountController.text = firstClass['ALL']['fee']
                                    .toString();
                              }
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      /// AMOUNT
                      _buildTextField(
                        amountController,
                        "Amount (per student)",
                        inputType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (val) {
                          updateStudents(val, setState);
                        },
                      ),

                      const SizedBox(height: 20),

                      /// CLASS SELECTION
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Select Classes",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: feeClasses.map((cls) {
                          final isSelected = cls == 'All'
                              ? selectedClasses.length == (feeClasses.length - 1)
                              : selectedClasses.contains(cls);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (cls == 'All') {
                                  if (selectedClasses.length == (feeClasses.length - 1)) {
                                    selectedClasses.clear();
                                  } else {
                                    selectedClasses = feeClasses
                                        .where((c) => c != 'All')
                                        .toList();
                                  }
                                } else {
                                  selectedClasses.contains(cls)
                                      ? selectedClasses.remove(cls)
                                      : selectedClasses.add(cls);
                                }
                              });

                              updateStudents(amountController.text, setState);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                ),
                                color: isSelected
                                    ? Colors.blue.withValues(alpha: .12)
                                    : Colors.grey.shade100,
                              ),
                              child: Text(
                                cls,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      /// INFO CARD
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _rowInfo("Students:", studentCount.toString()),
                            const SizedBox(height: 6),
                            _rowInfo(
                              "Total Amount:",
                              "₹$totalAmount",
                              valueColor: Colors.green,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                      /// SUBMIT
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
                            final studentsMap =
                                await _getStudentsByClassDivision();
                            final teachersMap = await _getTeachersMap();

                            final selected = selectedClasses.contains('All')
                                ? List.generate(12, (i) => (i + 1).toString())
                                : selectedClasses;

                            for (final cls in selected) {
                              final double feeAmount = double.parse(
                                amountController.text,
                              );
                              final classNo = int.parse(cls);

                              final divisions = studentsMap.keys
                                  .where((k) => k.startsWith("${classNo}_"))
                                  .map((k) => k.split('_')[1])
                                  .toSet();

                              for (final div in divisions) {
                                final key = "${classNo}_$div";
                                final students = studentsMap[key] ?? [];

                                if (students.isEmpty) continue;

                                final teacher = teachersMap[key];

                                final int collectedCount = students
                                    .where((s) => s['collected'] == true)
                                    .length;

                                final fee = FeeModel(
                                  description: descriptionController.text
                                      .trim(),
                                  fee: feeAmount,
                                  totalAmount: feeAmount * collectedCount,
                                  classNo: classNo,
                                  collectedCount: 0,
                                  division: div,
                                  teacherName:
                                      teacher?['name'] ?? 'Not Assigned',
                                  teacherId: teacher?['id'] ?? '',
                                  delete: false,
                                  completed: false,
                                  createdDate: DateTime.now(),
                                  students: students,
                                );

                                await FirebaseFirestore.instance
                                    .schoolCollection(FirebaseConstant.fees)
                                    .doc(
                                      fee.description,
                                    ) // 👈 description = docId
                                    .set({
                                      classNo.toString(): {div: fee.toMap()},
                                    }, SetOptions(merge: true));
                              }
                            }
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Add Fee",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    double width = double.infinity,
    TextInputType inputType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    onChanged,
  }) {
    return SizedBox(
      height: 65,
      width: width,
      child: TextFormField(
        onChanged: onChanged,
        controller: controller,
        keyboardType: inputType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          labelText: label, // 👈 FLOATING LABEL
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
          suffixIcon: suffixIcon,
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
    );
  }

  Widget _rowInfo(
    String label,
    String value, {
    Color valueColor = Colors.black,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.black)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _descriptionField({
    required BuildContext context,
    required TextEditingController controller,
    required Function(String) onSelectSuggestion,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final suggestionsAsync = ref.watch(feeDescriptionsProvider);

        return suggestionsAsync.when(
          data: (list) {
            final suggestions = list
                .where(
                  (item) => item.toLowerCase().contains(
                    controller.text.toLowerCase(),
                  ),
                )
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TEXT FIELD
                TextFormField(
                  controller: controller,
                  onChanged: (_) {
                    (context as Element).markNeedsBuild();
                  },
                  decoration: InputDecoration(
                    labelText: "Description",
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    labelStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color(0xFF5E6777),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                  ),
                ),

                // SUGGESTION LIST — shows only when typing
                if (controller.text.isNotEmpty && suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: suggestions.map((suggestion) {
                        return ListTile(
                          dense: true,
                          title: Text(suggestion),
                          onTap: () {
                            controller.text = suggestion;
                            onSelectSuggestion(suggestion);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xff1193D4)),
          ),
          error: (e, _) => Text("Error: $e"),
        );
      },
    );
  }

  Future<Map<String, Map<String, String>>> _getTeachersMap() async {
    final snap = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.teacher)
        .where('delete', isEqualTo: false)
        .get();

    final Map<String, Map<String, String>> teachers = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final key = "${data['classNo']}_${data['division']}";

      teachers[key] = {"id": doc.id, "name": data['teacherName']};
    }

    return teachers;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  _getStudentsByClassDivision() async {
    final snap = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.student)
        .where('delete', isEqualTo: false)
        .get();

    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final key = "${data['classNo']}_${data['division']}";

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add({
        "id": doc.id,
        "name": data['studentName'],
        "status": "unpaid",
        "collected": false,
      });
    }

    return grouped;
  }

  //------------------------------teacher add--------------------------------------------

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  bool _isPasswordValid(String password) {
    return password.length >= 6;
  }

  Widget _buildTextFieldWithValidation(
    TextEditingController controller,
    String label, {
    bool isEmail = false,
    bool isPassword = false,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    bool isValid = true;
    return StatefulBuilder(
      builder: (context, setStateField) {
        return TextField(
          controller: controller,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onChanged: (v) {
            setStateField(() {
              if (isEmail) isValid = _isEmailValid(v);
              if (isPassword) isValid = _isPasswordValid(v);
            });
          },
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: (isEmail || isPassword)
                ? (controller.text.isEmpty
                      ? null
                      : Icon(
                          isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: isValid ? Colors.green : Colors.red,
                        ))
                : null,
          ),
        );
      },
    );
  }

  Widget _buildDropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPhoneField() {
    return CountryPhoneField(
      controller: _mobileController,
      labelText: 'Mobile No',
    );
  }

  Widget _buildDateOfBirthField() {
    return Row(
      children: [
        Expanded(
          child: _buildTextFieldWithValidation(
            _dayController,
            "DD",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextFieldWithValidation(
            _monthController,
            "MM",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTextFieldWithValidation(
            _yearController,
            "YYYY",
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddTeacherSheet() {
    final addTeacher = ref.read(addTeacherProvider);

    // 🔹 CLEAR EVERYTHING (no edit support)
    _teacherIdController.clear();
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _mobileController.clear();
    _subjectController.clear();
    _addressController.clear();
    _dayController.clear();
    _monthController.clear();
    _yearController.clear();
    _selectedClass = '0';
    _selectedDiv = 'Nil';
    _selectedGender = null;
    _uploadedImageUrl = null;
    _selectedFile = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          width: 600,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 40,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Add New Teacher',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                /// IMAGE
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _selectedFile != null
                              ? FileImage(_selectedFile!)
                              : const AssetImage(ImageConstant.temporaryTeacherImage)
                                  as ImageProvider,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xff1193D4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextFieldWithValidation(_teacherIdController, "Teacher ID"),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_nameController, "Name"),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_subjectController, "Subject"),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        "Class",
                        _selectedClass,
                        List.generate(13, (i) => '$i'),
                        (v) => setState(() => _selectedClass = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        "Division",
                        _selectedDiv,
                        ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'Nil'],
                        (v) => setState(() => _selectedDiv = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildDropdown("Gender", _selectedGender, ['Male', 'Female'], (v) => setState(() => _selectedGender = v)),
                const SizedBox(height: 14),
                _buildPhoneField(),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_emailController, "Email",
                    isEmail: true, readOnly: true),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_passwordController, "Password",
                    isPassword: true, readOnly: true),
                const SizedBox(height: 14),
                _buildTextFieldWithValidation(_addressController, "Address"),
                const SizedBox(height: 16),
                const Text(
                  "Date of Birth",
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildDateOfBirthField(),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1193D4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isUploading
                        ? null
                        : () async {
                            final employeeId = _teacherIdController.text.trim();
                            final name = _nameController.text.trim();
                            final mobile = _mobileController.text.trim();
                            final subject = _subjectController.text.trim();
                            final address = _addressController.text.trim();
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final dayStr = _dayController.text.trim();
                            final monthStr = _monthController.text.trim();
                            final yearStr = _yearController.text.trim();

                            if (employeeId.isEmpty) {
                              AlertInfo.show(
                                context: context,
                                text: 'Employee ID cannot be empty',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (name.isEmpty) {
                              AlertInfo.show(
                                context: context,
                                text: 'Name cannot be empty',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (subject.isEmpty) {
                              AlertInfo.show(
                                context: context,
                                text: 'Subject cannot be empty',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (_selectedClass == null || _selectedDiv == null) {
                              AlertInfo.show(
                                context: context,
                                text: 'Please select Class and Division',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (_selectedGender == null) {
                              AlertInfo.show(
                                context: context,
                                text: 'Please select Gender',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            final phoneError = getPhoneValidationErrorMessage(mobile);
                            if (phoneError.isNotEmpty) {
                              AlertInfo.show(
                                context: context,
                                text: phoneError,
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (!_isEmailValid(email)) {
                              AlertInfo.show(
                                context: context,
                                text: 'Please enter a valid Email',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (!_isPasswordValid(password)) {
                              AlertInfo.show(
                                context: context,
                                text: 'Password must be at least 6 characters',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            if (address.isEmpty) {
                              AlertInfo.show(
                                context: context,
                                text: 'Address cannot be empty',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                              return;
                            }
                            final dayVal = int.tryParse(dayStr);
                            final monthVal = int.tryParse(monthStr);
                            final yearVal = int.tryParse(yearStr);
                            if (dayVal == null || dayVal < 1 || dayVal > 31 ||
                                monthVal == null || monthVal < 1 || monthVal > 12 ||
                                yearVal == null || yearVal < 1900 || yearVal > DateTime.now().year) {
                              AlertInfo.show(
                                context: context,
                                text: 'Please enter a valid Date of Birth (DD/MM/YYYY)',
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                               );
                              return;
                            }

                            setState(() => _isUploading = true);

                            try {
                              if (_selectedFile != null) {
                                _uploadedImageUrl = await ref.read(
                                  teacherImageUploadProvider,
                                )(_selectedFile!);
                              }
                              final dob = DateTime(
                                int.parse(_yearController.text),
                                int.parse(_monthController.text),
                                int.parse(_dayController.text),
                              );

                              final teacher = TeacherModel(
                                id: '',
                                employeeId: _teacherIdController.text,
                                mobileNo: _mobileController.text,
                                teacherName: _nameController.text,
                                classNo: int.parse(_selectedClass!),
                                division: _selectedDiv!,
                                subject: _subjectController.text,
                                email: _emailController.text,
                                password: _passwordController.text,
                                address: _addressController.text,
                                gender: _selectedGender!,
                                imageUrl: _uploadedImageUrl ?? '',
                                delete: false,
                                createdDate: DateTime.now(),
                                dateOfBirth: dob,
                              );

                              await addTeacher(teacher);

                              if (context.mounted) {
                                Navigator.pop(context);
                                AlertInfo.show(
                                  context: context,
                                  text: 'Teacher added successfully',
                                  typeInfo: TypeInfo.success,
                                  iconColor: Colors.white,
                                  backgroundColor: const Color(0xFF27AE60),
                                  textColor: Colors.white,
                                  position: MessagePosition.top,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AlertInfo.show(
                                  context: context,
                                  text: "Error: $e",
                                  typeInfo: TypeInfo.error,
                                  iconColor: Colors.white,
                                  backgroundColor: Colors.redAccent,
                                  textColor: Colors.white,
                                  position: MessagePosition.top,
                                );
                              }
                            } finally {
                              setState(() => _isUploading = false);
                            }
                          },
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Add Teacher"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //------------------------------student add--------------------------------------------

  Future<String> _uploadToCloudinary(File file) async {
    final response = await CloudinaryService.studentProfile.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: 'student_images'),
    );
    return response.secureUrl;
  }



  int _classNoToInt(String classNoStr) {
    if (classNoStr == 'LKG') return -2;
    if (classNoStr == 'UKG') return -1;
    return int.tryParse(classNoStr) ?? 0;
  }

  Widget _buildClassAndDivisionDropdowns(List<ClassModel> classes, StateSetter setSheetState) {
    final activeClasses = classes.where((c) => !c.delete).toList();
    final uniqueClassNumbers = activeClasses.map((c) => c.classNo).toSet().toList();
    uniqueClassNumbers.sort((a, b) => _classNoToInt(a).compareTo(_classNoToInt(b)));

    final availableDivisions = _classNo == null
        ? <String>[]
        : activeClasses
            .where((c) => c.classNo == _classNo)
            .map((c) => c.division)
            .toSet()
            .toList()
          ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _classNo,
                hint: const Text("Select Class"),
                items: uniqueClassNumbers.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    _classNo = v;
                    _division = null; // reset division
                    _selectedTeacherId = null;
                    _selectedTeacherName = null;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Class',
                  labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _division,
                hint: const Text("Select Division"),
                items: availableDivisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) {
                  setSheetState(() {
                    _division = v;
                    if (_classNo != null && _division != null) {
                      final selectedClassModel = activeClasses.firstWhere(
                        (c) => c.classNo == _classNo && c.division == _division,
                        orElse: () => ClassModel(classNo: _classNo!, division: _division!, className: '', delete: false, createdDate: DateTime.now()),
                      );
                      _selectedTeacherId = selectedClassModel.teacherId;
                      _selectedTeacherName = selectedClassModel.teacherName;
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Division',
                  labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xff1193D4), width: 1.5),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        if (_selectedTeacherName != null && _selectedTeacherName!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Assigned Teacher: $_selectedTeacherName",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xff1193D4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 🔹 Add/Edit Modal Sheet
  void _showStudentDialog() {
    // 🔹 CLEAR EVERYTHING (ADD ONLY)
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _rollController.clear();
    _admissionController.clear();
    _mobileController.clear();
    _parentController.clear();
    _addressController.clear();
    _dayController.clear();
    _monthController.clear();
    _yearController.clear();

    _selectedGender = null;
    _selectedTeacherName = null;
    _selectedTeacherId = null;
    _classNo = null;
    _division = null;
    _uploadedImageUrl = null;
    _selectedFile = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final List<ClassModel> classes = ref.read(classesStreamProvider).value ?? <ClassModel>[];
          return Center(
            child: Container(
              width: 600,
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 40,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(28),
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Add New Student',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    /// PROFILE IMAGE
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _selectedFile != null
                                  ? FileImage(_selectedFile!)
                                  : const AssetImage(ImageConstant.temporaryStudentImage)
                                      as ImageProvider,
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () async {
                                await _pickImage();
                                setSheetState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xff1193D4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextFieldWithValidation(_admissionController, "Admission No", inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ]),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_nameController, "Name"),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_rollController, "Roll No", inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ]),
                    const SizedBox(height: 14),
                    _buildPhoneField(),
                    const SizedBox(height: 14),
                    _buildDropdown("Gender", _selectedGender, ['Male', 'Female', 'Other'], (v) => setSheetState(() => _selectedGender = v)),
                    const SizedBox(height: 14),
                    _buildClassAndDivisionDropdowns(classes, setSheetState),
                    const SizedBox(height: 14),
                    const Text(
                      "Date of Birth",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _buildDateOfBirthField(),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_parentController, "Parent Name"),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_addressController, "Address"),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_emailController, "Email",
                        isEmail: true, readOnly: true),
                    const SizedBox(height: 14),
                    _buildTextFieldWithValidation(_passwordController, "Password",
                        isPassword: true, readOnly: true),
                    const SizedBox(height: 28),

                    /// SAVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff1193D4),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () async {
                          final admissionNo = _admissionController.text.trim();
                          final rollNo = _rollController.text.trim();
                          final name = _nameController.text.trim();
                          final mobile = _mobileController.text.trim();
                          final parent = _parentController.text.trim();
                          final address = _addressController.text.trim();
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          final day = _dayController.text.trim();
                          final month = _monthController.text.trim();
                          final year = _yearController.text.trim();

                          if (admissionNo.isEmpty || admissionNo.length != 6) {
                            AlertInfo.show(
                              context: context,
                              text: 'Admission number must be exactly 6 digits',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (name.isEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: 'Name cannot be empty',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (rollNo.isEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: 'Roll number cannot be empty',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          final phoneError = getPhoneValidationErrorMessage(mobile);
                          if (phoneError.isNotEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: phoneError,
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (_selectedGender == null || _selectedGender!.isEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: 'Please select a gender',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (_classNo == null || _division == null) {
                            AlertInfo.show(
                              context: context,
                              text: 'Please select Class and Division',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          final dayVal = int.tryParse(day);
                          final monthVal = int.tryParse(month);
                          final yearVal = int.tryParse(year);
                          if (dayVal == null || dayVal < 1 || dayVal > 31 ||
                              monthVal == null || monthVal < 1 || monthVal > 12 ||
                              yearVal == null || yearVal < 1900 || yearVal > DateTime.now().year) {
                            AlertInfo.show(
                              context: context,
                              text: 'Please enter a valid Date of Birth (DD/MM/YYYY)',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (parent.isEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: 'Parent name cannot be empty',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (address.isEmpty) {
                            AlertInfo.show(
                              context: context,
                              text: 'Address cannot be empty',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (!_isEmailValid(email)) {
                            AlertInfo.show(
                              context: context,
                              text: 'Please enter a valid Email',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }
                          if (!_isPasswordValid(password)) {
                            AlertInfo.show(
                              context: context,
                              text: 'Password must be at least 6 characters',
                              typeInfo: TypeInfo.error,
                              iconColor: Colors.white,
                              backgroundColor: Colors.redAccent,
                              textColor: Colors.white,
                              position: MessagePosition.top,
                            );
                            return;
                          }

                          setSheetState(() => _isUploading = true);
                          setState(() => _isUploading = true);

                          try {
                            if (_selectedFile != null) {
                              _uploadedImageUrl = await _uploadToCloudinary(
                                _selectedFile!,
                              );
                            }

                            final dob = DateTime(
                              int.parse(_yearController.text),
                              int.parse(_monthController.text),
                              int.parse(_dayController.text),
                            );

                            final student = StudentsModel(
                              studentId: '',
                              admissionNo: int.parse(_admissionController.text),
                              rollNo: int.parse(_rollController.text),
                              studentName: _nameController.text,
                              mobileNo: _mobileController.text,
                              email: _emailController.text,
                              password: _passwordController.text,
                              address: _addressController.text,
                              parentName: _parentController.text,
                              classNo: _classNoToInt(_classNo!),
                              division: _division!,
                              teacherName: _selectedTeacherName ?? '',
                              teacherId: _selectedTeacherId ?? '',
                              gender: _selectedGender ?? '',
                              delete: false,
                              imageUrl: _uploadedImageUrl ?? '',
                              dateOfBirth: dob,
                              createdDate: DateTime.now(),
                            );

                            final studentCollectionRef = FirebaseFirestore.instance.schoolCollection(
                              FirebaseConstant.student,
                            );
                            final classRepo = ref.read(classWiseTeacherRepoProvider);
                            final doc = await studentCollectionRef.add(student.toMap());
                            final studentId = doc.id;
                            await doc.update({'studentId': studentId});

                            await classRepo.syncStudentToClass(
                              newClassNo: _classNoToString(student.classNo),
                              newDivision: student.division,
                              studentId: studentId,
                              studentName: student.studentName,
                              imageUrl: student.imageUrl,
                              rollNo: student.rollNo,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              AlertInfo.show(
                                context: context,
                                text: 'Student added successfully',
                                typeInfo: TypeInfo.success,
                                iconColor: Colors.white,
                                backgroundColor: const Color(0xFF27AE60),
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AlertInfo.show(
                                context: context,
                                text: "Error: $e",
                                typeInfo: TypeInfo.error,
                                iconColor: Colors.white,
                                backgroundColor: Colors.redAccent,
                                textColor: Colors.white,
                                position: MessagePosition.top,
                              );
                            }
                          } finally {
                            setSheetState(() => _isUploading = false);
                            setState(() => _isUploading = false);
                          }
                              },
                        child: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Add Student"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  //------------------------------- body ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesStreamProvider);
    final classesList = classesAsync.value ?? [];
    final activeClasses = classesList.where((c) => !c.delete).toList();
    final uniqueClasses = activeClasses.map((c) => c.classNo).toSet().toList();
    uniqueClasses.sort((a, b) => _classNoToInt(a).compareTo(_classNoToInt(b)));
    allClasses = uniqueClasses;
    feeClasses = ['All', ...uniqueClasses];

    ref.watch(cleanExpiredSubstitutionsProvider); // 👈 AUTO RUN
    final totalStudentsAsync = ref.watch(totalStudentsProvider);
    final feesCollectedAsync = ref.watch(feesCollectedProvider);
    final pendingFeesAsync = ref.watch(pendingFeesProvider);
    final teachersAsync = ref.watch(teachersProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Title, Subtitle, Refresh Button)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Overview of key school metrics and performance.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
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
                      ref.invalidate(classesStreamProvider);
                      ref.invalidate(cleanExpiredSubstitutionsProvider);
                      ref.invalidate(totalStudentsProvider);
                      ref.invalidate(feesCollectedProvider);
                      ref.invalidate(pendingFeesProvider);
                      ref.invalidate(teachersProvider);
                      ref.invalidate(studentsProvider);
                      ref.invalidate(unmarkedClassesProvider);
                      ref.invalidate(upcomingEventsProvider);
                      ref.invalidate(activeTeachersProvider);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // TOP CARDS
            Row(
              children: [
                totalStudentsAsync.when(
                  data: (total) => _summaryCard(
                    "Total Students",
                    total.toString(),
                    Icons.people,
                    const Color(0xff1193D4),
                  ),
                  loading: () => _summaryCard(
                    "Total Students",
                    "Loading...",
                    Icons.people,
                    const Color(0xff1193D4),
                  ),
                  error: (e, _) => _summaryCard(
                    "Total Students",
                    "Error",
                    Icons.people,
                    const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 16),
                feesCollectedAsync.when(
                  data: (amount) => _summaryCard(
                    "Fees Collected",
                    "₹${amount.toStringAsFixed(0)}",
                    Icons.attach_money,
                    const Color(0xFF10B981),
                  ),
                  loading: () => _summaryCard(
                    "Fees Collected",
                    "Loading...",
                    Icons.attach_money,
                    const Color(0xFF10B981),
                  ),
                  error: (e, _) => _summaryCard(
                    "Fees Collected",
                    "Error",
                    Icons.attach_money,
                    const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 16),
                pendingFeesAsync.when(
                  data: (amount) => _summaryCard(
                    "Pending Fees",
                    "₹${amount.toStringAsFixed(0)}",
                    Icons.pending_actions,
                    const Color(0xFFF59E0B),
                  ),
                  loading: () => _summaryCard(
                    "Pending Fees",
                    "Loading...",
                    Icons.pending_actions,
                    const Color(0xFFF59E0B),
                  ),
                  error: (e, _) => _summaryCard(
                    "Pending Fees",
                    "Error",
                    Icons.pending_actions,
                    const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _attendanceOverviewWithDependency(),

            const SizedBox(height: 24),

            // Calendar + Quick Actions AND Upcoming Events
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _quickActionsWithCalendar()),
                const SizedBox(width: 24),
                Expanded(child: _upcomingEvents()),
              ],
            ),

            const SizedBox(height: 24),

            // TEACHERS + STUDENTS
            Row(
              children: [
                Expanded(
                  child: teachersAsync.when(
                    data: (teachers) => _teachersListFromModel(teachers),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) {
                      log(e.toString());
                      return const Text("Failed to load teachers");
                    },
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: studentsAsync.when(
                    data: (students) => _studentListFromModel(students),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) {
                      log(e.toString());
                      return const Text("Failed to load students");
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _activeTeachers(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY CARD
  // ---------------------------------------------------------------------------
  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    final gradient = LinearGradient(
      colors: [Colors.white, const Color(0xFFF8FAFC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Expanded(
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.15), width: 1),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
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

  Widget _attendanceOverviewWithDependency() {
    final unmarkedAsync = ref.watch(unmarkedClassesProvider);
    final totalStudentsAsync = ref.watch(totalStudentsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT – CIRCLE
          Expanded(
            flex: 2,
            child: totalStudentsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Text("Error: $e"),

              data: (totalStudents) {
                final attendanceAsync =
                ref.watch(todayAttendanceProvider(totalStudents));

                return attendanceAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Text("Error: $e"),

                  data: (attendance) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Today's Attendance Overview",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Center(
                          child: CircularPercentIndicator(
                            radius: 75,
                            lineWidth: 12,
                            percent: attendance.percent.clamp(0.0, 1.0),
                            animation: true,
                            animationDuration: 2000,
                            circularStrokeCap: CircularStrokeCap.round,
                            backgroundColor: const Color(0xFFFECDD3), // Soft rose/red
                            progressColor: const Color(0xff1193D4), // Premium blue
                            startAngle: 180,
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${(attendance.percent * 100).round()}%",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Present",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          "Students Present",
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                        const SizedBox(height: 6),

                        Text(
                          "${attendance.presentStudents} / ${attendance.totalStudents}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Row(
                          children: [
                            _LegendDot(color: Color(0xff1193D4), label: "Present"),
                            SizedBox(width: 20),
                            _LegendDot(color: Color(0xFFEF4444), label: "Absent"),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(width: 16),

          SizedBox(
            height: 320, // match left content height
            child: VerticalDivider(
              thickness: 1.2,
              width: 1,
              color: Colors.grey.shade200,
            ),
          ),

          const SizedBox(width: 24),

          // RIGHT – UNMARKED CLASSES
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "UNMARKED CLASSES",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    unmarkedAsync.maybeWhen(
                      data: (unmarked) {
                        if (unmarked.length > 4) {
                          return TextButton(
                            onPressed: () {
                              _showUnmarkedClassesSheet(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xff1193D4),
                            ),
                            child: const Text(
                              "View All",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                unmarkedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) {
                    log(e.toString());
                    return Text("Error: $e");
                  },
                  data: (unmarked) {
                    if (unmarked.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Center(
                          child: Text(
                            "All classes marked",
                            style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: unmarked
                          .take(4)
                          .map(
                            (c) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c['label'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xff1193D4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () {
                                      context.push(
                                        '/admin/classrooms/attendance/${c['teacherId']}',
                                      );
                                    },
                                    child: const Text(
                                      "Mark",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnmarkedClassesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Consumer(
          builder: (context, ref, _) {
            final asyncUnmarked = ref.watch(unmarkedClassesProvider);

            return Center(
              child: Material(
                elevation: 20,
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                child: SizedBox(
                  width: 520,
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Unmarked Classes",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 12),

                        asyncUnmarked.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) {
                            log(e.toString());
                            return Text("Error: $e");
                          },
                          data: (list) {
                            if (list.isEmpty) {
                              return const Expanded(
                                child: Center(
                                  child: Text("All classes marked"),
                                ),
                              );
                            }

                            return Expanded(
                              child: ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final item = list[i];

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['label'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xff1193D4),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(context);

                                            context.push(
                                              '/admin/classrooms/attendance/${item['teacherId']}',
                                            );
                                          },
                                          child: const Text(
                                            "Mark",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // QUICK ACTIONS + CALENDAR
  // ---------------------------------------------------------------------------
  Widget _quickActionsWithCalendar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions & Schedule",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              // Calendar panel
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.utc(2030),
                  focusedDay: focusedDay,
                  availableGestures: AvailableGestures.all,
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    headerPadding: const EdgeInsets.only(top: 12, bottom: 12),
                    titleTextStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: Colors.grey.shade600),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                    weekendTextStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFEF4444),
                    ),
                    todayDecoration: const BoxDecoration(
                      color: Color(0xff1193D4),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 32),

              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 350,
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final icons = [
                        Icons.person_add_outlined,
                        CupertinoIcons.person_alt_circle_fill,
                        Icons.wallet_outlined,
                        Icons.event_outlined,
                      ];

                      final labels = [
                        "Add Student",
                        "Add Teacher",
                        "Add Fee",
                        "Add Event",
                      ];

                      return _actionBox(icons[index], labels[index], () {
                        if (labels[index] == "Add Event") {
                          _showAddEditEventDialog();
                        } else if (labels[index] == "Add Fee") {
                          _showAddFeeBottomSheet();
                        } else if (labels[index] == "Add Teacher") {
                          _showAddTeacherSheet();
                        } else if (labels[index] == "Add Student") {
                          _showStudentDialog();
                        }
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBox(IconData icon, String label, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xff1193D4).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xff1193D4), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UPCOMING EVENTS
  // ---------------------------------------------------------------------------
  Widget _upcomingEvents() {
    final eventsAsync = ref.watch(upcomingEventsProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Upcoming Events",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/admin/events');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff1193D4),
                ),
                child: const Text(
                  "View Calendar",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              log(e.toString());
              return const Text(
                "Failed to load events",
                style: TextStyle(color: Colors.red),
              );
            },
            data: (events) {
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      "No upcoming events",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ),
                );
              }

              return Column(
                children: events.map((event) {
                  final date = event.startDateTime;
                  final color = _parseColor(event.color);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _eventTile(
                      DateFormat('MMM').format(date).toUpperCase(),
                      DateFormat('dd').format(date),
                      color,
                      event.title,
                      _eventSubtitle(event),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _eventSubtitle(EventModel event) {
    if (event.classes.length == 12) {
      return "All Classes";
    }
    return "Classes: ${event.classes.join(', ')}";
  }

  Widget _eventTile(
    String m,
    String d,
    Color color,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  d,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TEACHER LIST
  // ---------------------------------------------------------------------------
  Widget _teachersListFromModel(List<TeacherModel> teachers) {
    return _tableCard(
      "Teachers List",
      ["Name", "Subject", "Class / Division"],
      teachers
          .map(
            (t) => _rowItem(
              t.teacherName,
              t.subject,
              "${t.classNo}-${t.division}",
            ),
          )
          .toList(),
      onViewAll: () {
        context.go('/admin/teachers');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STUDENT LIST
  // ---------------------------------------------------------------------------
  Widget _studentListFromModel(List<StudentsModel> students) {
    return _tableCard(
      "Students List",
      ['ID', "Name", "Class / Division"],
      students
          .map(
            (s) => _rowItem(
              '#${s.admissionNo}',
              s.studentName,
              "${s.classNo}-${s.division}",
            ),
          )
          .toList(),
      onViewAll: () {
        context.go('/admin/students');
      },
    );
  }

  Widget _tableCard(
    String title,
    List<String> heads,
    List<Widget> rows, {
    VoidCallback? onViewAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff1193D4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text(
                    "View All",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // TABLE HEADER
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    heads[0],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    heads[1],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    heads[2],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  "No items found",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
            )
          else
            // TABLE ROWS
            ...rows.map(
              (row) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: row,
              ),
            ),
        ],
      ),
    );
  }

  Widget _rowItem(String c1, String c2, String c3) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            c1,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            c2,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Color(0xFF475569),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            c3,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIVE TEACHERS
  // ---------------------------------------------------------------------------
  Widget _activeTeachers() {
    final teachersAsync = ref.watch(activeTeachersProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Active Teachers",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/admin/classrooms');
                },
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xff1193D4),
                ),
                child: const Text(
                  "View Directory",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          teachersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) {
              log(e.toString());
              return const Text("Failed to load teachers");
            },
            data: (teachers) {
              if (teachers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "No active teachers found",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: teachers
                      .map(
                        (t) => _teacherAvatar(
                          teacherId: t.id,
                          name: t.teacherName,
                          imageUrl: t.imageUrl,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _teacherAvatar({
    required String teacherId,
    required String name,
    required String imageUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              context.push(
                '/admin/classrooms/teacher-dashboard/$teacherId',
              );
            },
            borderRadius: BorderRadius.circular(40),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xff1193D4).withValues(alpha: 0.4), const Color(0xff1193D4).withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFF1F5F9),
                backgroundImage: imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: imageUrl.isEmpty
                    ? Text(
                        _initials(name),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff1193D4),
                        ),
                      )
                    : null,
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: 86,
            child: Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(" ");
    if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0] : '';
    return (parts[0].isNotEmpty ? parts[0][0] : '') + (parts[1].isNotEmpty ? parts[1][0] : '');
  }

  // ---------------------------------------------------------------------------
  // CARD DECORATION (SOFT SHADOW)
  // ---------------------------------------------------------------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade100, width: 1.5),
      boxShadow: [
        BoxShadow(
          blurRadius: 16,
          offset: const Offset(0, 8),
          color: Colors.black.withValues(alpha: .03),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
