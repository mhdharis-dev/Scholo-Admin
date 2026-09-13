import 'dart:developer';
import 'package:flutter_riverpod/legacy.dart';
import '../repository/attendance_repository.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/students_model.dart';
import '../../../../models/attendance_model.dart';

class AttendanceState {
  final bool loading;
  final TeacherModel? teacher;
  final List<StudentsModel> students;
  final Map<String, bool?> status; // studentId => true/false/null
  final DateTime date;
  final String half;

  AttendanceState({
    required this.loading,
    required this.teacher,
    required this.students,
    required this.status,
    required this.date,
    required this.half,
  });

  AttendanceState copyWith({
    bool? loading,
    TeacherModel? teacher,
    List<StudentsModel>? students,
    Map<String, bool?>? status,
    DateTime? date,
    String? half,
  }) {
    return AttendanceState(
      loading: loading ?? this.loading,
      teacher: teacher ?? this.teacher,
      students: students ?? this.students,
      status: status ?? this.status,
      date: date ?? this.date,
      half: half ?? this.half,
    );
  }
}

class AttendanceController extends StateNotifier<AttendanceState> {
  final AttendanceRepository repo;

  AttendanceController(this.repo)
      : super(AttendanceState(
    loading: false,
    teacher: null,
    students: const [],
    status: {},
    date: DateTime.now(),
    half: "Morning",
  ));

  // -------------------------------------------------------
  // INIT - LOAD TEACHER + STUDENTS + CACHE OR FIRESTORE
  // -------------------------------------------------------
  Future<void> init(String teacherId) async {
    state = state.copyWith(loading: true);

    try {
      // Load teacher
      final teacher = await repo.fetchTeacher(teacherId);

      // Load students
      final students = await repo.fetchStudents(teacher);

      // Load existing firebase attendance for selected date
      final existing = await repo.fetchExistingAttendance(
        date: state.date,
        teacher: teacher,
      );

      final isMorning = state.half == "Morning";
      final statusMap = <String, bool?>{};
      for (var s in students) {
        if (existing.containsKey(s.studentId)) {
          final att = existing[s.studentId]!;
          final status = att.status;
          if (isMorning) {
            if (status.contains("Morning")) {
              statusMap[s.studentId] = true;
            } else {
              statusMap[s.studentId] = false;
            }
          } else {
            if (status.contains("Evening")) {
              statusMap[s.studentId] = true;
            } else {
              statusMap[s.studentId] = false;
            }
          }
        } else {
          // Default status is Present (true)
          statusMap[s.studentId] = true;
        }
      }

      state = state.copyWith(
        loading: false,
        teacher: teacher,
        students: students,
        status: statusMap,
      );
    } catch (e, stack) {
      log("INIT ERROR: $e");
      log(stack.toString());
      state = state.copyWith(loading: false);
    }
  }

  // -------------------------------------------------------
  // CHANGE HALF
  // -------------------------------------------------------
  Future<void> setHalf(String half) async {
    state = state.copyWith(half: half);
    if (state.teacher != null) {
      await init(state.teacher!.id);
    }
  }

  // -------------------------------------------------------
  // CHANGE DATE → reload attendance for that date
  // -------------------------------------------------------
  Future<void> setDate(DateTime date) async {
    state = state.copyWith(date: date);
    if (state.teacher != null) {
      await init(state.teacher!.id);
    }
  }

  // -------------------------------------------------------
  // TOGGLE ATTENDANCE (Default Present -> 1st tap Absent -> 2nd tap Present -> repeating)
  // -------------------------------------------------------
  void toggleAttendance(String studentId) {
    final map = {...state.status};
    final current = map[studentId];
    if (current == false) {
      map[studentId] = true;
    } else {
      map[studentId] = false;
    }
    state = state.copyWith(status: map);
  }

  // -------------------------------------------------------
  // MARK PRESENT
  // -------------------------------------------------------
  void markPresent(String studentId) {
    final map = {...state.status};
    map[studentId] = true;
    state = state.copyWith(status: map);
  }

  // -------------------------------------------------------
  // MARK ABSENT
  // -------------------------------------------------------
  void markAbsent(String studentId) {
    final map = {...state.status};
    map[studentId] = false;
    state = state.copyWith(status: map);
  }

  // -------------------------------------------------------
  // MARK ALL PRESENT / ABSENT
  // -------------------------------------------------------
  void markAllPresent() {
    final map = <String, bool?>{};
    for (var s in state.students) {
      map[s.studentId] = true;
    }
    state = state.copyWith(status: map);
  }

  void markAllAbsent() {
    final map = <String, bool?>{};
    for (var s in state.students) {
      map[s.studentId] = false;
    }
    state = state.copyWith(status: map);
  }

  // -------------------------------------------------------
  // SAVE ATTENDANCE (OLD LOGIC EXACTLY USED)
  // -------------------------------------------------------
  Future<void> saveAttendance() async {
    if (state.teacher == null) return;

    final teacher = state.teacher!;
    final students = state.students;
    final isMorning = state.half == "Morning";
    log("Saving attendance for ${students.length} students");

    // build final list
    List<AttendanceModel> finalList = [];

    // load existing firebase attendance to check Morning/Evening combo
    final existing = await repo.fetchExistingAttendance(
      date: state.date,
      teacher: teacher,
    );

    for (final student in students) {
      final marked = state.status[student.studentId] ?? false;
      final existingModel = existing[student.studentId];

      String status;
      String presentDetail;

      if (isMorning) {
        if (marked) {
          if (existingModel != null &&
              existingModel.status.contains("Evening")) {
            status = "Morning & Evening";
            presentDetail = "Full Day";
          } else {
            status = "Morning Half";
            presentDetail = "Half Day";
          }
        } else {
          if (existingModel != null &&
              existingModel.status.contains("Evening")) {
            status = "Evening Half";
            presentDetail = "Half Day";
          } else {
            status = "Absent";
            presentDetail = "Absent";
          }
        }
      } else {
        if (marked) {
          if (existingModel != null &&
              existingModel.status.contains("Morning")) {
            status = "Morning & Evening";
            presentDetail = "Full Day";
          } else {
            status = "Evening Half";
            presentDetail = "Half Day";
          }
        } else {
          if (existingModel != null &&
              existingModel.status.contains("Morning")) {
            status = "Morning Half";
            presentDetail = "Half Day";
          } else {
            status = "Absent";
            presentDetail = "Absent";
          }
        }
      }

      finalList.add(
        AttendanceModel(
          studentId: student.studentId,
          division: student.division,
          classNo: student.classNo,
          rollNo: student.rollNo,
          studentName: student.studentName,
          status: status,
          presentDetail: presentDetail,
          teacherId: teacher.id,
          date: DateTime.now(),
          teacherName: teacher.teacherName
        ),
      );
    }

    await repo.saveAttendanceToFirestore(
      date: state.date,
      teacher: teacher,
      finalList: finalList,
    );
  }
}

// PROVIDER
final attendanceControllerProvider =
StateNotifierProvider<AttendanceController, AttendanceState>((ref) {
  final repo = ref.read(attendanceRepositoryProvider);
  return AttendanceController(repo);
});
