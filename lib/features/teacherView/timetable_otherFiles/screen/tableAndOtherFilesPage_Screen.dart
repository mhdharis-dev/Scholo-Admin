import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scholo_admin/features/teacherView/timetable_otherFiles/screen/timetableLayoutMaker.dart';
import 'package:speed_dial_fab/speed_dial_fab.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/otherFiles_model.dart';
import '../../../../models/timeTable_model.dart';
import '../../../../models/period_model.dart';
import '../controller/tableAndOtherFilesPag_controller.dart';
import '../repository/tableAndOtherFilesPag_repository.dart' show TimetableQueryParams;
import 'otherFilesAddingScreen.dart';
import 'timetableCreatingPage.dart';

class TableAndOtherFilePageScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final int classNo;
  final String division;

  const TableAndOtherFilePageScreen({
    super.key,
    required this.teacherId,
    required this.classNo,
    required this.division,
  });

  @override
  ConsumerState<TableAndOtherFilePageScreen> createState() =>
      _TableAndOtherFilePageScreenState();
}

class _TableAndOtherFilePageScreenState
    extends ConsumerState<TableAndOtherFilePageScreen> {
  bool _isGridView = true;

  // ── Logic (unchanged) ────────────────────────────────────────────────────────

  Future<void> downloadFileAsPdf({
    required String url,
    required String fileName,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      Uint8List bytes = response.bodyBytes;
      final isPdf = url.toLowerCase().contains(".pdf");
      Uint8List finalBytes;

      if (isPdf) {
        finalBytes = bytes;
      } else {
        final pdf = pw.Document();
        final image = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            build: (c) =>
                pw.Center(child: pw.Image(image, fit: pw.BoxFit.fill)),
          ),
        );
        finalBytes = await pdf.save();
      }

      final blob = html.Blob([finalBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute("download", "$fileName.pdf")
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      log("Download error: $e");
    }
  }

  Future<void> printFileAsPdf(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return;

    Uint8List bytes = response.bodyBytes;
    if (url.toLowerCase().contains(".pdf")) {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } else {
      final pdf = pw.Document();
      final image = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          build: (c) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  }

  void _openTimetable(BuildContext context, TimetableModel item) {
    Map<String, String> dayTypes = {
      'Sunday': 'Non-Working Day',
      'Monday': 'Non-Working Day',
      'Tuesday': 'Non-Working Day',
      'Wednesday': 'Non-Working Day',
      'Thursday': 'Non-Working Day',
      'Friday': 'Non-Working Day',
      'Saturday': 'Non-Working Day',
    };

    Map<String, List<Map<String, dynamic>>> scheduleData = {
      'Sunday': [],
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
    };

    item.workingDays.forEach((day, daySchedule) {
      dayTypes[day] = daySchedule.status;
      List<Map<String, dynamic>> slots = [];
      for (var period in daySchedule.periods) {
        List<Map<String, dynamic>>? assignedTeachers;
        if (period.teacherId != null && period.teacherId!.isNotEmpty) {
          List<String> ids = period.teacherId!.split(', ');
          List<String> names = (period.teacherName ?? '').split(', ');
          List<String> subjects = (period.subject ?? '').split(' / ');

          assignedTeachers = [];
          for (int i = 0; i < ids.length; i++) {
            assignedTeachers.add({
              'id': ids[i],
              'name': i < names.length ? names[i] : '',
              'subject': i < subjects.length ? subjects[i] : '',
              'color': period.colorValue != null
                  ? Color(period.colorValue!)
                  : const Color(0xFF2563EB),
            });
          }
        }

        Map<String, dynamic> slotData = {
          'name': period.periodName,
          'type': period.type,
          'start': period.startTime,
          'end': period.endTime,
          'mainSubject': period.mainSubject,
          'color': period.colorValue != null
              ? Color(period.colorValue!)
              : (period.type == 'period'
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFFFAF3A)),
        };
        if (assignedTeachers != null && assignedTeachers.isNotEmpty) {
          slotData['assignedTeachers'] = assignedTeachers;
        }
        slots.add(slotData);
      }
      scheduleData[day] = slots;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimeTableCreatingPage(
          teacherId: widget.teacherId,
          timetableName: item.timetableName,
          scheduleData: scheduleData,
          dayTypes: dayTypes,
        ),
      ),
    );
  }

  Future<void> downloadTimetableAsPdf(TimetableModel item) async {
    try {
      final pdfBytes = await _generateTimetablePdfBytes(item);
      final blob = html.Blob([pdfBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute("download", "${item.timetableName}.pdf")
        ..click();
      html.Url.revokeObjectUrl(blobUrl);
    } catch (e) {
      log("Download timetable error: $e");
    }
  }

  Future<void> printTimetableAsPdf(TimetableModel item) async {
    try {
      final pdfBytes = await _generateTimetablePdfBytes(item);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
    } catch (e) {
      log("Print timetable error: $e");
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

  PeriodSlotModel? _getPeriodForIndex(TimetableModel item, int index) {
    for (var day in item.workingDays.keys) {
      final schedule = item.workingDays[day];
      if (schedule != null && index < schedule.periods.length) {
        return schedule.periods[index];
      }
    }
    return null;
  }

  pw.Widget _buildPdfTimePeriodCell(TimetableModel item, int index) {
    final period = _getPeriodForIndex(item, index);
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

  pw.Widget _buildPdfTableCell(TimetableModel item, String day, int index) {
    final schedule = item.workingDays[day];
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

  Future<Uint8List> _generateTimetablePdfBytes(TimetableModel item) async {
    final pdf = pw.Document();
    
    final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final activeDays = allDays.where((d) => item.workingDays.containsKey(d) && item.workingDays[d]!.status == 'Working Day').toList();
    
    int maxPeriods = 0;
    for (var day in activeDays) {
      final schedule = item.workingDays[day];
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
                        "Name: ${item.timetableName} | Class ${item.classNo} - Division ${item.division} | Class Teacher: ${item.classTeacherName}",
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
                      _buildPdfTimePeriodCell(item, i),
                      for (var day in activeDays)
                        _buildPdfTableCell(item, day, i),
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final otherFilesAsync = ref.watch(otherFilesListProvider(widget.teacherId));
    final timetablesAsync = ref.watch(timetablesListProvider(TimetableQueryParams(
      classNo: widget.classNo.toString(),
      division: widget.division,
      teacherId: widget.teacherId,
    )));

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Academic Timetables ────────────────────────────────────
            Expanded(
              flex: 3,
              child: Container(
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
                    _buildLeftHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: timetablesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator(color: Color(0xff1D9BF0))),
                        error: (e, _) {
                          log(e.toString());
                          return Text("Error: $e");
                        },
                        data: (tables) => tables.isEmpty
                            ? _buildEmptyState("No Timetables Found", Icons.calendar_today_rounded)
                            : ListView.separated(
                                itemCount: tables.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, i) =>
                                    _buildTimetableCard(context, tables[i]),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 24),

            // ── RIGHT: Document Vault ────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Container(
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
                    _buildRightHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: otherFilesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator(color: Color(0xff1D9BF0))),
                        error: (e, _) => Text("Error: $e"),
                        data: (files) {
                          final filteredFiles = files
                              .where((f) =>
                                  f.classNo == widget.classNo &&
                                  f.division.trim().toUpperCase() == widget.division.trim().toUpperCase())
                              .toList();

                          if (_isGridView) {
                            final items = <Widget>[
                              ...filteredFiles.map((f) => _buildDocumentCard(f)),
                              _buildAddNewFileCard(),
                            ];
                            return GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.82,
                              children: items,
                            );
                          } else {
                            final items = <Widget>[
                              ...filteredFiles.map((f) => _buildDocumentListTile(f)),
                              _buildAddNewFileListTile(),
                            ];
                            return ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) => items[i],
                            );
                          }
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
      floatingActionButton: _buildSpeedDial(context),
    );
  }

  // ── Widget Methods ───────────────────────────────────────────────────────────

  Widget _buildLeftHeader() {
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Timetables',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xff1E293B),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Current & upcoming schedules',
              style: TextStyle(fontSize: 11, color: Color(0xff64748B)),
            ),
          ],
        ),
        const Spacer(),
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
              ref.invalidate(otherFilesListProvider(widget.teacherId));
              ref.invalidate(timetablesListProvider(TimetableQueryParams(
                classNo: widget.classNo.toString(),
                division: widget.division,
                teacherId: widget.teacherId,
              )));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Vault',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xff1E293B),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'High-fidelity repository for all academic records',
              style: TextStyle(fontSize: 11, color: Color(0xff64748B)),
            ),
          ],
        ),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn(
            icon: Icons.grid_view_rounded,
            selected: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
          const SizedBox(width: 4),
          _buildToggleBtn(
            icon: Icons.view_list_rounded,
            selected: !_isGridView,
            onTap: () => setState(() => _isGridView = false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xff0f172a).withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected ? const Color(0xff1D9BF0) : const Color(0xff64748B),
        ),
      ),
    );
  }

  Widget _buildTimetableCard(BuildContext context, TimetableModel item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffE0F2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Color(0xff1D9BF0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.timetableName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Timetable",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    _openTimetable(context, item);
                  } else if (val == 'delete') {
                    _showDeleteConfirmationDialog(
                      context: context,
                      title: "Delete Timetable?",
                      message: "Are you sure you want to delete '${item.timetableName}'? This action cannot be undone.",
                      onConfirm: () => ref
                          .read(timetableAndOtherFilesPageControllerProvider)
                          .deleteTimetable(
                            classNo: widget.classNo.toString(),
                            division: widget.division,
                            timetableName: item.timetableName,
                          ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Color(0xff64748B),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xffF1F5F9), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              InkWell(
                onTap: () => context.push(
                  '/admin/classrooms/teacher-dashboard/${widget.teacherId}/timetable-view/${widget.classNo}/${widget.division}',
                  extra: item,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View Schedule',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1D9BF0),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Color(0xff1D9BF0),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _buildActionIconBtn(
                Icons.download_rounded,
                () => downloadTimetableAsPdf(item),
              ),
              const SizedBox(width: 8),
              _buildActionIconBtn(
                Icons.print_rounded,
                () => printTimetableAsPdf(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(OtherFilesModel item) {
    final url = item.fileUrl.toLowerCase();
    final isImage =
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
    final isPdf = url.contains('.pdf');
    final isXlsx = url.contains('.xlsx') || url.contains('.xls');
    final isDocx = url.contains('.docx') || url.contains('.doc');

    final badgeColor = isPdf
        ? const Color(0xffFEE2E2)
        : isXlsx
        ? const Color(0xffD1FAE5)
        : isDocx
        ? const Color(0xffDBEAFE)
        : const Color(0xffF1F5F9);

    final badgeTextColor = isPdf
        ? const Color(0xff991B1B)
        : isXlsx
        ? const Color(0xff065F46)
        : isDocx
        ? const Color(0xff1E40AF)
        : const Color(0xff475569);

    final badgeText = isPdf
        ? "PDF"
        : isXlsx
        ? "Spreadsheet"
        : isDocx
        ? "Document"
        : isImage
        ? "Image"
        : "File";

    final fileIcon = isPdf
        ? Icons.picture_as_pdf_rounded
        : isXlsx
        ? Icons.table_chart_rounded
        : isDocx
        ? Icons.description_rounded
        : isImage
        ? Icons.image_rounded
        : Icons.insert_drive_file_rounded;

    final themeColor = isPdf
        ? const Color(0xffEF4444)
        : isXlsx
        ? const Color(0xff10B981)
        : isDocx
        ? const Color(0xff3B82F6)
        : const Color(0xff64748B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail area
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(19),
                    ),
                    child: isImage && item.fileUrl.isNotEmpty
                        ? Image.network(
                            item.fileUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildFileIconPlaceholder(fileIcon, themeColor, isPdf, isXlsx, isDocx),
                          )
                        : _buildFileIconPlaceholder(fileIcon, themeColor, isPdf, isXlsx, isDocx),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info + actions
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: item.tittle,
                  child: Text(
                    item.tittle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle == "OTHER FILE" ? "Notes" : item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildActionIconBtn(
                      Icons.download_rounded,
                      () => downloadFileAsPdf(
                        url: item.fileUrl,
                        fileName: item.tittle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionIconBtn(
                      Icons.print_rounded,
                      () => printFileAsPdf(item.fileUrl),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        final controller = ref.read(
                          timetableAndOtherFilesPageControllerProvider,
                        );
                        if (val == 'delete') {
                          _showDeleteConfirmationDialog(
                            context: context,
                            title: "Delete File?",
                            message: "Are you sure you want to delete '${item.tittle}'? This action cannot be undone.",
                            onConfirm: () => controller.deleteOtherFiles(item.id),
                          );
                        }
                        if (val == 'edit') {
                          _showEditTitleDialog(context, item);
                        }
                      },
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: Color(0xff64748B),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text("Edit")),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            "Delete",
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileIconPlaceholder(IconData icon, Color color, bool isPdf, bool isXlsx, bool isDocx) {
    Gradient gradient = const LinearGradient(
      colors: [Color(0xffF8FAFC), Color(0xffF1F5F9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (isPdf) {
      gradient = const LinearGradient(
        colors: [Color(0xffFFF1F2), Color(0xffFFE4E6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (isXlsx) {
      gradient = const LinearGradient(
        colors: [Color(0xffECFDF5), Color(0xffD1FAE5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (isDocx) {
      gradient = const LinearGradient(
        colors: [Color(0xffEFF6FF), Color(0xffDBEAFE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, size: 28, color: color),
        ),
      ),
    );
  }

  Widget _buildActionIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xffE2E8F0)),
        ),
        child: Icon(icon, size: 14, color: const Color(0xff475569)),
      ),
    );
  }

  Widget _buildAddNewFileCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherFilesAddingScreen(
            teacherId: widget.teacherId,
            classNo: widget.classNo,
            division: widget.division,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xffCBD5E1),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xffE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 26,
                  color: Color(0xff1D9BF0),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add New File',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff475569),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Upload doc, pdf or sheet',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xff94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentListTile(OtherFilesModel item) {
    final url = item.fileUrl.toLowerCase();
    final isImage =
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
    final isPdf = url.contains('.pdf');
    final isXlsx = url.contains('.xlsx') || url.contains('.xls');
    final isDocx = url.contains('.docx') || url.contains('.doc');

    final badgeColor = isPdf
        ? const Color(0xffFEE2E2)
        : isXlsx
        ? const Color(0xffD1FAE5)
        : isDocx
        ? const Color(0xffDBEAFE)
        : const Color(0xffF1F5F9);

    final badgeTextColor = isPdf
        ? const Color(0xff991B1B)
        : isXlsx
        ? const Color(0xff065F46)
        : isDocx
        ? const Color(0xff1E40AF)
        : const Color(0xff475569);

    final badgeText = isPdf
        ? "PDF"
        : isXlsx
        ? "Spreadsheet"
        : isDocx
        ? "Document"
        : isImage
        ? "Image"
        : "File";

    final fileIcon = isPdf
        ? Icons.picture_as_pdf_rounded
        : isXlsx
        ? Icons.table_chart_rounded
        : isDocx
        ? Icons.description_rounded
        : isImage
        ? Icons.image_rounded
        : Icons.insert_drive_file_rounded;

    final themeColor = isPdf
        ? const Color(0xffEF4444)
        : isXlsx
        ? const Color(0xff10B981)
        : isDocx
        ? const Color(0xff3B82F6)
        : const Color(0xff64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0f172a).withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // File Icon Box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              fileIcon,
              color: themeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Title / Subtitle / Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.tittle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: badgeTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle == "OTHER FILE" ? "Notes" : item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionIconBtn(
                Icons.download_rounded,
                () => downloadFileAsPdf(
                  url: item.fileUrl,
                  fileName: item.tittle,
                ),
              ),
              const SizedBox(width: 8),
              _buildActionIconBtn(
                Icons.print_rounded,
                () => printFileAsPdf(item.fileUrl),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (val) {
                  final controller = ref.read(
                    timetableAndOtherFilesPageControllerProvider,
                  );
                  if (val == 'delete') {
                    _showDeleteConfirmationDialog(
                      context: context,
                      title: "Delete File?",
                      message: "Are you sure you want to delete '${item.tittle}'? This action cannot be undone.",
                      onConfirm: () => controller.deleteOtherFiles(item.id),
                    );
                  }
                  if (val == 'edit') {
                    _showEditTitleDialog(context, item);
                  }
                },
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: Color(0xff64748B),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text("Edit")),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      "Delete",
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddNewFileListTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherFilesAddingScreen(
            teacherId: widget.teacherId,
            classNo: widget.classNo,
            division: widget.division,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xffF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xffCBD5E1),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xffE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: Color(0xff1D9BF0),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Add New File',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff475569),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Upload doc, pdf or sheet',
                  style: TextStyle(fontSize: 10, color: Color(0xff94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xffCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDial(BuildContext context) {
    return SpeedDialFabWidget(
      primaryIconCollapse: Icons.clear_rounded,
      primaryIconExpand: Icons.add_rounded,
      secondaryIconsList: const [Icons.calendar_month_rounded, Icons.file_copy_rounded],
      secondaryIconsText: const ["TimeTable", "Notes"],
      secondaryIconsOnPress: [
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TimeTableLayoutMakerPage(teacherId: widget.teacherId),
          ),
        ),
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherFilesAddingScreen(
              teacherId: widget.teacherId,
              classNo: widget.classNo,
              division: widget.division,
            ),
          ),
        ),
      ],
      primaryBackgroundColor: const Color(0xff1D9BF0),
    );
  }

  // --- Dialog Helpers ---

  void _showEditTitleDialog(BuildContext context, OtherFilesModel item) {
    final editController = TextEditingController(text: item.tittle);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: const [
              Icon(Icons.edit_rounded, color: Color(0xff1D9BF0), size: 24),
              SizedBox(width: 10),
              Text(
                "Edit File Title",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xff1E293B)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Document Name",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff64748B)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: editController,
                style: const TextStyle(fontSize: 14, color: Color(0xff1E293B)),
                decoration: InputDecoration(
                  hintText: "Enter new file title",
                  hintStyle: const TextStyle(color: Color(0xff94A3B8)),
                  filled: true,
                  fillColor: const Color(0xffF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xffE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xff1D9BF0), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel", 
                style: TextStyle(color: Color(0xff64748B), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff4F46E5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final newTitle = editController.text.trim();
                if (newTitle.isNotEmpty) {
                  ref
                      .read(timetableAndOtherFilesPageControllerProvider)
                      .updateTitleOtherFiles(item.id, newTitle);
                  Navigator.pop(dialogContext);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Title cannot be empty"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text(
                "Delete Confirmation",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xff1E293B)),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xff475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel", 
                style: TextStyle(color: Color(0xff64748B), fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                onConfirm();
                Navigator.pop(dialogContext);
              },
              child: const Text("Delete Permanently", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
