import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alert_info/alert_info.dart';
import '../../../models/timeTable_model.dart';
import '../../../models/class_model.dart';
import '../../../auth/controller/login_controller.dart';
import '../../teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import '../controller/timetable_management_controller.dart';
import '../helper/timetable_pdf_helper.dart';
import '../widgets/timetable_detail_modal.dart';
import '../widgets/make_timetable_dialog.dart';

class TimetableManagementScreen extends ConsumerStatefulWidget {
  const TimetableManagementScreen({super.key});

  @override
  ConsumerState<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends ConsumerState<TimetableManagementScreen> {
  String _searchQuery = '';
  String _selectedClassFilter = 'All';
  String _selectedDivisionFilter = 'All';
  bool _isGridView = true;
  bool _isExportingPdf = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TimetableModel> _filterTimetables(List<TimetableModel> list) {
    return list.where((item) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = item.timetableName.toLowerCase().contains(query);
        final teacherMatch = item.classTeacherName.toLowerCase().contains(query);
        final classMatch = "class ${item.classNo}".toLowerCase().contains(query) || item.classNo.toLowerCase().contains(query);
        final divMatch = item.division.toLowerCase().contains(query);
        
        bool subjectMatch = false;
        for (var day in item.workingDays.values) {
          for (var p in day.periods) {
            if ((p.subject?.toLowerCase().contains(query) ?? false) ||
                (p.mainSubject?.toLowerCase().contains(query) ?? false) ||
                (p.teacherName?.toLowerCase().contains(query) ?? false)) {
              subjectMatch = true;
              break;
            }
          }
          if (subjectMatch) break;
        }

        if (!nameMatch && !teacherMatch && !classMatch && !divMatch && !subjectMatch) {
          return false;
        }
      }

      // 2. Class Filter
      if (_selectedClassFilter != 'All') {
        if (item.classNo.trim().toLowerCase() != _selectedClassFilter.trim().toLowerCase()) {
          return false;
        }
      }

      // 3. Division Filter
      if (_selectedDivisionFilter != 'All') {
        if (item.division.trim().toLowerCase() != _selectedDivisionFilter.trim().toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _handleDeleteTimetable(TimetableModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Move to Trash Bin?"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete '${item.timetableName}' for Class ${item.classNo} - ${item.division}? It will be moved to the Trash Bin and can be restored anytime.",
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(timetableManagementControllerProvider.notifier).deleteTimetable(
            classNo: item.classNo,
            division: item.division,
            timetableName: item.timetableName,
          );

      if (mounted) {
        if (success) {
          AlertInfo.show(
            context: context,
            text: "'${item.timetableName}' moved to Trash Bin",
            typeInfo: TypeInfo.success,
            backgroundColor: const Color(0xFF27AE60),
            textColor: Colors.white,
            position: MessagePosition.top,
          );
        } else {
          AlertInfo.show(
            context: context,
            text: "Failed to delete timetable. Please try again.",
            typeInfo: TypeInfo.error,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            position: MessagePosition.top,
          );
        }
      }
    }
  }

  Future<void> _handleExportSummary(List<TimetableModel> timetables) async {
    if (timetables.isEmpty) {
      AlertInfo.show(
        context: context,
        text: "No timetables available to export.",
        typeInfo: TypeInfo.warning,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isExportingPdf = true);
    try {
      final school = ref.read(schoolStreamProvider).value;
      await TimetablePdfHelper.downloadAllTimetablesSummaryPdf(timetables, school: school);
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetablesAsync = ref.watch(realtimeTimetablesStreamProvider);
    final draftsAsync = ref.watch(realtimeDraftTimetablesStreamProvider);
    final classesAsync = ref.watch(classesStreamProvider);
    final school = ref.watch(schoolStreamProvider).value;

    final List<ClassModel> createdClasses = (classesAsync.value ?? <ClassModel>[])
        .where((c) => !c.delete)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ──
            _buildPageHeader(context, timetablesAsync.value ?? [], school),

            const SizedBox(height: 24),

            // ── Metric / Stats Cards ──
            timetablesAsync.when(
              data: (timetables) {
                final drafts = draftsAsync.value ?? [];
                return _buildStatsRow(timetables, drafts);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Search & Filter Controls Card (Showing ONLY Created Classes & Divisions) ──
            _buildFilterCard(createdClasses),

            const SizedBox(height: 24),

            // ── Main Timetables Content Area ──
            timetablesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(color: Color(0xFF1193D4)),
                ),
              ),
              error: (err, stack) => _buildErrorCard(err),
              data: (allTimetables) {
                final filtered = _filterTimetables(allTimetables);
                if (filtered.isEmpty) {
                  return _buildEmptyCard(allTimetables.isEmpty);
                }
                return _isGridView ? _buildGridView(filtered, school) : _buildTableView(filtered, school);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Page Header (Responsive & Clean, with Make Timetable button) ──
  Widget _buildPageHeader(BuildContext context, List<TimetableModel> timetables, dynamic school) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Title + Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  const Text(
                    "Timetable Management",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Live Firestore Sync",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Monitor and manage real-time academic timetables, class period structures, and faculty allocations.",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Action Buttons Row
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Refresh Button
            IconButton(
              tooltip: "Refresh real-time data",
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              onPressed: () {
                ref.invalidate(realtimeTimetablesStreamProvider);
                ref.invalidate(realtimeDraftTimetablesStreamProvider);
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1193D4)),
            ),
            const SizedBox(width: 10),
            // Export Master PDF icon button
            IconButton(
              tooltip: "Export Master Directory PDF",
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              onPressed: _isExportingPdf ? null : () => _handleExportSummary(timetables),
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1193D4)),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 12),
            // Primary "Make Timetable" Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1193D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: () => MakeTimetableDialog.show(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                "Make Timetable",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Metric / Stats Row ──
  Widget _buildStatsRow(List<TimetableModel> timetables, List<dynamic> drafts) {
    final uniqueClasses = <String>{};
    int totalWorkingDaysSchedules = 0;

    for (var tt in timetables) {
      uniqueClasses.add(tt.classNo);
      totalWorkingDaysSchedules += tt.workingDays.values.where((d) => d.status == 'Working Day').length;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final cardWidth = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard(
              title: "Published Timetables",
              value: timetables.length.toString(),
              subtitle: "Active school schedules",
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF1193D4),
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Classes Covered",
              value: uniqueClasses.length.toString(),
              subtitle: "Distinct classes scheduled",
              icon: Icons.school_rounded,
              color: const Color(0xFF10B981),
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Weekly Scheduled Days",
              value: totalWorkingDaysSchedules.toString(),
              subtitle: "Active day-period slots",
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFF8B5CF6),
              width: cardWidth,
            ),
            _buildStatCard(
              title: "Draft Timetables",
              value: drafts.length.toString(),
              subtitle: "Unpublished layouts & drafts",
              icon: Icons.edit_calendar_rounded,
              color: const Color(0xFFF59E0B),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Filter Card (Populated strictly from CREATED classes & divisions) ──
  Widget _buildFilterCard(List<ClassModel> createdClasses) {
    // Collect created class numbers
    final availableClasses = <String>['All'];
    final classNos = createdClasses.map((c) => c.classNo).toSet().toList();
    classNos.sort((a, b) {
      final aNum = int.tryParse(a);
      final bNum = int.tryParse(b);
      if (aNum != null && bNum != null) return aNum.compareTo(bNum);
      return a.compareTo(b);
    });
    availableClasses.addAll(classNos);

    if (!availableClasses.contains(_selectedClassFilter)) {
      _selectedClassFilter = 'All';
    }

    // Collect created divisions (filtered by selected class if one is chosen)
    final availableDivisions = <String>['All'];
    final divSet = createdClasses
        .where((c) => _selectedClassFilter == 'All' || c.classNo == _selectedClassFilter)
        .map((c) => c.division)
        .toSet()
        .toList();
    divSet.sort();
    availableDivisions.addAll(divSet);

    if (!availableDivisions.contains(_selectedDivisionFilter)) {
      _selectedDivisionFilter = 'All';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search box
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: "Search timetable, teacher, class...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1193D4), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1193D4)),
                ),
              ),
            ),
          ),

          // Filters and view switch
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Class dropdown filter (Shows only created classes)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Class: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    DropdownButton<String>(
                      value: _selectedClassFilter,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedClassFilter = val;
                            _selectedDivisionFilter = 'All';
                          });
                        }
                      },
                      items: availableClasses.map((c) {
                        return DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Classes' : "Class $c"));
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Division dropdown filter (Shows only created divisions)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Div: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    DropdownButton<String>(
                      value: _selectedDivisionFilter,
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDivisionFilter = val);
                      },
                      items: availableDivisions.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Divisions' : "Div $d"));
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // View Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
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
              ),
            ],
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? const Color(0xFF1193D4) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  // ── 4. Grid View (With 245px mainAxisExtent to prevent any overflow) ──
  Widget _buildGridView(List<TimetableModel> timetables, dynamic school) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 3
            : (constraints.maxWidth > 750 ? 2 : 1);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: timetables.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            mainAxisExtent: 245,
          ),
          itemBuilder: (ctx, index) {
            final item = timetables[index];
            return _buildTimetableCard(item, school);
          },
        );
      },
    );
  }

  Widget _buildTimetableCard(TimetableModel item, dynamic school) {
    final activeDaysCount = item.workingDays.values.where((d) => d.status == 'Working Day').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Class & Division pill + Action menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1193D4).withValues(alpha: 0.25)),
                ),
                child: Text(
                  "Class ${item.classNo} - ${item.division}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1193D4),
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'view') {
                    TimetableDetailModal.show(context, item);
                  } else if (val == 'pdf') {
                    TimetablePdfHelper.downloadTimetablePdf(item, school: school);
                  } else if (val == 'print') {
                    TimetablePdfHelper.printTimetablePdf(item, school: school);
                  } else if (val == 'delete') {
                    _handleDeleteTimetable(item);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF1193D4)),
                        SizedBox(width: 8),
                        Text("View Schedule"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text("Download PDF"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print_rounded, size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Text("Print"),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text("Delete", style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Timetable Name
          Text(
            item.timetableName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 4),

          // Teacher Name
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.classTeacherName.isNotEmpty ? item.classTeacherName : "No Teacher Assigned",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Schedule meta badges (Working days & periods)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      "$activeDaysCount Days",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      "${item.totalPeriods} Periods",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => TimetableDetailModal.show(context, item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: const [
                      Text(
                        "View Schedule",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1193D4),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1193D4)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: "Download PDF",
                    icon: const Icon(Icons.download_rounded, size: 18),
                    color: const Color(0xFF10B981),
                    splashRadius: 18,
                    onPressed: () => TimetablePdfHelper.downloadTimetablePdf(item, school: school),
                  ),
                  IconButton(
                    tooltip: "Print",
                    icon: const Icon(Icons.print_rounded, size: 18),
                    color: const Color(0xFF64748B),
                    splashRadius: 18,
                    onPressed: () => TimetablePdfHelper.printTimetablePdf(item, school: school),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Table View ──
  Widget _buildTableView(List<TimetableModel> timetables, dynamic school) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: const Color(0xFFF1F5F9),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text("CLASS & DIV", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text("TIMETABLE TITLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text("CLASS TEACHER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("WORKING DAYS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("PERIODS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("CREATED DATE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Table Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: timetables.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, index) {
                final item = timetables[index];
                final activeDaysCount = item.workingDays.values.where((d) => d.status == 'Working Day').length;

                return InkWell(
                  onTap: () => TimetableDetailModal.show(context, item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                    child: Row(
                      children: [
                        // Class & Div
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Class ${item.classNo} - ${item.division}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1193D4)),
                              ),
                            ),
                          ),
                        ),
                        // Title
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.timetableName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                        // Teacher
                        Expanded(
                          flex: 3,
                          child: Text(
                            item.classTeacherName.isNotEmpty ? item.classTeacherName : "-",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          ),
                        ),
                        // Working Days
                        Expanded(
                          flex: 2,
                          child: Text(
                            "$activeDaysCount Days",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        // Periods
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${item.totalPeriods} Periods",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        // Created Date
                        Expanded(
                          flex: 2,
                          child: Text(
                            "${item.createdDate.day}/${item.createdDate.month}/${item.createdDate.year}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                        // Actions
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: "View",
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                color: const Color(0xFF1193D4),
                                onPressed: () => TimetableDetailModal.show(context, item),
                              ),
                              IconButton(
                                tooltip: "PDF",
                                icon: const Icon(Icons.download_rounded, size: 18),
                                color: const Color(0xFF10B981),
                                onPressed: () => TimetablePdfHelper.downloadTimetablePdf(item, school: school),
                              ),
                              IconButton(
                                tooltip: "Print",
                                icon: const Icon(Icons.print_rounded, size: 18),
                                color: const Color(0xFF64748B),
                                onPressed: () => TimetablePdfHelper.printTimetablePdf(item, school: school),
                              ),
                              IconButton(
                                tooltip: "Delete",
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                color: Colors.redAccent,
                                onPressed: () => _handleDeleteTimetable(item),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Empty State ──
  Widget _buildEmptyCard(bool isTotalEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1193D4).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.table_chart_outlined, size: 48, color: Color(0xFF1193D4)),
          ),
          const SizedBox(height: 16),
          Text(
            isTotalEmpty ? "No Timetables Found in Firestore" : "No Matching Timetables",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            isTotalEmpty
                ? "There are currently no active timetables published in the database."
                : "No timetables matched your search query or filter selection.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1193D4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => MakeTimetableDialog.show(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("Make Timetable", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── 7. Error State ──
  Widget _buildErrorCard(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            "Failed to load timetables from Firestore",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent),
          ),
          const SizedBox(height: 4),
          Text(
            error.toString(),
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1193D4),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref.invalidate(realtimeTimetablesStreamProvider);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
