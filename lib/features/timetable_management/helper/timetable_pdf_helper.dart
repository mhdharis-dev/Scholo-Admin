import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../../../models/timeTable_model.dart';
import '../../../models/period_model.dart';
import '../../../models/school_model.dart';

class TimetablePdfHelper {
  static PdfColor _getPdfDayColor(String day) {
    switch (day) {
      case 'Monday':
        return PdfColors.blue100;
      case 'Tuesday':
        return PdfColors.green100;
      case 'Wednesday':
        return PdfColors.amber100;
      case 'Thursday':
        return PdfColors.red100;
      case 'Friday':
        return PdfColors.purple100;
      case 'Saturday':
        return PdfColors.teal100;
      case 'Sunday':
        return PdfColors.orange100;
      default:
        return PdfColors.grey100;
    }
  }

  static PeriodSlotModel? _getPeriodForIndex(TimetableModel timetable, int index) {
    for (var day in timetable.workingDays.keys) {
      final schedule = timetable.workingDays[day];
      if (schedule != null && index < schedule.periods.length) {
        return schedule.periods[index];
      }
    }
    return null;
  }

  static Future<Uint8List> generateTimetablePdfBytes({
    required TimetableModel timetable,
    SchoolModel? school,
  }) async {
    final pdf = pw.Document();

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
                        school?.schoolName.isNotEmpty == true ? school!.schoolName : "Scholo Academic System",
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "${timetable.timetableName} • Class ${timetable.classNo} (${timetable.division})",
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                      ),
                      pw.Text(
                        "Class Teacher: ${timetable.classTeacherName.isNotEmpty ? timetable.classTeacherName : 'N/A'} • Total Periods: ${timetable.totalPeriods} • Working Days: ${activeDays.length}",
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "OFFICIAL CLASS TIMETABLE",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                      ),
                      pw.Text(
                        "Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(90),
                for (int i = 1; i <= activeDays.length; i++) i: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("Time / Period", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    for (var day in activeDays)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: _getPdfDayColor(day),
                        child: pw.Center(
                          child: pw.Text(day, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                  ],
                ),
                for (int i = 0; i < maxPeriods; i++)
                  pw.TableRow(
                    children: [
                      // Time / Period column
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        color: PdfColors.grey100,
                        child: pw.Builder(builder: (ctx) {
                          final period = _getPeriodForIndex(timetable, i);
                          final name = period?.periodName ?? "Period ${i + 1}";
                          final time = period != null ? "${period.startTime} - ${period.endTime}" : "";
                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                              if (time.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(time, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                              ],
                            ],
                          );
                        }),
                      ),
                      for (var day in activeDays)
                        pw.Builder(builder: (ctx) {
                          final schedule = timetable.workingDays[day];
                          if (schedule == null || i >= schedule.periods.length) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Center(child: pw.Text("-", style: const pw.TextStyle(fontSize: 8))),
                            );
                          }
                          final period = schedule.periods[i];
                          if (period.type == 'break') {
                            return pw.Container(
                              alignment: pw.Alignment.center,
                              padding: const pw.EdgeInsets.all(6),
                              color: PdfColors.amber50,
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
                        }),
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

  static Future<void> downloadTimetablePdf(TimetableModel timetable, {SchoolModel? school}) async {
    try {
      final pdfBytes = await generateTimetablePdfBytes(timetable: timetable, school: school);
      final blob = html.Blob([pdfBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute("download", "${timetable.timetableName}_Class_${timetable.classNo}_${timetable.division}.pdf")
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      debugPrint("Download error: $e");
    }
  }

  static Future<void> printTimetablePdf(TimetableModel timetable, {SchoolModel? school}) async {
    try {
      final pdfBytes = await generateTimetablePdfBytes(timetable: timetable, school: school);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      debugPrint("Print error: $e");
    }
  }

  static Future<void> downloadAllTimetablesSummaryPdf(List<TimetableModel> timetables, {SchoolModel? school}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
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
                        school?.schoolName.isNotEmpty == true ? school!.schoolName : "Scholo Academic System",
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text("Academic Timetable Master Directory", style: pw.TextStyle(fontSize: 13, color: PdfColors.grey800)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Total Schedules: ${timetables.length}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _cell("SL", isHeader: true, flex: 1),
                    _cell("Class & Div", isHeader: true, flex: 2),
                    _cell("Timetable Title", isHeader: true, flex: 4),
                    _cell("Class Teacher", isHeader: true, flex: 3),
                    _cell("Working Days", isHeader: true, flex: 2),
                    _cell("Periods", isHeader: true, flex: 2),
                    _cell("Created Date", isHeader: true, flex: 2),
                  ],
                ),
                for (int i = 0; i < timetables.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                    children: [
                      _cell("${i + 1}", flex: 1),
                      _cell("Class ${timetables[i].classNo} - ${timetables[i].division}", flex: 2),
                      _cell(timetables[i].timetableName, flex: 4),
                      _cell(timetables[i].classTeacherName.isNotEmpty ? timetables[i].classTeacherName : "-", flex: 3),
                      _cell("${timetables[i].totalWorkingDays} Days", flex: 2),
                      _cell("${timetables[i].totalPeriods} Periods", flex: 2),
                      _cell("${timetables[i].createdDate.day}/${timetables[i].createdDate.month}/${timetables[i].createdDate.year}", flex: 2),
                    ],
                  ),
              ],
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final blob = html.Blob([pdfBytes]);
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: blobUrl)
      ..setAttribute("download", "Timetable_Master_Directory.pdf")
      ..click();
    html.Url.revokeObjectUrl(blobUrl);
  }

  static pw.Widget _cell(String text, {bool isHeader = false, int flex = 1}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }
}
