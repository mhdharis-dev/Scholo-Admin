import 'package:flutter/material.dart';
import '../../../models/timeTable_model.dart';
import '../../../models/dayShedule_model.dart';
import '../../../models/period_model.dart';

class AnalyzedTeacherInfo {
  final String id;
  final String name;
  final String subjectCode; // e.g. "ENGLISH - 1" or "MALAYALAM"
  final String subjectName; // e.g. "English" or "Language"
  final Color badgeColor;
  final bool isLanguageTeacher;
  final String employeeId;
  final String mobileNo;
  final bool isFromFirestore;

  const AnalyzedTeacherInfo({
    required this.id,
    required this.name,
    required this.subjectCode,
    required this.subjectName,
    required this.badgeColor,
    this.isLanguageTeacher = false,
    this.employeeId = '',
    this.mobileNo = '',
    this.isFromFirestore = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'subject': subjectCode,
    'color': badgeColor.toARGB32(),
    'isLanguageTeacher': isLanguageTeacher,
  };
}

class AnalyzedPeriodSlot {
  int periodNumber; // 1 to 7, or 0 for breaks
  String periodName; // 'Period 1', 'Interval', 'Lunch Break', 'PT'
  String type; // 'period', 'break', 'pt', 'lab'
  String startTime;
  String endTime;
  String? mainSubject; // e.g. "Second Language" when multiple teachers or "Mathematics"
  String? subject; // e.g. "MAL / ARB / HIN" or single subject
  String? teacherName;
  String? teacherId;
  Color color;
  List<AnalyzedTeacherInfo> assignedTeachers;

  AnalyzedPeriodSlot({
    required this.periodNumber,
    required this.periodName,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.mainSubject,
    this.subject,
    this.teacherName,
    this.teacherId,
    required this.color,
    List<AnalyzedTeacherInfo>? assignedTeachers,
  }) : assignedTeachers = assignedTeachers ?? [];

  bool get isBreak => type == 'break';

  AnalyzedPeriodSlot copyWith({
    int? periodNumber,
    String? periodName,
    String? type,
    String? startTime,
    String? endTime,
    String? mainSubject,
    String? subject,
    String? teacherName,
    String? teacherId,
    Color? color,
    List<AnalyzedTeacherInfo>? assignedTeachers,
  }) {
    return AnalyzedPeriodSlot(
      periodNumber: periodNumber ?? this.periodNumber,
      periodName: periodName ?? this.periodName,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mainSubject: mainSubject ?? this.mainSubject,
      subject: subject ?? this.subject,
      teacherName: teacherName ?? this.teacherName,
      teacherId: teacherId ?? this.teacherId,
      color: color ?? this.color,
      assignedTeachers: assignedTeachers ?? List.from(this.assignedTeachers),
    );
  }

  PeriodSlotModel toPeriodSlotModel() {
    final effectiveTeacherName = assignedTeachers.isNotEmpty
        ? assignedTeachers.map((t) => t.name).join(', ')
        : (teacherName ?? '');
    final effectiveTeacherId = assignedTeachers.isNotEmpty
        ? assignedTeachers.map((t) => t.id).join(', ')
        : (teacherId ?? '');
    final effectiveSubject = assignedTeachers.isNotEmpty
        ? assignedTeachers.map((t) => t.subjectCode).join(' / ')
        : (subject ?? '');
    final effectiveMainSubject = (mainSubject != null && mainSubject!.isNotEmpty)
        ? mainSubject
        : (assignedTeachers.length > 1 ? "Second Language" : effectiveSubject);

    return PeriodSlotModel(
      periodName: periodName,
      type: type == 'break' ? 'break' : 'period',
      startTime: startTime,
      endTime: endTime,
      mainSubject: effectiveMainSubject,
      subject: effectiveSubject,
      teacherName: effectiveTeacherName,
      teacherId: effectiveTeacherId,
      colorValue: color.toARGB32(),
    );
  }
}

class AnalyzedClassTimetable {
  String id;
  String className; // e.g. "Biology Science - A1"
  String classNo; // e.g. "11" or "1"
  String division; // e.g. "A1" or "A"
  String stream; // 'Science', 'Commerce', 'Humanities', 'Computer Science'
  String classTeacherName;
  String classTeacherId;
  Map<String, List<AnalyzedPeriodSlot>> schedule; // 'Monday': [...slots]

  AnalyzedClassTimetable({
    required this.id,
    required this.className,
    required this.classNo,
    required this.division,
    required this.stream,
    this.classTeacherName = '',
    this.classTeacherId = '',
    required this.schedule,
  });

  TimetableModel toFirestoreTimetableModel({String schoolId = ''}) {
    final Map<String, DayScheduleModel> workingDays = {};

    schedule.forEach((day, slots) {
      final periodModels = slots.map((s) => s.toPeriodSlotModel()).toList();
      workingDays[day] = DayScheduleModel(
        status: slots.isNotEmpty ? 'Working Day' : 'Non-Working Day',
        totalPeriods: slots.where((s) => s.type == 'period' || s.type == 'pt' || s.type == 'lab').length,
        periods: periodModels,
      );
    });

    final totalPeriodsCount = workingDays.values.fold<int>(
      0,
      (max, d) => d.totalPeriods > max ? d.totalPeriods : max,
    );

    return TimetableModel(
      timetableName: "$className Schedule",
      classTeacherId: classTeacherId,
      classTeacherName: classTeacherName,
      classNo: classNo,
      division: division,
      totalPeriods: totalPeriodsCount > 0 ? totalPeriodsCount : 7,
      totalWorkingDays: workingDays.values.where((d) => d.status == 'Working Day').length,
      createdDate: DateTime.now(),
      delete: false,
      workingDays: workingDays,
      schoolId: schoolId,
    );
  }
}

class MasterTimetableParser {
  // Color palette for subjects
  static const Color chemistryColor = Color(0xFFF97316); // Orange
  static const Color physicsColor = Color(0xFF0284C7); // Sky Blue
  static const Color mathsColor = Color(0xFF7C3AED); // Purple
  static const Color biologyColor = Color(0xFF10B981); // Emerald Green
  static const Color englishColor = Color(0xFF2563EB); // Royal Blue
  static const Color secondLangColor = Color(0xFF64748B); // Slate
  static const Color economicsColor = Color(0xFFD97706); // Amber
  static const Color accountancyColor = Color(0xFF059669); // Dark Green
  static const Color businessColor = Color(0xFF4F46E5); // Indigo
  static const Color csColor = Color(0xFF0D9488); // Teal
  static const Color humanitiesColor = Color(0xFF9333EA); // Violet
  static const Color ptColor = Color(0xFFDC2626); // Red
  static const Color breakColor = Color(0xFFFDE68A); // Light Yellow

  static List<AnalyzedTeacherInfo> getKnownTeachers() {
    return const [
      AnalyzedTeacherInfo(id: 't_eng1', name: 'HARISA C P', subjectCode: 'ENGLISH - 1', subjectName: 'English', badgeColor: englishColor),
      AnalyzedTeacherInfo(id: 't_eng2', name: 'MUHAMMED SHAMEER P', subjectCode: 'ENGLISH - 2', subjectName: 'English', badgeColor: englishColor),
      AnalyzedTeacherInfo(id: 't_eng3', name: 'RAMAKRISHNAN', subjectCode: 'ENGLISH - 3', subjectName: 'English', badgeColor: englishColor),
      AnalyzedTeacherInfo(id: 't_eng4', name: 'NIZMA', subjectCode: 'ENGLISH - 4', subjectName: 'English', badgeColor: englishColor),
      AnalyzedTeacherInfo(id: 't_che1', name: 'ZAIBUNISA K', subjectCode: 'CHEMISTRY - 1', subjectName: 'Chemistry', badgeColor: chemistryColor),
      AnalyzedTeacherInfo(id: 't_che2', name: 'KALA NK', subjectCode: 'CHEMISTRY - 2', subjectName: 'Chemistry', badgeColor: chemistryColor),
      AnalyzedTeacherInfo(id: 't_che3', name: 'ABDUL KADER C', subjectCode: 'CHEMISTRY - 3', subjectName: 'Chemistry', badgeColor: chemistryColor),
      AnalyzedTeacherInfo(id: 't_phy1', name: 'ANIL KUMAR KS', subjectCode: 'PHYSICS - 1', subjectName: 'Physics', badgeColor: physicsColor),
      AnalyzedTeacherInfo(id: 't_phy2', name: 'ILLIAS V', subjectCode: 'PHYSICS - 2', subjectName: 'Physics', badgeColor: physicsColor),
      AnalyzedTeacherInfo(id: 't_phy3', name: 'SHAHANAS AP', subjectCode: 'PHYSICS - 3', subjectName: 'Physics', badgeColor: physicsColor),
      AnalyzedTeacherInfo(id: 't_mat1', name: 'MOHAMMED ASHRAF VP', subjectCode: 'MATHS - 1', subjectName: 'Maths', badgeColor: mathsColor),
      AnalyzedTeacherInfo(id: 't_mat2', name: 'SHEMSUDEEN VK', subjectCode: 'MATHS - 2', subjectName: 'Maths', badgeColor: mathsColor),
      AnalyzedTeacherInfo(id: 't_mat3', name: 'MUHSINA', subjectCode: 'MATHS - 3', subjectName: 'Maths', badgeColor: mathsColor),
      AnalyzedTeacherInfo(id: 't_eco1', name: 'ABDUL NAZAR M', subjectCode: 'ECONOMICS - 1', subjectName: 'Economics', badgeColor: economicsColor),
      AnalyzedTeacherInfo(id: 't_eco2', name: 'SATHAR PT', subjectCode: 'ECONOMICS - 2', subjectName: 'Economics', badgeColor: economicsColor),
      AnalyzedTeacherInfo(id: 't_cs1', name: 'JINI', subjectCode: 'COMPUTER SCIENCE', subjectName: 'Computer Science', badgeColor: csColor),
      AnalyzedTeacherInfo(id: 't_cs2', name: 'MUNEERA', subjectCode: 'COMPUTER / COMMERCE', subjectName: 'Computer Science', badgeColor: csColor),
    ];
  }

  static String lookupTeacher(String? subject) {
    if (subject == null || subject.isEmpty) return '';
    final s = subject.toUpperCase().trim().replaceAll(' ', '');
    for (var t in getKnownTeachers()) {
      final code = t.subjectCode.toUpperCase().replaceAll(' ', '');
      if (s.contains(code) || code.contains(s)) {
        return t.name;
      }
    }
    if (s.contains('JINI')) return 'JINI';
    if (s.contains('MUNEERA')) return 'MUNEERA';
    return '';
  }

  static Color getSubjectColor(String? subject) {
    if (subject == null) return const Color(0xFF64748B);
    final s = subject.toUpperCase();
    if (s.contains('PT')) return ptColor;
    if (s.contains('CHEM')) return chemistryColor;
    if (s.contains('PHY')) return physicsColor;
    if (s.contains('MATH')) return mathsColor;
    if (s.contains('BOTANY') || s.contains('ZOO') || s.contains('BIO')) return biologyColor;
    if (s.contains('ENG')) return englishColor;
    if (s.contains('SECOND')) return secondLangColor;
    if (s.contains('ECO')) return economicsColor;
    if (s.contains('ACC')) return accountancyColor;
    if (s.contains('BUS')) return businessColor;
    if (s.contains('JINI') || s.contains('MUNEERA') || s.contains('COMP')) return csColor;
    if (s.contains('POL') || s.contains('HIST') || s.contains('SOC')) return humanitiesColor;
    return const Color(0xFF2563EB);
  }

  static bool isLanguageSubject(String? subject) {
    if (subject == null) return false;
    final s = subject.toLowerCase();
    return s.contains('lang') ||
        s.contains('arabic') ||
        s.contains('malayalam') ||
        s.contains('hindi') ||
        s.contains('sanskrit') ||
        s.contains('urdu') ||
        s.contains('english') ||
        s.contains('french') ||
        s.contains('second') ||
        s.contains('tamil');
  }

  static AnalyzedTeacherInfo? findKnownTeacher(String name) {
    if (name.isEmpty) return null;
    for (var t in getKnownTeachers()) {
      if (t.name.toUpperCase() == name.toUpperCase()) return t;
    }
    return null;
  }

  static AnalyzedPeriodSlot _buildSlotHelper({
    required int periodNumber,
    required String periodName,
    required String type,
    required String startTime,
    required String endTime,
    required String subject,
  }) {
    if (type == 'break') {
      return AnalyzedPeriodSlot(
        periodNumber: 0,
        periodName: periodName,
        type: 'break',
        startTime: startTime,
        endTime: endTime,
        subject: subject,
        color: breakColor,
      );
    }

    final isLang = isLanguageSubject(subject);
    final teacherName = lookupTeacher(subject);
    final teacher = findKnownTeacher(teacherName);
    final color = getSubjectColor(subject);

    final List<AnalyzedTeacherInfo> teachers = [];
    if (teacher != null) {
      teachers.add(teacher);
    } else if (teacherName.isNotEmpty) {
      teachers.add(AnalyzedTeacherInfo(
        id: 't_${teacherName.replaceAll(' ', '_')}',
        name: teacherName,
        subjectCode: subject,
        subjectName: subject,
        badgeColor: color,
        isLanguageTeacher: isLang,
      ));
    }

    return AnalyzedPeriodSlot(
      periodNumber: periodNumber,
      periodName: periodName,
      type: type,
      startTime: startTime,
      endTime: endTime,
      mainSubject: isLang ? 'Second Language' : subject,
      subject: subject,
      teacherName: teacherName.isNotEmpty ? teacherName : null,
      teacherId: teacher?.id,
      color: color,
      assignedTeachers: teachers,
    );
  }

  static List<AnalyzedPeriodSlot> _createSlots(
    List<String> periodSubjects, // exactly 7 subjects for periods 1 through 7
  ) {
    // 7 periods + 3 breaks (Interval after P2, Lunch Break after P4, Interval after P6)
    return [
      // Period 1
      _buildSlotHelper(
        periodNumber: 1,
        periodName: 'Period 1',
        type: 'period',
        startTime: '09:00 AM',
        endTime: '09:45 AM',
        subject: periodSubjects[0],
      ),
      // Period 2
      _buildSlotHelper(
        periodNumber: 2,
        periodName: 'Period 2',
        type: 'period',
        startTime: '09:45 AM',
        endTime: '10:30 AM',
        subject: periodSubjects[1],
      ),
      // Morning Interval
      _buildSlotHelper(
        periodNumber: 0,
        periodName: 'Interval',
        type: 'break',
        startTime: '10:30 AM',
        endTime: '10:45 AM',
        subject: 'Interval',
      ),
      // Period 3
      _buildSlotHelper(
        periodNumber: 3,
        periodName: 'Period 3',
        type: 'period',
        startTime: '10:45 AM',
        endTime: '11:30 AM',
        subject: periodSubjects[2],
      ),
      // Period 4
      _buildSlotHelper(
        periodNumber: 4,
        periodName: 'Period 4',
        type: 'period',
        startTime: '11:30 AM',
        endTime: '12:15 PM',
        subject: periodSubjects[3],
      ),
      // Lunch Break
      _buildSlotHelper(
        periodNumber: 0,
        periodName: 'Lunch Break',
        type: 'break',
        startTime: '12:15 PM',
        endTime: '01:00 PM',
        subject: 'Lunch Break',
      ),
      // Period 5
      _buildSlotHelper(
        periodNumber: 5,
        periodName: 'Period 5',
        type: periodSubjects[4].toUpperCase().contains('PRACTICAL') ? 'lab' : 'period',
        startTime: '01:00 PM',
        endTime: '01:45 PM',
        subject: periodSubjects[4],
      ),
      // Period 6
      _buildSlotHelper(
        periodNumber: 6,
        periodName: 'Period 6',
        type: periodSubjects[5].toUpperCase().contains('PRACTICAL') ? 'lab' : 'period',
        startTime: '01:45 PM',
        endTime: '02:30 PM',
        subject: periodSubjects[5],
      ),
      // Afternoon Interval
      _buildSlotHelper(
        periodNumber: 0,
        periodName: 'Interval',
        type: 'break',
        startTime: '02:30 PM',
        endTime: '02:40 PM',
        subject: 'Interval',
      ),
      // Period 7
      _buildSlotHelper(
        periodNumber: 7,
        periodName: 'Period 7',
        type: periodSubjects[6].toUpperCase().contains('PT') ? 'pt' : 'period',
        startTime: '02:40 PM',
        endTime: '03:20 PM',
        subject: periodSubjects[6],
      ),
    ];
  }

  /// Builds all 13 class timetables parsed directly from the institutional master timetable document!
  static List<AnalyzedClassTimetable> parseMasterTimetable() {
    return [
      // 1. BIOLOGY SCIENCE - A1
      AnalyzedClassTimetable(
        id: 'bio_a1',
        className: 'Biology Science - A1',
        classNo: '11',
        division: 'A1',
        stream: 'Science',
        classTeacherName: 'ZAIBUNISA K',
        schedule: {
          'Monday': _createSlots(['CHEMISTRY-1', 'SECOND LANG', 'PHYSICS-1', 'BOTANY', 'ENGLISH-1', 'MATHS-1', 'ZOOLOGY']),
          'Tuesday': _createSlots(['ZOOLOGY', 'ENGLISH- 2', 'CHEMISTRY-2', 'SECOND LANG', 'MATHS-2', 'ENGLISH-1', 'PHYSICS-2']),
          'Wednesday': _createSlots(['PHYSICS-2', 'MATHS-1', 'CHEMISTRY-1', 'BOTANY', 'ENGLISH- 2', 'CHEMISTRY-2', 'SECOND LANG']),
          'Thursday': _createSlots(['ZOOLOGY', 'CHEMISTRY-1', 'MATHS-2', 'PHYSICS-2', 'SECOND LANG', 'ENGLISH- 2', 'PHYSICS-1']),
          'Friday': _createSlots(['MATHS-2', 'BOTANY', 'PHYSICS-1', 'ENGLISH-1', 'CHEMISTRY-2', 'MATHS-1', 'PT']),
        },
      ),

      // 2. BIOLOGY SCIENCE - A2
      AnalyzedClassTimetable(
        id: 'bio_a2',
        className: 'Biology Science - A2',
        classNo: '11',
        division: 'A2',
        stream: 'Science',
        classTeacherName: 'MUHAMMED SHAMEER P',
        schedule: {
          'Monday': _createSlots(['ENGLISH- 2', 'PHYSICS-1', 'CHEMISTRY-2', 'SECOND LANG', 'PRACTICAL BOTANY/ZOO', 'PRACTICAL BOTANY/ZOO', 'CHEMISTRY-1']),
          'Tuesday': _createSlots(['SECOND LANG', 'CHEMISTRY-2', 'PHYSICS-1', 'ENGLISH-1', 'PRACTICAL PHY-1/CHE-1', 'MATHS-2', 'MATHS-1']),
          'Wednesday': _createSlots(['CHEMISTRY-1', 'ZOOLOGY', 'MATHS-1', 'SECOND LANG', 'PRACTICAL MATHS-2', 'PHYSICS-2', 'BOTANY']),
          'Thursday': _createSlots(['MATHS-2', 'BOTANY', 'ENGLISH-1', 'PHYSICS-1', 'PRACTICAL CHE-2/PHY-2', 'SECOND LANG', 'PT']),
          'Friday': _createSlots(['MATHS-1', 'PHYSICS-2', 'ZOOLOGY', 'CHEMISTRY-2', 'ENGLISH- 2', 'SECOND LANG', 'ENGLISH-1']),
        },
      ),

      // 3. BIOLOGY SCIENCE - B1
      AnalyzedClassTimetable(
        id: 'bio_b1',
        className: 'Biology Science - B1',
        classNo: '11',
        division: 'B1',
        stream: 'Science',
        classTeacherName: 'ANIL KUMAR KS',
        schedule: {
          'Monday': _createSlots(['PHYSICS- 3', 'SECOND LANG', 'MATHS-3', 'ENGLISH- 3', 'ENGLISH- 2', 'CHEMISTRY- 3', 'PHYSICS-1']),
          'Tuesday': _createSlots(['MATHS-1', 'ZOOLOGY', 'CHEMISTRY- 3', 'SECOND LANG', 'PHYSICS- 3', 'MATHS-3', 'ENGLISH- 2']),
          'Wednesday': _createSlots(['PHYSICS-1', 'BOTANY', 'ENGLISH- 2', 'CHEMISTRY-1', 'CHEMISTRY- 3', 'MATHS-1', 'SECOND LANG']),
          'Thursday': _createSlots(['ENGLISH- 2', 'MATHS-3', 'BOTANY', 'CHEMISTRY-1', 'SECOND LANG', 'ZOOLOGY', 'PHYSICS- 3']),
          'Friday': _createSlots(['CHEMISTRY-1', 'ZOOLOGY', 'MATHS-1', 'PHYSICS-1', 'ENGLISH- 3', 'BOTANY', 'PT']),
        },
      ),

      // 4. BIOLOGY SCIENCE - B2
      AnalyzedClassTimetable(
        id: 'bio_b2',
        className: 'Biology Science - B2',
        classNo: '11',
        division: 'B2',
        stream: 'Science',
        classTeacherName: 'ABDUL KADER C',
        schedule: {
          'Monday': _createSlots(['BOTANY', 'ENGLISH- 3', 'CHEMISTRY- 3', 'SECOND LANG', 'PRACTICAL CHE-3/PHY-3', 'ENGLISH- 2', 'MATHS-3']),
          'Tuesday': _createSlots(['SECOND LANG', 'CHEMISTRY-1', 'MATHS-1', 'PHYSICS-1', 'PRACTICAL ZOO/BOT', 'PRACTICAL ZOO/BOT', 'ZOOLOGY']),
          'Wednesday': _createSlots(['MATHS-1', 'ENGLISH- 2', 'MATHS-3', 'SECOND LANG', 'PHYSICS-1', 'PRACTICAL PHY-1/CHE-1', 'ENGLISH- 3']),
          'Thursday': _createSlots(['PHYSICS- 3', 'ZOOLOGY', 'CHEMISTRY-1', 'ENGLISH- 2', 'MATHS LAB M1/M3', 'SECOND LANG', 'PT']),
          'Friday': _createSlots(['PHYSICS-1', 'CHEMISTRY-1', 'PHYSICS- 3', 'MATHS-1', 'BOTANY', 'SECOND LANG', 'CHEMISTRY- 3']),
        },
      ),

      // 5. BIOLOGY SCIENCE - C1
      AnalyzedClassTimetable(
        id: 'bio_c1',
        className: 'Biology Science - C1',
        classNo: '11',
        division: 'C1',
        stream: 'Science',
        classTeacherName: 'MOHAMMED ASHRAF VP',
        schedule: {
          'Monday': _createSlots(['ZOOLOGY', 'SECOND LANG', 'MATHS-1', 'CHEMISTRY-1', 'PHYSICS-2', 'ENGLISH- 4', 'MATHS-2']),
          'Tuesday': _createSlots(['BOTANY', 'PHYSICS-1', 'CHEMISTRY-1', 'SECOND LANG', 'MATHS-1', 'ENGLISH- 3', 'CHEMISTRY-2']),
          'Wednesday': _createSlots(['CHEMISTRY-2', 'PHYSICS-1', 'ENGLISH- 4', 'ZOOLOGY', 'ENGLISH- 3', 'MATHS-2', 'SECOND LANG']),
          'Thursday': _createSlots(['PHYSICS-2', 'CHEMISTRY-2', 'ENGLISH- 3', 'MATHS-1', 'SECOND LANG', 'PHYSICS-1', 'BOTANY']),
          'Friday': _createSlots(['PHYSICS-2', 'MATHS-2', 'ENGLISH- 3', 'BOTANY', 'ZOOLOGY', 'CHEMISTRY-1', 'PT']),
        },
      ),

      // 6. BIOLOGY SCIENCE - C2
      AnalyzedClassTimetable(
        id: 'bio_c2',
        className: 'Biology Science - C2',
        classNo: '11',
        division: 'C2',
        stream: 'Science',
        classTeacherName: 'ILLIAS V',
        schedule: {
          'Monday': _createSlots(['CHEMISTRY-2', 'PHYSICS-2', 'ZOOLOGY', 'SECOND LANG', 'MATHS-1', 'PRACTICAL CHE-1/PHY-1', 'ENGLISH- 3']),
          'Tuesday': _createSlots(['SECOND LANG', 'MATHS-2', 'PHYSICS-2', 'BOTANY', 'ENGLISH- 3', 'PRACTICAL PHY-2/CHE-2', 'CHEMISTRY-1']),
          'Wednesday': _createSlots(['MATHS-2', 'CHEMISTRY-2', 'PHYSICS-2', 'SECOND LANG', 'PRACTICAL ZOO/BOT', 'PRACTICAL ZOO/BOT', 'ENGLISH- 4']),
          'Thursday': _createSlots(['PHYSICS-1', 'MATHS LAB M-1/M-2', 'ZOOLOGY', 'ENGLISH- 3', 'CHEMISTRY-1', 'SECOND LANG', 'PT']),
          'Friday': _createSlots(['BOTANY', 'ENGLISH- 3', 'MATHS-2', 'CHEMISTRY-1', 'PHYSICS-1', 'SECOND LANG', 'MATHS-1']),
        },
      ),

      // 7. COMPUTER SCIENCE (CS1)
      AnalyzedClassTimetable(
        id: 'cs_1',
        className: 'Computer Science (CS1)',
        classNo: '11',
        division: 'CS1',
        stream: 'Computer Science',
        classTeacherName: 'JINI',
        schedule: {
          'Monday': _createSlots(['MATHS-3', 'JINI', 'PHYSICS-2', 'CHEMISTRY- 3', 'ENGLISH-4', 'CHEMISTRY-2', 'JINI']),
          'Tuesday': _createSlots(['ENGLISH-1', 'PHYSICS-2', 'PHYSICS- 3', 'MATHS-2', 'MUNEERA', 'CHEMISTRY- 3', 'SECOND LANG']),
          'Wednesday': _createSlots(['MUNEERA', 'PHYSICS- 3', 'CHEMISTRY-2', 'ENGLISH-4', 'SECOND LANG', 'MATHS-3', 'ENGLISH-1']),
          'Thursday': _createSlots(['SECOND LANG', 'PHYSICS-2', 'JINI', 'CHEMISTRY- 3', 'ENGLISH-1', 'MUNEERA', 'MATHS-2']),
          'Friday': _createSlots(['ENGLISH-4', 'SECOND LANG', 'CHEMISTRY-2', 'MATHS-3', 'PHYSICS- 3', 'MATHS-2', 'PT']),
        },
      ),

      // 8. COMPUTER SCIENCE (CS2)
      AnalyzedClassTimetable(
        id: 'cs_2',
        className: 'Computer Science (CS2)',
        classNo: '11',
        division: 'CS2',
        stream: 'Computer Science',
        classTeacherName: 'MUNEERA',
        schedule: {
          'Monday': _createSlots(['MUNEERA', 'MATHS-2', 'ENGLISH-1', 'PHYSICS-2', 'MATH LAB M3/M2', 'SECOND LANG', 'CHEMISTRY-2']),
          'Tuesday': _createSlots(['PHYSICS-2', 'MATHS-3', 'ENGLISH-1', 'JINI', 'SECOND LANG', 'COMP LAB JNM/MKT', 'ENGLISH-4']),
          'Wednesday': _createSlots(['CHEMISTRY- 3', 'SECOND LANG', 'MATHS-2', 'ENGLISH-1', 'PHY LAB P2/C2', 'PHYSICS- 3', 'MUNEERA']),
          'Thursday': _createSlots(['CHEMISTRY-2', 'MUNEERA', 'SECOND LANG', 'ENGLISH-4', 'MATHS-2', 'LAB P3/C3', 'PT']),
          'Friday': _createSlots(['PHYSICS- 3', 'CHEMISTRY-2', 'SECOND LANG', 'CHEMISTRY- 3', 'JINI', 'MATHS-3', 'PHYSICS-2']),
        },
      ),

      // 9. COMMERCE (E1)
      AnalyzedClassTimetable(
        id: 'comm_e1',
        className: 'Commerce (E1)',
        classNo: '11',
        division: 'E1',
        stream: 'Commerce',
        classTeacherName: 'ABDUL NAZAR M',
        schedule: {
          'Monday': _createSlots(['ECONOMICS -1', 'ACCOUNTANCY', 'ENGLISH-4', 'BUSINESS STUDIES', 'JINI', 'ACCOUNTANCY', 'MUNEERA']),
          'Tuesday': _createSlots(['ECONOMICS -2', 'ENGLISH-4', 'BUSINESS STUDIES', 'ENGLISH- 2', 'ECONOMICS -1', 'ACCOUNTANCY', 'SECOND LANG']),
          'Wednesday': _createSlots(['ECONOMICS -1', 'ACCOUNTANCY', 'MUNEERA', 'ECONOMICS -2', 'SECOND LANG', 'BUSINESS STUDIES', 'ENGLISH- 2']),
          'Thursday': _createSlots(['SECOND LANG', 'BUSINESS STUDIES', 'ENGLISH- 2', 'MUNEERA', 'ACCOUNTANCY', 'JINI', 'ECONOMICS -2']),
          'Friday': _createSlots(['BUSINESS STUDIES', 'SECOND LANG', 'MUNEERA', 'ENGLISH- 2', 'BUSINESS STUDIES', 'ACCOUNTANCY', 'PT']),
        },
      ),

      // 10. COMMERCE (E2)
      AnalyzedClassTimetable(
        id: 'comm_e2',
        className: 'Commerce (E2)',
        classNo: '11',
        division: 'E2',
        stream: 'Commerce',
        classTeacherName: 'SATHAR PT',
        schedule: {
          'Monday': _createSlots(['ACCOUNTANCY', 'BUSINESS STUDIES', 'MUNEERA', 'ENGLISH- 2', 'ECONOMICS -2', 'SECOND LANG', 'ECONOMICS -1']),
          'Tuesday': _createSlots(['BUSINESS STUDIES', 'MUNEERA', 'ECONOMICS -1', 'ACCOUNTANCY', 'SECOND LANG', 'ENGLISH- 2', 'BUSINESS STUDIES']),
          'Wednesday': _createSlots(['JINI', 'SECOND LANG', 'BUSINESS STUDIES', 'ACCOUNTANCY', 'ECONOMICS -1', 'COMP LAB MKT/JNM', 'BS (NCT)']),
          'Thursday': _createSlots(['ECONOMICS -2', 'ACCOUNTANCY', 'SECOND LANG', 'ECONOMICS -1', 'ENGLISH-4', 'LAB ACC NCT/UHB', 'PT']),
          'Friday': _createSlots(['ACCOUNTANCY', 'ENGLISH- 2', 'SECOND LANG', 'JINI', 'ENGLISH-4', 'MUNEERA', 'BS(NCT)']),
        },
      ),

      // 11. HUMANITIES (H1 A)
      AnalyzedClassTimetable(
        id: 'hum_h1a',
        className: 'Humanities (H1 A)',
        classNo: '11',
        division: 'H1A',
        stream: 'Humanities',
        classTeacherName: 'RAMAKRISHNAN',
        schedule: {
          'Monday': _createSlots(['ENGLISH-1', 'ECONOMICS -2', 'POLITICS', 'HISTORY', 'SOCIOLOGY', 'ENGLISH-1', 'HISTORY']),
          'Tuesday': _createSlots(['SOCIOLOGY', 'POLITICS', 'ENGLISH- 3', 'HISTORY', 'SOCIOLOGY', 'ECONOMICS -2', 'SECOND LANG']),
          'Wednesday': _createSlots(['SOCIOLOGY', 'ENGLISH-1', 'POLITICS', 'POLITICS', 'SECOND LANG', 'HISTORY', 'ECONOMICS -1']),
          'Thursday': _createSlots(['SECOND LANG', 'POLITICS', 'HISTORY', 'SOCIOLOGY', 'ECONOMICS -1', 'ENGLISH-1', 'ENGLISH- 3']),
          'Friday': _createSlots(['HISTORY', 'SECOND LANG', 'POLITICS', 'SOCIOLOGY', 'ECONOMICS -2', 'ECONOMICS -1', 'PT']),
        },
      ),

      // 12. HUMANITIES (H1 B)
      AnalyzedClassTimetable(
        id: 'hum_h1b',
        className: 'Humanities (H1 B)',
        classNo: '11',
        division: 'H1B',
        stream: 'Humanities',
        classTeacherName: 'NIZMA',
        schedule: {
          'Monday': _createSlots(['POLITICS', 'ENGLISH- 4', 'ECONOMICS -1', 'POLITICS', 'HISTORY', 'SOCIOLOGY', 'ENGLISH- 4']),
          'Tuesday': _createSlots(['POLITICS', 'ECONOMICS -2', 'ENGLISH- 4', 'SOCIOLOGY', 'HISTORY', 'ECONOMICS -1', 'SECOND LANG']),
          'Wednesday': _createSlots(['POLITICS', 'ECONOMICS -2', 'HISTORY', 'SOCIOLOGY', 'SECOND LANG', 'ENGLISH- 4', 'SOCIOLOGY']),
          'Thursday': _createSlots(['SECOND LANG', 'HISTORY', 'ENGLISH- 4', 'POLITICS', 'SOCIOLOGY', 'ECONOMICS -2', 'HISTORY']),
          'Friday': _createSlots(['POLITICS', 'SECOND LANG', 'ENGLISH- 4', 'ECONOMICS -1', 'SOCIOLOGY', 'HISTORY', 'PT']),
        },
      ),

      // 13. HUMANITIES (D2)
      AnalyzedClassTimetable(
        id: 'hum_d2',
        className: 'Humanities (D2)',
        classNo: '12',
        division: 'D2',
        stream: 'Humanities',
        classTeacherName: 'HARISA C P',
        schedule: {
          'Monday': _createSlots(['SOCIOLOGY', 'POLITICS', 'HISTORY', 'ECONOMICS -1', 'ENGLISH- 3', 'SECOND LANG', 'SOCIOLOGY']),
          'Tuesday': _createSlots(['ECONOMICS -1', 'HISTORY', 'SOCIOLOGY', 'POLITICS', 'SECOND LANG', 'HISTORY', 'ENGLISH-1']),
          'Wednesday': _createSlots(['HISTORY', 'SECOND LANG', 'ECONOMICS -2', 'ENGLISH- 3', 'POLITICS', 'SOCIOLOGY', 'POLITICS']),
          'Thursday': _createSlots(['POLITICS', 'SOCIOLOGY', 'SECOND LANG', 'ENGLISH-1', 'HISTORY', 'ECONOMICS -1', 'PT']),
          'Friday': _createSlots(['ECONOMICS -1', 'SOCIOLOGY', 'SECOND LANG', 'POLITICS', 'ENGLISH-1', 'ECONOMICS -2', 'HISTORY']),
        },
      ),
    ];
  }
}
