// lib/features/report/month_wise_report/screen/month_wise_report_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../models/teacher_model.dart';
import '../controller/month_wise_report_controller.dart';

class MonthWiseReport extends ConsumerWidget {
  final String teacherId;
  final String monthKey; //"2025-11"

  const MonthWiseReport({
    super.key,
    required this.teacherId,
    required this.monthKey,
  });

  // ---------------------------------------------------------------------------
  //                           UI HELPERS
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = MonthReportParams(teacherId: teacherId, monthKey: monthKey);
    final state = ref.watch(monthWiseReportControllerProvider(params));
    final controller =
    ref.read(monthWiseReportControllerProvider(params).notifier);

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Download All Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reports for ${controller.monthLabel}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side:
                          const BorderSide(color: Color(0xff5B5CEB)),
                        ),
                      ),
                      icon: const Icon(Icons.print, color: Color(0xff5B5CEB)),
                      label: const Text(
                        'Print All',
                        style: TextStyle(
                          color: Color(0xff5B5CEB),
                          fontSize: 15,
                        ),
                      ),
                      onPressed: state.teacher == null ||
                          state.reports.isEmpty
                          ? null
                          : () => _printMonthPDF(
                        teacher: state.teacher!,
                        monthLabel: controller.monthLabel,
                        dates: state.reports,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff5B5CEB),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon:
                      const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Download All',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      onPressed: state.teacher == null ||
                          state.reports.isEmpty
                          ? null
                          : () => _downloadMonthPDF(
                        teacher: state.teacher!,
                        monthLabel: controller.monthLabel,
                        dates: state.reports,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                    ? _ErrorView(
                  message: state.error!,
                  onRetry: () => controller.refresh(),
                )
                    : state.reports.isEmpty
                    ? const Center(
                  child: Text('No reports for this month'),
                )
                    : Column(
                  children: [
                    // Header Row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'DATE',
                              style: TextStyle(
                                letterSpacing: 1,
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              'REPORT TITLE',
                              style: TextStyle(
                                letterSpacing: 1,
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'ACTIONS',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                letterSpacing: 1,
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Rows
                    Expanded(
                      child: ListView.separated(
                        itemCount: state.reports.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade300,
                        ),
                        itemBuilder: (context, index) {
                          final day = state.reports[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                // DATE
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatDate(day.date),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight.w500,
                                    ),
                                  ),
                                ),

                                // TITLE
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    'Attendance Report - ${day.label}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                // ACTIONS: Print + Download this day
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.print,
                                          size: 22,
                                          color:
                                          Color(0xff5B5CEB),
                                        ),
                                        onPressed: state
                                            .teacher ==
                                            null
                                            ? null
                                            : () =>
                                            _printDayPDF(
                                              teacher: state
                                                  .teacher!,
                                              report: day,
                                            ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download,
                                          size: 22,
                                          color:
                                          Color(0xff5B5CEB),
                                        ),
                                        onPressed: state
                                            .teacher ==
                                            null
                                            ? null
                                            : () =>
                                            _downloadDayPDF(
                                              teacher: state
                                                  .teacher!,
                                              report: day,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //                           MONTH PDF  (TOP BUTTON)
  // ---------------------------------------------------------------------------

  Future<void> _printMonthPDF({
    required TeacherModel teacher,
    required String monthLabel,
    required List<DayReportModel> dates,
  }) async {
    final bytes = await _generateStyledMonthPdfBytes(
      teacher: teacher,
      monthLabel: monthLabel,
      dates: dates,
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Attendance_$monthLabel.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _downloadMonthPDF({
    required TeacherModel teacher,
    required String monthLabel,
    required List<DayReportModel> dates,
  }) async {
    final bytes = await _generateStyledMonthPdfBytes(
      teacher: teacher,
      monthLabel: monthLabel,
      dates: dates,
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Attendance_$monthLabel.pdf',
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Attendance_$monthLabel.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report - $monthLabel',
      );
    }
  }

  Future<Uint8List> _generateStyledMonthPdfBytes({
    required TeacherModel teacher,
    required String monthLabel,
    required List<DayReportModel> dates,
  }) async {
    final pdf = pw.Document();

    final teacherName = teacher.teacherName;
    final classNo = teacher.classNo;
    final division = teacher.division;

    final Map<int, Map<int, String>> matrix = {};
    final Map<int, String> studentNames = {};

    for (final dayReport in dates) {
      final data = dayReport.data;
      final day = dayReport.date.day;

      data.forEach((classKey, divisions) {
        if (divisions is Map<String, dynamic>) {
          divisions.forEach((divKey, students) {
            if (students is List) {
              for (final s in students) {
                if (s is! Map<String, dynamic>) continue;

                final roll = (s['rollNo'] ?? 0) as int;
                final name = (s['studentName'] ?? '').toString();
                final status =
                (s['presentDetail'] ?? s['status'] ?? '').toString();

                studentNames[roll] = name;

                matrix.putIfAbsent(roll, () => {});
                matrix[roll]![day] = status;
              }
            }
          });
        }
      });
    }

    final sortedRolls = studentNames.keys.toList()..sort();
    final stats = _calculateMonthStats(dates);
    final totalStudents = sortedRolls.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => [
          pw.Center(
            child: pw.Text(
              '$monthLabel Attendance Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Teacher: $teacherName'),
              pw.Text('Class: $classNo'),
              pw.Text('Division: $division'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Summary:', style: pw.TextStyle(fontSize: 12)),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                _summaryCell('Total Students: $totalStudents'),
                _summaryCell('Attendance: ${stats.attendancePercentage.toStringAsFixed(1)}%'),
                _summaryCell('Working Days: ${dates.length}'),
              ])
            ],
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _headerCell('Roll'),
                  _headerCell('Student Name'),
                  ...List.generate(31, (i) => _headerCell('${i + 1}')),
                ],
              ),
              ...sortedRolls.map((roll) {
                final daysMap = matrix[roll] ?? {};
                return pw.TableRow(
                  children: [
                    _dataCell(roll.toString()),
                    _dataCell(studentNames[roll] ?? ''),
                    ...List.generate(31, (i) {
                      final d = i + 1;
                      final status = daysMap[d] ?? '';
                      final color = _statusToColor(status);
                      return _circleCell(color);
                    }),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  //                           DAY PDF  (ROW BUTTONS)
  // ---------------------------------------------------------------------------

  Future<void> _printDayPDF({
    required TeacherModel teacher,
    required DayReportModel report,
  }) async
  {
    final bytes = await _generateDayPdfBytes(
      teacher: teacher,
      report: report,
    );

    final label = report.label;

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Attendance_$label.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    }
  }

  Future<void> _downloadDayPDF({
    required TeacherModel teacher,
    required DayReportModel report,
  }) async {
    final bytes = await _generateDayPdfBytes(
      teacher: teacher,
      report: report,
    );

    final label = report.label;

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Attendance_$label.pdf',
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Attendance_$label.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance Report - $label',
      );
    }
  }

  Future<Uint8List> _generateDayPdfBytes({
    required TeacherModel teacher,
    required DayReportModel report,
  }) async {
    final pdf = pw.Document();

    final dateLabel = report.label;
    final teacherName = teacher.teacherName;
    final classNo = teacher.classNo;
    final division = teacher.division;

    final Map<String, dynamic> data = report.data;
    final List<_DayRow> rows = [];

    data.forEach((classKey, divisions) {
      if (divisions is Map<String, dynamic>) {
        divisions.forEach((divKey, students) {
          if (students is List) {
            for (final s in students) {
              if (s is! Map<String, dynamic>) continue;
              rows.add(
                _DayRow(
                  roll: (s['rollNo'] ?? 0) as int,
                  name: (s['studentName'] ?? '').toString(),
                  presentDetail:
                  (s['presentDetail'] ?? s['status'] ?? '').toString(),
                  status: (s['status'] ?? '').toString(),
                ),
              );
            }
          }
        });
      }
    });

    rows.sort((a, b) => a.roll.compareTo(b.roll));

    final totalStudents = rows.length;
    final totalPresent = rows.where((r) => r.presentDetail != 'Absent').length;
    final totalAbsent = totalStudents - totalPresent;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(
                'Attendance Report - $dateLabel',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Teacher: $teacherName'),
                pw.Text('Class: $classNo'),
                pw.Text('Division: $division'),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(children: [
                  _summaryCell('Total: $totalStudents'),
                  _summaryCell('Present: $totalPresent'),
                  _summaryCell('Absent: $totalAbsent'),
                ])
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _headerCell('Roll'),
                    _headerCell('Name'),
                    _headerCell('Detail'),
                    _headerCell('Status'),
                  ],
                ),
                ...rows.map((r) => pw.TableRow(children: [
                  _dataCell(r.roll.toString()),
                  _dataCell(r.name),
                  _dataCell(r.presentDetail),
                  _dataCell(r.status),
                ])),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  //                           COMMON PDF HELPERS
  // ---------------------------------------------------------------------------

  PdfColor _statusToColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('absent')) return PdfColors.red;

    if (s.contains('morning & evening') || s.contains('full day')) {
      return PdfColors.green;
    }

    if (s.contains('half day') ||
        s.contains('morning half') ||
        s.contains('evening half')) {
      return PdfColors.blue;
    }

    return PdfColors.white;
  }

  pw.Widget _summaryCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );

  pw.Widget _legendCircle(PdfColor color, String label) => pw.Row(
    children: [
      pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(
          color: color,
          shape: pw.BoxShape.circle,
        ),
      ),
      pw.SizedBox(width: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    ],
  );

  pw.Widget _headerCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
        ),
      ),
    ),
  );

  pw.Widget _dataCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Center(
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
      ),
    ),
  );

  pw.Widget _circleCell(PdfColor color) => pw.Center(
    child: pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(
        color: color,
        shape: pw.BoxShape.circle,
      ),
    ),
  );

  MonthStats _calculateMonthStats(List<DayReportModel> dates) {
    final Map<int, Map<int, double>> studentDayUnits = {};
    final Set<int> workingDays = {};

    for (final day in dates) {
      final dayNo = day.date.day;
      workingDays.add(dayNo);

      day.data.forEach((classKey, divisions) {
        if (divisions is Map<String, dynamic>) {
          divisions.forEach((divKey, students) {
            if (students is List) {
              for (final s in students) {
                if (s is! Map<String, dynamic>) continue;

                final roll = (s['rollNo'] ?? 0) as int;
                final detail = (s['presentDetail'] ?? s['status'] ?? '')
                    .toString()
                    .toLowerCase();

                double unit = 0;
                if (detail.contains('full') ||
                    detail.contains('morning & evening')) {
                  unit = 1;
                } else if (detail.contains('half')) {
                  unit = 0.5;
                }

                studentDayUnits.putIfAbsent(roll, () => {});
                studentDayUnits[roll]![dayNo] = unit;
              }
            }
          });
        }
      });
    }

    final totalStudents = studentDayUnits.length;
    final totalDays = workingDays.length;

    double presentUnits = 0;
    studentDayUnits.values.forEach(
          (days) => presentUnits += days.values.fold(0, (a, b) => a + b),
    );

    final totalPossible = totalStudents * totalDays;
    final percentage =
    totalPossible == 0 ? 0 : (presentUnits / totalPossible) * 100;

    return MonthStats(
      attendancePercentage: percentage.toDouble(),
      leaveDays: 0,
    );
  }
}

// small helper for day pdf rows
class _DayRow {
  final int roll;
  final String name;
  final String presentDetail;
  final String status;

  _DayRow({
    required this.roll,
    required this.name,
    required this.presentDetail,
    required this.status,
  });
}

class MonthStats {
  final double attendancePercentage;
  final int leaveDays;

  MonthStats({
    required this.attendancePercentage,
    required this.leaveDays,
  });
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
