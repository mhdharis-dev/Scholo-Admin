import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

import '../../../../models/timeTable_model.dart';
import '../../../../models/period_model.dart';

class TimetableViewPage extends ConsumerWidget {
  final String teacherId;
  final int classNo;
  final String division;
  final TimetableModel timetable;

  const TimetableViewPage({
    super.key,
    required this.teacherId,
    required this.classNo,
    required this.division,
    required this.timetable,
  });

  Future<void> _downloadTimetable(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdfBytes();
      final blob = html.Blob([pdfBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute("download", "${timetable.timetableName}.pdf")
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      log("Download error: $e");
    }
  }

  Future<void> _printTimetable(BuildContext context) async {
    try {
      final pdfBytes = await _generatePdfBytes();
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      log("Print error: $e");
    }
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'Monday':
        return const Color(0xff90CAF9); // Soft Blue
      case 'Tuesday':
        return const Color(0xffA5D6A7); // Soft Green
      case 'Wednesday':
        return const Color(0xffFFF59D); // Soft Yellow
      case 'Thursday':
        return const Color(0xffEF9A9A); // Soft Red
      case 'Friday':
        return const Color(0xffCE93D8); // Soft Purple
      case 'Saturday':
        return const Color(0xffB2DFDB); // Soft Teal
      case 'Sunday':
        return const Color(0xffFFCC80); // Soft Orange
      default:
        return const Color(0xffE2E8F0);
    }
  }

  PdfColor _getPdfDayColor(String day) {
    switch (day) {
      case 'Monday':
        return PdfColors.blue200;
      case 'Tuesday':
        return PdfColors.green200;
      case 'Wednesday':
        return PdfColors.yellow200;
      case 'Thursday':
        return PdfColors.red200;
      case 'Friday':
        return PdfColors.purple200;
      case 'Saturday':
        return PdfColors.teal200;
      case 'Sunday':
        return PdfColors.orange200;
      default:
        return PdfColors.grey200;
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

  pw.Widget _buildPdfTimePeriodCell(int index) {
    final period = _getPeriodForIndex(index);
    final periodName = period?.periodName ?? "Period ${index + 1}";
    final time = period != null ? "${period.startTime} - ${period.endTime}" : "";
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      color: PdfColors.grey100,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            periodName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          ),
          if (time.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              time,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfTableCell(String day, int index) {
    final schedule = timetable.workingDays[day];
    if (schedule == null || index >= schedule.periods.length) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text("-", style: const pw.TextStyle(fontSize: 8)),
      );
    }
    final period = schedule.periods[index];
    if (period.type == 'break') {
      return pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.amber100,
        child: pw.Text(
          period.periodName,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
        ),
      );
    }
    
    final subject = (period.mainSubject != null && period.mainSubject!.trim().isNotEmpty)
        ? period.mainSubject!
        : (period.subject != null && period.subject!.trim().isNotEmpty ? period.subject! : '-');
    final teacher = period.teacherName ?? '';
    final time = "${period.startTime} - ${period.endTime}";
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(subject, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          if (teacher.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(teacher, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 2),
          pw.Text(time, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  Future<Uint8List> _generatePdfBytes() async {
    final pdf = pw.Document();
    
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final activeDays = allDays.where((d) => timetable.workingDays.containsKey(d) && timetable.workingDays[d]!.status == 'Working Day').toList();
    
    int maxPeriods = 0;
    for (var day in activeDays) {
      final schedule = timetable.workingDays[day];
      if (schedule != null && schedule.periods.length > maxPeriods) {
        maxPeriods = schedule.periods.length;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Timetable",
                        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "Name: ${timetable.timetableName} | Class $classNo - Division $division | Class Teacher: ${timetable.classTeacherName}",
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Text(
                    "Scholo Admin",
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(90),
                for (int i = 1; i <= activeDays.length; i++)
                  i: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      color: PdfColors.grey100,
                      child: pw.Text("Time / period", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    for (var day in activeDays)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: _getPdfDayColor(day),
                        child: pw.Text(day, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                  ],
                ),
                for (int i = 0; i < maxPeriods; i++)
                  pw.TableRow(
                    children: [
                      _buildPdfTimePeriodCell(i),
                      for (var day in activeDays)
                        _buildPdfTableCell(day, i),
                    ],
                  ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final activeDays = allDays.where((d) => timetable.workingDays.containsKey(d) && timetable.workingDays[d]!.status == 'Working Day').toList();
    
    int maxPeriods = 0;
    for (var day in activeDays) {
      final schedule = timetable.workingDays[day];
      if (schedule != null && schedule.periods.length > maxPeriods) {
        maxPeriods = schedule.periods.length;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff0F172A).withValues(alpha: 0.03),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: const Color(0xffF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Schedule Grid",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff1E293B),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Full week breakdown across active periods",
                                style: TextStyle(fontSize: 11, color: Color(0xff64748B)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xffE0F2FE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Class $classNo - $division",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff1D9BF0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: activeDays.isEmpty
                            ? _buildEmptyState()
                            : _buildTimetableGrid(activeDays, maxPeriods),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xff0f172a).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: const Color(0xffE2E8F0)),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF1E293B)),
            onPressed: () => context.pop(),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timetable.timetableName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Class Teacher: ${timetable.classTeacherName}",
                style: const TextStyle(fontSize: 12, color: Color(0xff64748B)),
              ),
            ],
          ),
        ),
        _buildHeaderActionBtn(Icons.download_rounded, () => _downloadTimetable(context)),
        const SizedBox(width: 8),
        _buildHeaderActionBtn(Icons.print_rounded, () => _printTimetable(context)),
      ],
    );
  }

  Widget _buildHeaderActionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xff0f172a).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xff475569)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.calendar_view_week_rounded, size: 48, color: Color(0xffCBD5E1)),
          SizedBox(height: 12),
          Text(
            "No active working days defined in this timetable",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(List<String> activeDays, int maxPeriods) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(140),
          border: TableBorder.all(color: const Color(0xffE2E8F0), width: 1),
          children: [
            TableRow(
              children: [
                _buildGridHeaderCell("Time / period", isFirstColumn: true),
                for (var day in activeDays)
                  _buildGridHeaderCell(day, dayName: day),
              ],
            ),
            for (int i = 0; i < maxPeriods; i++)
              TableRow(
                children: [
                  _buildGridTimePeriodCell(i),
                  for (var day in activeDays)
                    _buildGridTableCell(day, i),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridHeaderCell(String text, {bool isFirstColumn = false, String? dayName}) {
    final bgColor = isFirstColumn
        ? const Color(0xffF8FAFC)
        : (dayName != null ? _getDayColor(dayName) : const Color(0xffF8FAFC));
    final textColor = isFirstColumn
        ? const Color(0xff475569)
        : (dayName != null ? const Color(0xff1E293B) : const Color(0xff475569));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      alignment: Alignment.center,
      color: bgColor,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildGridTimePeriodCell(int index) {
    final period = _getPeriodForIndex(index);
    final periodName = period?.periodName ?? "Period ${index + 1}";
    final time = period != null ? "${period.startTime} - ${period.endTime}" : "";
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      alignment: Alignment.center,
      color: const Color(0xffF8FAFC),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            periodName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xff1E293B),
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xff64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridTableCell(String day, int index) {
    final schedule = timetable.workingDays[day];
    if (schedule == null || index >= schedule.periods.length) {
      return Container(
        height: 72,
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text("-", style: TextStyle(color: Color(0xff94A3B8))),
        ),
      );
    }

    final period = schedule.periods[index];
    if (period.type == 'break') {
      return Container(
        height: 72,
        color: const Color(0xffFEF3C7),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: Text(
          period.periodName,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xffB45309),
          ),
        ),
      );
    }

    final subject = (period.mainSubject != null && period.mainSubject!.trim().isNotEmpty)
        ? period.mainSubject!
        : (period.subject != null && period.subject!.trim().isNotEmpty ? period.subject! : '-');
    final teacher = period.teacherName ?? '';
    final time = "${period.startTime} - ${period.endTime}";
    final cellColor = period.colorValue != null
        ? Color(period.colorValue!)
        : const Color(0xff1D9BF0);

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: cellColor, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            subject,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xff1E293B),
            ),
          ),
          if (teacher.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              teacher,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xff64748B),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(fontSize: 8, color: Color(0xff94A3B8)),
          ),
        ],
      ),
    );
  }
}
