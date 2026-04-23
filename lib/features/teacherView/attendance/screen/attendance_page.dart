import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../controller/attendance_controller.dart';

class AttendancePage extends ConsumerStatefulWidget {
  final String teacherId; // 🔥 coming from previous screen

  const AttendancePage({super.key, required this.teacherId});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  @override
  void initState() {
    super.initState();
    // Load everything
    Future.delayed(Duration.zero, () {
      ref.read(attendanceControllerProvider.notifier).init(widget.teacherId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopCard(context, state),
              const SizedBox(height: 30),
              _headerRow(),
              const SizedBox(height: 12),
              Expanded(child: _studentList(state)),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // TOP CARD (HALF + DATE + SAVE BUTTON)
  // --------------------------------------------------------
  Widget _buildTopCard(BuildContext context, AttendanceState state) {
    final ctrl = ref.read(attendanceControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // HALF SELECT
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Half", style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: state.half,
                    underline: const SizedBox(),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "Morning",
                        child: Text("Morning"),
                      ),
                      DropdownMenuItem(
                        value: "Evening",
                        child: Text("Evening"),
                      ),
                    ],
                    onChanged: (v) => ctrl.setHalf(v!),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 30),

          // DATE PICKER
          SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Date", style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );

                    if (picked != null) {
                      await ctrl.setDate(picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(DateFormat("dd/MM/yyyy").format(state.date)),
                        const Spacer(),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // SAVE BUTTON
          ElevatedButton.icon(
            onPressed: () async {
              await ctrl.saveAttendance();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Attendance Saved")),
              );
            },
            style: ElevatedButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 25, vertical: 16),
              backgroundColor: const Color(0xff1677FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              "Save Attendance",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // LIST HEADER ROW
  // --------------------------------------------------------
  Widget _headerRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Expanded(
          flex: 3,
          child: Text(
            "STUDENT NAME",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            "ATTENDANCE STATUS",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------
  // STUDENT LIST
  // --------------------------------------------------------
  Widget _studentList(AttendanceState state) {
    if (state.students.isEmpty) {
      return const Center(child: Text("No Students Found"));
    }

    final ctrl = ref.read(attendanceControllerProvider.notifier);

    // 🔥 Sort students by roll number
    final students = [...state.students]
      ..sort((a, b) => a.rollNo.compareTo(b.rollNo));

    return ListView.separated(
      itemCount: students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final s = students[index];
        final marked = state.status[s.studentId];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(s.imageUrl),
            ),
            title: Text(
              s.studentName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text("Roll No: ${s.rollNo}"),

            // 🔥 Both buttons unselected when marked == null
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _btn(
                  text: "Present",
                  active: marked == true,
                  onTap: () => ctrl.markPresent(s.studentId),
                ),
                const SizedBox(width: 8),
                _btn(
                  text: "Absent",
                  active: marked == false,
                  onTap: () => ctrl.markAbsent(s.studentId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------
  // STATUS BUTTON
  // --------------------------------------------------------
  Widget _btn({
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    const color = Color(0xff1677FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
