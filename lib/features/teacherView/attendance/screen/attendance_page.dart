import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/image_constant.dart';
import '../controller/attendance_controller.dart';

class AttendancePage extends ConsumerStatefulWidget {
  final String teacherId; // 🔥 coming from previous screen

  const AttendancePage({super.key, required this.teacherId});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  String _activeFilter = 'All'; // 'All', 'Present', 'Absent'
  String _searchQuery = '';
  bool _isSaving = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(attendanceControllerProvider.notifier).init(widget.teacherId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: state.loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff1193D4)),
              )
            : Column(
                children: [
                  // 🔹 Top Bar & Header Cards
                  _buildHeader(context, state),

                  // 🔹 Main Desktop Layout Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 950;
                          if (isDesktop) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Quick Mark Section
                                Expanded(
                                  flex: 5,
                                  child: _buildQuickMarkCard(state),
                                ),
                                const SizedBox(width: 24),
                                // Right Column: Detailed Mark Section
                                Expanded(
                                  flex: 7,
                                  child: _buildDetailedMarkCard(state),
                                ),
                              ],
                            );
                          } else {
                            // Single column layout for smaller widths
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  _buildQuickMarkCard(state),
                                  const SizedBox(height: 20),
                                  _buildDetailedMarkCard(state),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  // 🔹 Bottom Submit Bar
                  _buildSubmitBar(context, state),
                ],
              ),
      ),
    );
  }

  // --------------------------------------------------------
  // TOP HEADER & STAT CARDS
  // --------------------------------------------------------
  Widget _buildHeader(BuildContext context, AttendanceState state) {
    final totalCount = state.students.length;
    final absentCount = state.students.where((s) => state.status[s.studentId] == false).length;
    final presentCount = totalCount - absentCount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Back button & Title
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manage Attendance",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    "Mark daily student attendance & monitor status",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              // Quick action buttons: All Present / All Absent
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(attendanceControllerProvider.notifier).markAllPresent();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  side: const BorderSide(color: Color(0xFF10B981)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text("Mark All Present", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(attendanceControllerProvider.notifier).markAllAbsent();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text("Mark All Absent", style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 2: Top Stat & Info Cards (Teacher Card + Stats)
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 950;
              final teacherCard = _buildTeacherInfoCard(context, state);
              final totalCard = _buildStatCard(
                title: "TOTAL STUDENTS",
                value: "$totalCount",
                subtitle: "Active",
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
                icon: Icons.people_alt_rounded,
              );
              final presentCard = _buildStatCard(
                title: "PRESENT TODAY",
                value: "$presentCount",
                subtitle: "Marked",
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                icon: Icons.check_circle_rounded,
              );
              final absentCard = _buildStatCard(
                title: "ABSENT TODAY",
                value: "$absentCount",
                subtitle: "Marked",
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                icon: Icons.cancel_rounded,
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 8, child: teacherCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: totalCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: presentCard),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: absentCard),
                  ],
                );
              } else {
                return Column(
                  children: [
                    teacherCard,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: totalCard),
                        const SizedBox(width: 10),
                        Expanded(child: presentCard),
                        const SizedBox(width: 10),
                        Expanded(child: absentCard),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // 🔹 Teacher & Class Info Card
  Widget _buildTeacherInfoCard(BuildContext context, AttendanceState state) {
    final ctrl = ref.read(attendanceControllerProvider.notifier);
    final teacher = state.teacher;
    final teacherName = teacher?.teacherName ?? 'Teacher';
    final classNoStr = teacher != null
        ? (teacher.classNo == -2
            ? 'LKG'
            : (teacher.classNo == -1 ? 'UKG' : teacher.classNo.toString()))
        : '-';
    final classLabel = teacher != null ? "$classNoStr ${teacher.division}" : "-";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Teacher Icon Avatar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF0EA5E9), size: 22),
          ),
          const SizedBox(width: 10),

          // Teacher Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "TEACHER",
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  teacherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
          const SizedBox(width: 8),

          // Class / Date / Shift controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Class
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Class", maxLines: 1, softWrap: false, style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(
                    classLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    await ctrl.setDate(picked);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Date", maxLines: 1, softWrap: false, style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat("dd MMM").format(state.date),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Shift Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Shift", maxLines: 1, softWrap: false, style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  DropdownButton<String>(
                    value: state.half,
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                    items: const [
                      DropdownMenuItem(value: "Morning", child: Text("Morning")),
                      DropdownMenuItem(value: "Evening", child: Text("Evening")),
                    ],
                    onChanged: (v) => ctrl.setHalf(v!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔹 Stat Card Widget
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: color == const Color(0xFF3B82F6) ? const Color(0xFF0F172A) : color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color.withValues(alpha: 0.7), size: 24),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // LEFT CARD: QUICK MARK GRID
  // --------------------------------------------------------
  Widget _buildQuickMarkCard(AttendanceState state) {
    final students = [...state.students]..sort((a, b) => a.rollNo.compareTo(b.rollNo));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Quick Mark",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                students.isNotEmpty ? "Roll Nos 1-${students.length}" : "",
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap any circle to toggle status (Default: Present, 1st tap: Absent, 2nd tap: Present)",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          // Legend Indicator Bar
          Row(
            children: [
              _buildLegendPill("Present (Default)", const Color(0xFF10B981)),
              const SizedBox(width: 12),
              _buildLegendPill("Absent", const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),

          // Roll Numbers Grid
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text("No Students Found", style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: students.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 58,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final student = students[index];
                // Default status is Present (true) unless status[id] == false
                final isPresent = (state.status[student.studentId] ?? true) == true;

                return Tooltip(
                  message: "Roll ${student.rollNo}: ${student.studentName}\nStatus: ${isPresent ? 'Present' : 'Absent'} (Tap to toggle)",
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Toggle logic: Default Present -> 1st tap Absent -> 2nd tap Present -> repeating!
                        ref.read(attendanceControllerProvider.notifier).toggleAttendance(student.studentId);
                      },
                      borderRadius: BorderRadius.circular(26),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          boxShadow: [
                            BoxShadow(
                              color: (isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "${student.rollNo}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  // --------------------------------------------------------
  // RIGHT CARD: DETAILED MARK SECTION WITH FILTERS
  // --------------------------------------------------------
  Widget _buildDetailedMarkCard(AttendanceState state) {
    final students = [...state.students]..sort((a, b) => a.rollNo.compareTo(b.rollNo));

    final absentCount = students.where((s) => state.status[s.studentId] == false).length;
    final presentCount = students.length - absentCount;

    // Filter students by active filter & search query
    final filteredStudents = students.where((s) {
      final isPresent = (state.status[s.studentId] ?? true) == true;
      if (_activeFilter == 'Present' && !isPresent) return false;
      if (_activeFilter == 'Absent' && isPresent) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();
        final matchesName = s.studentName.toLowerCase().contains(query);
        final matchesRoll = s.rollNo.toString().contains(query);
        return matchesName || matchesRoll;
      }
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Filter Bar
          Row(
            children: [
              const Text(
                "Detailed Mark",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              // Filter Chips: All, Present, Absent
              _buildFilterChip('All', students.length),
              const SizedBox(width: 8),
              _buildFilterChip('Present', presentCount, activeColor: const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildFilterChip('Absent', absentCount, activeColor: const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: "Search student by name or roll number...",
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                borderSide: const BorderSide(color: Color(0xFF1193D4)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filtered Student Cards List
          if (filteredStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  "No students match selected filter",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                final isPresent = (state.status[student.studentId] ?? true) == true;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isPresent
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFFFCA5A5).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: student.imageUrl.isNotEmpty
                            ? NetworkImage(student.imageUrl)
                            : const AssetImage(ImageConstant.temporaryStudentImage) as ImageProvider,
                      ),
                      const SizedBox(width: 14),

                      // Name & Roll
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.studentName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Roll: ${student.rollNo < 10 ? '0' : ''}${student.rollNo}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons (Absent X & Present Check)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ABSENT BUTTON (X)
                          InkWell(
                            onTap: () {
                              ref.read(attendanceControllerProvider.notifier).markAbsent(student.studentId);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPresent
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !isPresent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: !isPresent ? Colors.white : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // PRESENT BUTTON (✓)
                          InkWell(
                            onTap: () {
                              ref.read(attendanceControllerProvider.notifier).markPresent(student.studentId);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: isPresent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: isPresent ? Colors.white : const Color(0xFF10B981),
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
        ],
      ),
    );
  }

  // 🔹 Filter Chip Helper
  Widget _buildFilterChip(String label, int count, {Color? activeColor}) {
    final isSelected = _activeFilter == label;
    final primaryColor = activeColor ?? const Color(0xFF1193D4);

    return InkWell(
      onTap: () => setState(() => _activeFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // BOTTOM SUBMIT BAR
  // --------------------------------------------------------
  Widget _buildSubmitBar(BuildContext context, AttendanceState state) {
    final ctrl = ref.read(attendanceControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      try {
                        await ctrl.saveAttendance();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Attendance Saved Successfully!"),
                              backgroundColor: Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to save attendance: $e"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1193D4),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xff1193D4).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.how_to_reg_rounded, size: 22, color: Colors.white),
              label: Text(
                _isSaving ? "SAVING..." : "SUBMIT ATTENDANCE",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
