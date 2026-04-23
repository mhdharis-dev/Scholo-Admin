import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:scholo_admin/features/teacherView/report/screen/month_wise_report.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../models/teacher_model.dart';
import '../controller/year_wise_report_controller.dart';

class YearWiseReportScreen extends ConsumerStatefulWidget {
  final String teacherId; // from previous page

  const YearWiseReportScreen({
    super.key,
    required this.teacherId,
  });

  @override
  ConsumerState<YearWiseReportScreen> createState() =>
      _YearWiseReportScreenState();
}

class _YearWiseReportScreenState
    extends ConsumerState<YearWiseReportScreen> {
  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------

  /// "2025-03" -> "March 2025"
  String _formatMonthKey(String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = parts[0];
      final month = int.parse(parts[1]);

      const names = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return "${names[month]} $year";
    } catch (_) {
      return monthKey;
    }
  }

  // --------------------------------------------------
  // Month stats: attendance % & leave days
  // leaveDays = totalDaysInMonth - numberOfAttendanceDays
  // --------------------------------------------------

  MonthStats _calculateMonthStats(List<Map<String, dynamic>> dates) {
    final Map<String, Map<int, double>> studentDayUnits = {};
    final Set<int> workingDays = {};

    for (final entry in dates) {
      final dateStr = entry['date'] as String; // DD-MM-YYYY
      final data = entry['data'] as Map<String, dynamic>;

      int day;
      try {
        day = int.parse(dateStr.split('-')[0]);
        workingDays.add(day);
      } catch (_) {
        continue;
      }

      data.forEach((_, divisions) {
        if (divisions is Map<String, dynamic>) {
          divisions.forEach((_, students) {
            if (students is List) {
              for (final s in students) {
                if (s is! Map<String, dynamic>) continue;

                final roll = (s['rollNo'] ?? 0) as int;
                final status =
                (s['presentDetail'] ?? '').toString().toLowerCase();

                double unit = 0;
                if (status.contains('full') ||
                    status.contains('morning & evening')) {
                  unit = 1;
                } else if (status.contains('half')) {
                  unit = 0.5;
                }

                studentDayUnits.putIfAbsent(roll.toString(), () => {});
                studentDayUnits[roll.toString()]![day] = unit;
              }
            }
          });
        }
      });
    }

    final totalStudents = studentDayUnits.length;
    final totalWorkingDays = workingDays.length;

    double presentUnits = 0;
    studentDayUnits.forEach((_, days) {
      presentUnits += days.values.fold(0, (a, b) => a + b);
    });

    final totalPossibleUnits = totalStudents * totalWorkingDays;

    final percentage = totalPossibleUnits == 0
        ? 0.0
        : (presentUnits / totalPossibleUnits) * 100;

    // Calendar-based leave days
    int daysInMonth = 30;
    if (dates.isNotEmpty) {
      try {
        final first = dates.first['date'] as String;
        final p = first.split('-');
        final lastDay =
        DateTime(int.parse(p[2]), int.parse(p[1]) + 1, 0);
        daysInMonth = lastDay.day;
      } catch (_) {}
    }

    final leaveDays = daysInMonth - totalWorkingDays;

    return MonthStats(
      attendancePercentage: percentage,
      leaveDays: leaveDays < 0 ? 0 : leaveDays,
      totalUnits: totalPossibleUnits,
      presentUnits: presentUnits,
    );
  }

  // --------------------------------------------------
  // PDF: Full matrix, 31 columns, colored circles (per month)
  // --------------------------------------------------

  /// Generates a full matrix PDF for a single month, returns bytes
  Future<Uint8List> _generateStyledPdfBytes({
    required TeacherModel teacher,
    required String monthLabel,
    required List<Map<String, dynamic>> dates,
  }) async {
    final pdf = pw.Document();

    final teacherName = teacher.teacherName;
    final classNo = teacher.classNo;
    final division = teacher.division;

    // 1) Build matrix: rollNo -> { day: status }
    final Map<int, Map<int, String>> matrix = {}; // roll -> { day -> status }
    final Map<int, String> studentNames = {}; // roll -> name

    for (final entry in dates) {
      final dateStr = entry['date'] as String; // "15-11-2025"
      final data = entry['data'] as Map<String, dynamic>;

      int day = 0;
      try {
        day = int.parse(dateStr.split('-')[0]); // DD
      } catch (_) {}

      if (day <= 0 || day > 31) continue;

      data.forEach((_, divisions) {
        if (divisions is Map<String, dynamic>) {
          divisions.forEach((_, students) {
            if (students is List) {
              for (final s in students) {
                if (s is! Map<String, dynamic>) continue;

                final roll = (s['rollNo'] ?? 0) as int;
                final name = (s['studentName'] ?? '').toString();
                final status = (s['status'] ?? '').toString();

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

    // Count totals & stats:
    final stats = _calculateMonthStats(dates);
    final totalStudents = sortedRolls.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              "$monthLabel Attendance Report",
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Teacher: $teacherName"),
              pw.Text("Class: $classNo"),
              pw.Text("Division: $division"),
            ],
          ),
          pw.SizedBox(height: 12),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.8),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _summaryCell("Total Students: $totalStudents"),
                  _summaryCell(
                      "Attendance: ${stats.attendancePercentage.toStringAsFixed(1)}%"),
                  _summaryCell("Leave Days: ${stats.leaveDays}"),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          pw.Row(
            children: [
              _legendCircle(PdfColors.green, "Full Day present"),
              pw.SizedBox(width: 16),
              _legendCircle(PdfColors.blue, "Half Day present"),
              pw.SizedBox(width: 16),
              _legendCircle(PdfColors.red, "Absent"),
            ],
          ),
          pw.SizedBox(height: 10),

          // Matrix table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
            children: [
              // Header row: Roll, Name, 1..31
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _headerCell("Roll"),
                  _headerCell("Student Name"),
                  ...List.generate(31, (i) => _headerCell("${i + 1}")),
                ],
              ),

              // Student rows
              ...sortedRolls.map((roll) {
                final name = studentNames[roll] ?? "";
                final daysMap = matrix[roll] ?? {};

                return pw.TableRow(
                  children: [
                    _dataCell(roll.toString()),
                    _dataCell(name),
                    ...List.generate(31, (i) {
                      final day = i + 1;
                      final status = daysMap[day] ?? "";
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

  // --------------------------------------------------
  // YEAR PDF: multiple month sections in one file
  // --------------------------------------------------

  Future<Uint8List> _generateYearPdfBytes({
    required TeacherModel teacher,
    required String yearLabel,
    required Map<String, List<Map<String, dynamic>>> groupedData,
    required List<String> yearMonths,
  }) async {
    final pdf = pw.Document();

    final teacherName = teacher.teacherName;
    final classNo = teacher.classNo;
    final division = teacher.division;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) {
          final widgets = <pw.Widget>[];

          widgets.add(
            pw.Center(
              child: pw.Text(
                "Yearly Attendance Report - $yearLabel",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 20));

          for (final monthKey in yearMonths) {
            final monthLabel = _formatMonthKey(monthKey);
            final dates = groupedData[monthKey]!;
            final stats = _calculateMonthStats(dates);

            // Build matrix for this month
            final Map<int, Map<int, String>> matrix = {};
            final Map<int, String> studentNames = {};

            for (final entry in dates) {
              final dateStr = entry['date'] as String; // "DD-MM-YYYY"
              final data = entry['data'] as Map<String, dynamic>;

              int day = 0;
              try {
                day = int.parse(dateStr.split('-')[0]); // DD
              } catch (_) {}

              if (day <= 0 || day > 31) continue;

              data.forEach((_, divisions) {
                if (divisions is Map<String, dynamic>) {
                  divisions.forEach((_, students) {
                    if (students is List) {
                      for (final s in students) {
                        if (s is! Map<String, dynamic>) continue;

                        final roll = (s['rollNo'] ?? 0) as int;
                        final name = (s['studentName'] ?? '').toString();
                        final status = (s['status'] ?? '').toString();

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
            final totalStudents = sortedRolls.length;

            widgets.add(
              pw.Text(
                monthLabel,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 8));

            widgets.add(
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Teacher: $teacherName"),
                  pw.Text("Class: $classNo"),
                  pw.Text("Division: $division"),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 8));

            widgets.add(
              pw.Table(
                border:
                pw.TableBorder.all(color: PdfColors.grey700, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _summaryCell("Total Students: $totalStudents"),
                      _summaryCell(
                          "Attendance: ${stats.attendancePercentage.toStringAsFixed(1)}%"),
                      _summaryCell("Leave Days: ${stats.leaveDays}"),
                    ],
                  ),
                ],
              ),
            );

            widgets.add(pw.SizedBox(height: 8));
            widgets.add(
              pw.Row(
                children: [
                  _legendCircle(PdfColors.green, "Full Day present"),
                  pw.SizedBox(width: 16),
                  _legendCircle(PdfColors.blue, "Half Day present"),
                  pw.SizedBox(width: 16),
                  _legendCircle(PdfColors.red, "Absent"),
                ],
              ),
            );
            widgets.add(pw.SizedBox(height: 8));

            widgets.add(
              pw.Table(
                border:
                pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
                children: [
                  pw.TableRow(
                    decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _headerCell("Roll"),
                      _headerCell("Student Name"),
                      ...List.generate(31, (i) => _headerCell("${i + 1}")),
                    ],
                  ),
                  ...sortedRolls.map((roll) {
                    final name = studentNames[roll] ?? "";
                    final daysMap = matrix[roll] ?? {};
                    return pw.TableRow(
                      children: [
                        _dataCell(roll.toString()),
                        _dataCell(name),
                        ...List.generate(31, (i) {
                          final day = i + 1;
                          final status = daysMap[day] ?? "";
                          final color = _statusToColor(status);
                          return _circleCell(color);
                        }),
                      ],
                    );
                  }),
                ],
              ),
            );

            widgets.add(pw.SizedBox(height: 20));
            widgets.add(pw.Divider());
            widgets.add(pw.SizedBox(height: 20));
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------
  // Shared PDF helpers
  // --------------------------------------------------

  PdfColor _statusToColor(String status) {
    final s = status.toLowerCase();

    if (s.contains("absent")) {
      return PdfColors.red;
    }

    if (s.contains("full") || s.contains("morning & evening")) {
      return PdfColors.green;
    }

    if (s.contains("half")) {
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

  // --------------------------------------------------
  // DOWNLOAD, SHARE, PRINT (WEB + MOBILE SAFE)
  // --------------------------------------------------

  /// PRINT (old download function) – opens viewer / print dialog
  Future<void> _printPDF({
    required TeacherModel teacher,
    required String monthLabel,
    required List<Map<String, dynamic>> dates,
  }) async {
    final bytes = await _generateStyledPdfBytes(
      teacher: teacher,
      monthLabel: monthLabel,
      dates: dates,
    );

    if (kIsWeb) {
      // Web: open browser PDF viewer / print
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      // Mobile / Desktop: save and open via system app
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Attendance_$monthLabel.pdf");
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    }
  }

  /// DOWNLOAD (old share function) – uses share_pdf / share_xfiles
  Future<void> _downloadPDF({
    required TeacherModel teacher,
    required String monthLabel,
    required List<Map<String, dynamic>> dates,
  }) async {
    final bytes = await _generateStyledPdfBytes(
      teacher: teacher,
      monthLabel: monthLabel,
      dates: dates,
    );

    if (kIsWeb) {
      // Web: use printing share (download/share in browser)
      await Printing.sharePdf(
        bytes: bytes,
        filename: "Attendance_$monthLabel.pdf",
      );
    } else {
      // Mobile / Desktop: save to file and share via share_plus
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Attendance_$monthLabel.pdf");
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Attendance Report - $monthLabel",
      );
    }
  }

  /// PRINT YEAR (old downloadYear function)
  Future<void> _printYearPDF({
    required TeacherModel teacher,
    required String yearLabel,
    required Map<String, List<Map<String, dynamic>>> groupedData,
    required List<String> yearMonths,
  }) async {
    final bytes = await _generateYearPdfBytes(
      teacher: teacher,
      yearLabel: yearLabel,
      groupedData: groupedData,
      yearMonths: yearMonths,
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Attendance_Year_$yearLabel.pdf");
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    }
  }

  /// DOWNLOAD YEAR (old shareYear function)
  Future<void> _downloadYearPDF({
    required TeacherModel teacher,
    required String yearLabel,
    required Map<String, List<Map<String, dynamic>>> groupedData,
    required List<String> yearMonths,
  }) async {
    final bytes = await _generateYearPdfBytes(
      teacher: teacher,
      yearLabel: yearLabel,
      groupedData: groupedData,
      yearMonths: yearMonths,
    );

    if (kIsWeb) {
      await Printing.sharePdf(
        bytes: bytes,
        filename: "Attendance_Year_$yearLabel.pdf",
      );
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/Attendance_Year_$yearLabel.pdf");
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Attendance Yearly Report - $yearLabel",
      );
    }
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state =
    ref.watch(yearWiseReportControllerProvider(widget.teacherId));
    final selectedYear = ref.watch(selectedYearProvider);

    return Scaffold(
      backgroundColor: const Color(0xfff1f5fb),
      body: state.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearData) {
          final teacher = yearData.teacher;
          final groupedData = yearData.groupedData;

          if (groupedData.isEmpty) {
            return const Center(child: Text('No attendance found'));
          }

          final allMonths = groupedData.keys.toList()..sort();
          final years = allMonths
              .map((m) => m.substring(0, 4))
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a));

          final currentYear =
              selectedYear ?? (years.isNotEmpty ? years.first : "2025");

          final yearMonths =
          allMonths.where((m) => m.startsWith(currentYear)).toList()
            ..sort((a, b) => b.compareTo(a));

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP ROW: title (left) + year dropdown + year PRINT/DOWNLOAD/SHARE (right)
                Row(
                  children: [
                    const Text(
                      "Report Details",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    // Year dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentYear,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          items: years
                              .map(
                                (y) => DropdownMenuItem(
                              value: y,
                              child: Text("Year: $y"),
                            ),
                          )
                              .toList(),
                          onChanged: (value) {
                            ref
                                .read(selectedYearProvider.notifier)
                                .state = value;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Print Year (old download)
                    OutlinedButton.icon(
                      onPressed: teacher == null
                          ? null
                          : () => _printYearPDF(
                        teacher: teacher,
                        yearLabel: currentYear,
                        groupedData: groupedData,
                        yearMonths: yearMonths,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.print),
                      label: const Text("Print Year"),
                    ),
                    const SizedBox(width: 8),
                    // Download Year (old share)
                    ElevatedButton.icon(
                      onPressed: teacher == null
                          ? null
                          : () => _downloadYearPDF(
                        teacher: teacher,
                        yearLabel: currentYear,
                        groupedData: groupedData,
                        yearMonths: yearMonths,
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xff007bff),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text("Download Year"),
                    ),
                    const SizedBox(width: 8),
                    // Share Year (new share style)
                  ],
                ),

                const SizedBox(height: 24),

                // MONTH CARDS
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          children: yearMonths.map((monthKey) {
                            final label = _formatMonthKey(monthKey);
                            final realMonthKey = monthKey;
                            final dates = groupedData[monthKey]!;
                            final stats = _calculateMonthStats(dates);

                            return SizedBox(
                              width: constraints.maxWidth > 900
                                  ? 320
                                  : constraints.maxWidth * 0.9,
                              child: ReportCard(
                                monthLabel: label,
                                monthKey: realMonthKey,
                                stats: stats,
                                onPrint: teacher == null
                                    ? null
                                    : () => _printPDF(
                                  teacher: teacher,
                                  monthLabel: label,
                                  dates: dates,
                                ),
                                onDownload: teacher == null
                                    ? null
                                    : () => _downloadPDF(
                                  teacher: teacher,
                                  monthLabel: label,
                                  dates: dates,
                                ), teacher: widget.teacherId,
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------
// ReportCard Widget (UI matches screenshot)
// --------------------------------------------------

class ReportCard extends StatelessWidget {
  final String monthLabel;
  final String monthKey;
  final MonthStats stats;
  final VoidCallback? onPrint;
  final VoidCallback? onDownload;
  final String teacher;


  const ReportCard({
    super.key,
    required this.monthLabel,
    required this.monthKey,
    required this.stats,
    required this.onPrint,
    required this.onDownload,
    required this.teacher,   // NEW

  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MonthWiseReport(
              teacherId: teacher,   // 👈 Correct ID
              monthKey: monthKey,          // 👈 Correct monthKey "2025-10"
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Attendance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(Icons.access_time, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Attendance",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${stats.attendancePercentage.toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xff00b341),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
                const SizedBox(width: 40),
                // Leaves
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.beach_access, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Leaves",
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${stats.leaveDays} Days",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xffff3b30),
                      ),
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // PRINT
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrint,
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text("Print"),
                  ),
                ),
                const SizedBox(width: 8),
                // DOWNLOAD
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDownload,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xff007bff),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text("Download"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------
// MonthStats model
// --------------------------------------------------

class MonthStats {
  final double attendancePercentage;
  final int leaveDays;
  final int totalUnits;
  final double presentUnits;

  MonthStats({
    required this.attendancePercentage,
    required this.leaveDays,
    required this.totalUnits,
    required this.presentUnits,
  });
}
