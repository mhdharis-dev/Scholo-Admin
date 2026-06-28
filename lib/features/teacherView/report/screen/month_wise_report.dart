// lib/features/report/month_wise_report/screen/month_wise_report_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../models/teacher_model.dart';
import '../controller/month_wise_report_controller.dart';
import '../helper/attendance_pdf_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/session_manager.dart';

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
                Row(
                  children: [
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
                        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black),
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Reports for ${controller.monthLabel}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
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
                          ref.invalidate(monthWiseReportControllerProvider(params));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      color: Colors.black.withValues(alpha: 0.05),
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
    final standardized = dates.map((d) => {
      'date': d.label,
      'data': d.data,
    }).toList();

    return AttendancePdfHelper.generateMonthlyReportPdf(
      teacher: teacher,
      monthLabel: monthLabel,
      rawDates: standardized,
    );
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
    final division = teacher.division.toUpperCase();

    // --- FETCH REAL SCHOOL DETAILS ---
    String schoolName = "SCHOLO PUBLIC SCHOOL";
    String schoolAddress = "Thootha, Malappuram, Kerala";
    try {
      final schoolId = teacher.schoolId.isNotEmpty ? teacher.schoolId : SessionManager.schoolId;
      if (schoolId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data['schoolName'] != null) {
              schoolName = data['schoolName'].toString().toUpperCase();
            }
            if (data['schoolAddress'] != null) {
              schoolAddress = data['schoolAddress'].toString();
            }
          }
        }
      }
    } catch (_) {}

    final Map<String, dynamic> data = report.data;
    final List<_DayRow> rows = [];

    data.forEach((classKey, divisions) {
      if (divisions is Map) {
        divisions.forEach((divKey, students) {
          if (students is List) {
            for (final s in students) {
              if (s is! Map) continue;
              rows.add(
                _DayRow(
                  roll: int.tryParse(s['rollNo'].toString()) ?? 0,
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

    final primaryColor = PdfColor.fromHex("#1293D4");
    final successColor = PdfColor.fromHex("#4CAF50");
    final warningColor = PdfColor.fromHex("#FF9800");
    final dangerColor = PdfColor.fromHex("#F44336");
    final initial = schoolName.isNotEmpty ? schoolName.substring(0, 1) : "S";

    int totalStudents = rows.length;
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalLeave = 0;

    for (final r in rows) {
      final statusStr = _formatStatus(r.status);
      if (statusStr == 'Absent') {
        totalAbsent++;
      } else if (statusStr == 'Leave') {
        totalLeave++;
      } else {
        totalPresent++;
      }
    }

    pw.Widget dayHeaderCell(String text, {bool alignLeft = false}) {
      return pw.Container(
        alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget dayDataCell(String text, {bool alignLeft = false, PdfColor? valColor, bool isBold = false}) {
      return pw.Container(
        alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valColor ?? PdfColors.black,
          ),
        ),
      );
    }

    pw.Widget summaryBox(String label, String val, PdfColor textColor) {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: "$label: ",
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
              pw.TextSpan(
                text: val,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 38,
                      height: 38,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        initial,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          schoolName,
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(schoolAddress, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          "DAILY ATTENDANCE REPORT",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: "Date: ",
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.TextSpan(
                            text: dateLabel,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: "Class: ",
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.TextSpan(
                            text: "$classNo - $division",
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: "Teacher: ",
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.TextSpan(
                            text: teacherName,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            pw.SizedBox(height: 10),

            // Summary row (Premium KPI design)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    summaryBox('Total Students', '$totalStudents', PdfColors.black),
                    summaryBox('Present', '$totalPresent', successColor),
                    summaryBox('Absent', '$totalAbsent', dangerColor),
                    summaryBox('Leave', '$totalLeave', warningColor),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 12),

            // Detail table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(40),  // Roll
                1: pw.FlexColumnWidth(3),    // Name
                2: pw.FixedColumnWidth(100), // Session
                3: pw.FixedColumnWidth(100), // Status
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    dayHeaderCell('Roll'),
                    dayHeaderCell('Name', alignLeft: true),
                    dayHeaderCell('Session'),
                    dayHeaderCell('Status'),
                  ],
                ),
                ...rows.map((r) {
                  final session = _formatSession(r.status);
                  final statusStr = _formatStatus(r.status);
                  final isAbsent = statusStr == 'Absent';
                  final isLeave = statusStr == 'Leave';
                  final isHalf = statusStr == 'Half Day';

                  final statusColor = isAbsent
                      ? dangerColor
                      : (isLeave
                      ? warningColor
                      : (isHalf ? primaryColor : successColor));

                  return pw.TableRow(
                    children: [
                      dayDataCell(r.roll.toString()),
                      dayDataCell(r.name, alignLeft: true),
                      dayDataCell(session),
                      dayDataCell(
                        statusStr.toUpperCase(),
                        valColor: statusColor,
                        isBold: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  String _formatSession(String status) {
    final s = status.toLowerCase();
    if (s.contains('morning & evening')) return 'Full Day';
    if (s.contains('morning half')) return 'Morning Half';
    if (s.contains('evening half')) return 'Evening Half';
    if (s.contains('half day')) return 'Half Day';
    if (s.contains('absent') || s.contains('leave')) return '-';
    return 'Full Day';
  }

  String _formatStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('absent')) return 'Absent';
    if (s.contains('leave')) return 'Leave';
    if (s.contains('half')) return 'Half Day';
    return 'Present';
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
