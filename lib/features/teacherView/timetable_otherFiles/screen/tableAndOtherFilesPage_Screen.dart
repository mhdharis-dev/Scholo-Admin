import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scholo_admin/features/teacherView/timetable_otherFiles/screen/timetableLayoutMaker.dart';
import 'package:speed_dial_fab/speed_dial_fab.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/otherFiles_model.dart';
import '../../../../models/timeTable_model.dart';
import '../controller/tableAndOtherFilesPag_controller.dart';
import 'otherFilesAddingScreen.dart';

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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final otherFilesAsync = ref.watch(otherFilesListProvider(widget.teacherId));
    final timetablesAsync = ref.watch(timetablesListProvider({
      'classNo': widget.classNo.toString(),
      'division': widget.division,
      'teacherId': widget.teacherId,
    }));

    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Academic Timetables ────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLeftHeader(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: timetablesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) {
                        log(e.toString());
                        return Text("Error: $e");
                      },
                      data: (tables) => tables.isEmpty
                          ? _buildEmptyState("No Timetables Found")
                          : ListView.separated(
                              itemCount: tables.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  _buildTimetableCard(context, tables[i]),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 28),

            // ── RIGHT: Document Vault ────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRightHeader(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: otherFilesAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text("Error: $e"),
                      data: (files) {
                        final items = <Widget>[
                          ...files.map((f) => _buildDocumentCard(f)),
                          _buildAddNewFileCard(),
                        ];

                        return _isGridView
                            ? GridView.count(
                                crossAxisCount: 3,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.0,
                                children: items,
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) => items[i],
                              );
                      },
                    ),
                  ),
                ],
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
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Academic Timetables',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xff111827),
              ),
            ),
            Text(
              'Current & upcoming semester schedules',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRightHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Vault',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xff111827),
              ),
            ),
            Text(
              'High-fidelity repository for all academic records',
              style: TextStyle(fontSize: 12, color: Color(0xff6B7280)),
            ),
          ],
        ),
        _buildViewToggle(),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Row(
        children: [
          _buildToggleBtn(
            icon: Icons.grid_view_rounded,
            selected: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
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
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? const Color(0xff2563EB) : const Color(0xff9CA3AF),
        ),
      ),
    );
  }

  Widget _buildTimetableCard(BuildContext context, TimetableModel item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: Color(0xff2563EB),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {},
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xff9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.timetableName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xff111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Time Table',
            style: const TextStyle(fontSize: 12, color: Color(0xff6B7280)),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TimeTableLayoutMakerPage(teacherId: widget.teacherId),
              ),
            ),
            child: const Text(
              'View Schedule →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xff2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(OtherFilesModel item) {
    final url = item.fileUrl?.toLowerCase() ?? '';
    final isImage =
        url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
    final isPdf = url.contains('.pdf');
    final isXlsx = url.contains('.xlsx') || url.contains('.xls');
    final isDocx = url.contains('.docx') || url.contains('.doc');

    final iconColor = isPdf
        ? const Color(0xffDC2626)
        : isXlsx
        ? const Color(0xff16A34A)
        : isDocx
        ? const Color(0xff2563EB)
        : const Color(0xff6B7280);

    final fileIcon = isPdf
        ? Icons.picture_as_pdf_outlined
        : isXlsx
        ? Icons.table_chart_outlined
        : isDocx
        ? Icons.description_outlined
        : isImage
        ? Icons.image_outlined
        : Icons.insert_drive_file_outlined;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: isImage && (item.fileUrl?.isNotEmpty ?? false)
                  ? Image.network(
                      item.fileUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildFileIconPlaceholder(fileIcon, iconColor),
                    )
                  : _buildFileIconPlaceholder(fileIcon, iconColor),
            ),
          ),

          // Info + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xff111827),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff9CA3AF),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildActionIconBtn(
                      Icons.download_outlined,
                      () => downloadFileAsPdf(
                        url: item.fileUrl ?? '',
                        fileName: item.tittle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildActionIconBtn(
                      Icons.share_outlined,
                      () => printFileAsPdf(item.fileUrl ?? ''),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        final controller = ref.read(
                          timetableAndOtherFilesPageControllerProvider,
                        );
                        if (val == 'delete') {
                          controller.deleteOtherFiles(item.id);
                        }
                        if (val == 'edit') {
                          controller.updateTitleOtherFiles(
                            item.id,
                            "New Title File",
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Color(0xff6B7280),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text("Edit")),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            "Delete",
                            style: TextStyle(color: Colors.red),
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

  Widget _buildFileIconPlaceholder(IconData icon, Color color) {
    return Container(
      width: double.infinity,
      color: const Color(0xffF9FAFB),
      child: Center(child: Icon(icon, size: 42, color: color)),
    );
  }

  Widget _buildActionIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xffF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xffE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: const Color(0xff374151)),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffD1D5DB), width: 1.5),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 32,
                color: Color(0xff9CA3AF),
              ),
              SizedBox(height: 8),
              Text(
                'Add New File',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Text(msg, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildSpeedDial(BuildContext context) {
    return SpeedDialFabWidget(
      primaryIconCollapse: Icons.clear,
      primaryIconExpand: Icons.add,
      secondaryIconsList: [Icons.calendar_month_outlined, Icons.file_copy],
      secondaryIconsText: ["TimeTable", "Other Files"],
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
      primaryBackgroundColor: Colors.blue.shade600,
    );
  }
}
