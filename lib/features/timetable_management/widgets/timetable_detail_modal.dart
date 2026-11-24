import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/timeTable_model.dart';
import '../../../models/period_model.dart';
import '../../../auth/controller/login_controller.dart';
import '../helper/timetable_pdf_helper.dart';

class TimetableDetailModal extends ConsumerWidget {
  final TimetableModel timetable;

  const TimetableDetailModal({
    super.key,
    required this.timetable,
  });

  static void show(BuildContext context, TimetableModel timetable) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TimetableDetailModal(timetable: timetable),
    );
  }

  Color _getDayHeaderColor(String day) {
    switch (day) {
      case 'Monday':
        return const Color(0xFF3B82F6);
      case 'Tuesday':
        return const Color(0xFF10B981);
      case 'Wednesday':
        return const Color(0xFFF59E0B);
      case 'Thursday':
        return const Color(0xFFEF4444);
      case 'Friday':
        return const Color(0xFF8B5CF6);
      case 'Saturday':
        return const Color(0xFF06B6D4);
      case 'Sunday':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF64748B);
    }
  }

  PeriodSlotModel? _getPeriodForIndex(int index) {
    for (var day in timetable.workingDays.keys) {
      final schedule = timetable.workingDays[day];
      if (schedule != null && index < schedule.periods.length) {
        return schedule.periods[index];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final school = ref.watch(schoolStreamProvider).value;
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final activeDays = allDays
        .where((d) => timetable.workingDays.containsKey(d) && timetable.workingDays[d]!.status == 'Working Day')
        .toList();

    int maxPeriods = 0;
    for (var day in activeDays) {
      final schedule = timetable.workingDays[day];
      if (schedule != null && schedule.periods.length > maxPeriods) {
        maxPeriods = schedule.periods.length;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final modalWidth = screenWidth > 1200 ? 1100.0 : (screenWidth > 800 ? screenWidth * 0.9 : screenWidth * 0.95);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modal Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1193D4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Color(0xFF1193D4), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              timetable.timetableName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1193D4).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                "Class ${timetable.classNo} - ${timetable.division}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1193D4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Class Teacher: ${timetable.classTeacherName.isNotEmpty ? timetable.classTeacherName : 'Not Assigned'} • Total Periods: ${timetable.totalPeriods} • Working Days: ${activeDays.length}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Actions: Download PDF, Print, Close
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1193D4),
                      side: const BorderSide(color: Color(0xFF1193D4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => TimetablePdfHelper.downloadTimetablePdf(timetable, school: school),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text("PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => TimetablePdfHelper.printTimetablePdf(timetable, school: school),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text("Print", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    splashRadius: 20,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Timetable Grid Table ──
            Flexible(
              child: activeDays.isEmpty || maxPeriods == 0
                  ? Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "No active working days defined for this timetable.",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Table(
                              defaultColumnWidth: const FixedColumnWidth(140),
                              columnWidths: const {
                                0: FixedColumnWidth(110),
                              },
                              border: TableBorder(
                                horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                                verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                              ),
                              children: [
                                // Table Header: Days
                                TableRow(
                                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "Time / Period",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)),
                                      ),
                                    ),
                                    for (var day in activeDays)
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        color: _getDayHeaderColor(day).withValues(alpha: 0.12),
                                        alignment: Alignment.center,
                                        child: Text(
                                          day,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: _getDayHeaderColor(day),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                            // Periods Rows
                            for (int i = 0; i < maxPeriods; i++)
                              TableRow(
                                decoration: BoxDecoration(
                                  color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                ),
                                children: [
                                  // Time slot info
                                  Builder(builder: (ctx) {
                                    final period = _getPeriodForIndex(i);
                                    final name = period?.periodName ?? "Period ${i + 1}";
                                    final time = period != null ? "${period.startTime} - ${period.endTime}" : "";
                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1E293B)),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (time.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              time,
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                  // Day cells
                                  for (var day in activeDays)
                                    Builder(builder: (ctx) {
                                      final schedule = timetable.workingDays[day];
                                      if (schedule == null || i >= schedule.periods.length) {
                                        return Container(
                                          height: 70,
                                          alignment: Alignment.center,
                                          child: Text("-", style: TextStyle(color: Colors.grey.shade400)),
                                        );
                                      }
                                      final period = schedule.periods[i];
                                      if (period.type == 'break') {
                                        return Container(
                                          height: 70,
                                          padding: const EdgeInsets.all(8),
                                          color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                                          alignment: Alignment.center,
                                          child: Text(
                                            period.periodName,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFD97706),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }

                                      final subject = (period.mainSubject != null && period.mainSubject!.trim().isNotEmpty)
                                          ? period.mainSubject!
                                          : (period.subject != null && period.subject!.trim().isNotEmpty ? period.subject! : '-');
                                      final teacher = period.teacherName ?? '';
                                      final hasColor = period.colorValue != null;
                                      final Color cellAccent = hasColor ? Color(period.colorValue!) : const Color(0xFF1193D4);

                                      return Container(
                                        height: 70,
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: cellAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    subject,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (teacher.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                teacher,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
            ),

            // ── Modal Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Created: ${timetable.createdDate.day}/${timetable.createdDate.month}/${timetable.createdDate.year}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1193D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
