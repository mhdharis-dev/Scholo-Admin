import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:alert_info/alert_info.dart';
import 'package:scholo_admin/models/notification_model.dart';
import 'package:scholo_admin/models/teacher_model.dart';
import 'package:scholo_admin/models/students_model.dart';
import 'package:scholo_admin/models/class_model.dart';
import 'package:scholo_admin/features/teachers/controller/teacher_controller.dart';
import 'package:scholo_admin/features/students/controller/student_controller.dart';
import 'package:scholo_admin/features/teacherView/class_dashbord/controller/class_wise_teacher_view_controller.dart';
import 'package:scholo_admin/features/notifications/controller/notification_controller.dart';
import 'package:scholo_admin/core/config/session_manager.dart';

// ── 📄 ON-SCREEN LIVE PDF VIEWER (BLOB SAME-ORIGIN & CLOUDINARY CONVERSION) ─
class PdfEmbeddedViewer extends StatefulWidget {
  final String url;
  final String engine; // 'direct', 'cloud_image', 'pdfjs'
  const PdfEmbeddedViewer({
    super.key,
    required this.url,
    this.engine = 'cloud_image',
  });

  @override
  State<PdfEmbeddedViewer> createState() => _PdfEmbeddedViewerState();
}

class _PdfEmbeddedViewerState extends State<PdfEmbeddedViewer> {
  late String _viewId;
  String? _blobUrl;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(covariant PdfEmbeddedViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.engine != widget.engine) {
      _loadPdf();
    }
  }

  @override
  void dispose() {
    if (_blobUrl != null && kIsWeb) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (widget.engine == 'cloud_image') {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        if (_blobUrl != null) {
          html.Url.revokeObjectUrl(_blobUrl!);
          _blobUrl = null;
        }

        String finalViewerUrl = widget.url;

        if (widget.engine == 'direct') {
          // Fetch raw PDF bytes via HTTP GET and wrap into Same-Origin Blob URL
          final response = await http.get(Uri.parse(widget.url));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final blob = html.Blob([response.bodyBytes], 'application/pdf');
            _blobUrl = html.Url.createObjectUrlFromBlob(blob);
            finalViewerUrl = _blobUrl!;
          } else {
            throw Exception('HTTP status code ${response.statusCode}');
          }
        } else if (widget.engine == 'pdfjs') {
          finalViewerUrl = 'https://mozilla.github.io/pdf.js/web/viewer.html?file=${Uri.encodeComponent(widget.url)}';
        }

        _viewId = 'pdf-iframe-${widget.url.hashCode}-${widget.engine}-${DateTime.now().millisecondsSinceEpoch}';

        ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
          final iframe = html.IFrameElement()
            ..src = finalViewerUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          return iframe;
        });
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.engine == 'cloud_image') {
      // Convert Cloudinary .pdf URL to .jpg image preview
      String imageUrl = widget.url;
      if (imageUrl.toLowerCase().endsWith('.pdf')) {
        imageUrl = imageUrl.substring(0, imageUrl.length - 4) + '.jpg';
      }

      return Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Color(0xFF1193D4)));
            },
            errorBuilder: (ctx, err, stack) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 48, color: Colors.white70),
                SizedBox(height: 8),
                Text("Failed to render PDF page image", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1193D4)),
            SizedBox(height: 14),
            Text(
              "Loading PDF Document on screen...",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 44, color: Colors.orangeAccent),
            const SizedBox(height: 12),
            const Text(
              "Failed to load PDF bytes directly",
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1193D4), foregroundColor: Colors.white),
              onPressed: _loadPdf,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text("Retry Loading"),
            ),
          ],
        ),
      );
    }

    if (kIsWeb) {
      return HtmlElementView(key: ValueKey(_viewId), viewType: _viewId);
    }

    return Center(
      child: SelectableText(
        'PDF Document URL: ${widget.url}',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _selectedCategoryFilter = 'All';
  String _selectedAudienceMode = 'All School';
  String _selectedCategory = 'General';
  String _selectedClass = '';

  // ✏️ Edit Notification State
  NotificationModel? _editingNotification;

  // 🔹 Multi-Attachment Draft Queue (Multiple Images, PDFs, Web Links)
  List<NotificationAttachmentItem> _draftAttachments = [];

  // Multi-selection states
  List<TeacherModel> _selectedTeachers = [];
  List<StudentsModel> _selectedStudents = [];

  // Custom multi-target mode checkable flags
  bool _customTargetTeachers = false;
  bool _customTargetStudents = false;
  bool _customTargetParents = false;
  bool _customTargetClass = false;

  bool _isSending = false;
  bool _isUploadingFile = false;

  final List<String> _categoryFilters = [
    'All',
    'General',
    'Urgent',
    'Event',
    'Exam',
    'Fee'
  ];

  final List<String> _audienceModes = [
    'All School',
    'All Teachers',
    'All Parents',
    'All Students',
    'Specific Class',
    'Specific Teacher(s)',
    'Specific Student(s)',
    'Custom (Multiple Targets)',
  ];

  final List<Map<String, dynamic>> _categories = [
    {'name': 'General', 'icon': Icons.campaign_rounded, 'color': const Color(0xFF3B82F6)},
    {'name': 'Urgent', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFEF4444)},
    {'name': 'Event', 'icon': Icons.event_rounded, 'color': const Color(0xFF8B5CF6)},
    {'name': 'Exam', 'icon': Icons.assignment_turned_in_rounded, 'color': const Color(0xFFF59E0B)},
    {'name': 'Fee', 'icon': Icons.payments_rounded, 'color': const Color(0xFF10B981)},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final teachersAsync = ref.watch(teacherControllerProvider);
    final studentsAsync = ref.watch(studentControllerProvider);
    final classesAsync = ref.watch(classesStreamProvider);

    final isWide = MediaQuery.of(context).size.width > 900;
    final teachers = teachersAsync.value ?? [];
    final students = studentsAsync.value ?? [];
    final classes = classesAsync.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: notificationsAsync.when(
        data: (notifications) {
          return isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildNotificationFeed(notifications, teachers, students),
                    ),
                    const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildBroadcastCreationPanel(teachers, students, classes),
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildBroadcastCreationPanel(teachers, students, classes),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 650,
                        child: _buildNotificationFeed(notifications, teachers, students),
                      ),
                    ],
                  ),
                );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1193D4)),
        ),
        error: (err, stack) => Center(
          child: SelectableText(
            'Error loading notifications: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  // ── LEFT: Notification Feed ─────────────────────────────────────────
  Widget _buildNotificationFeed(
    List<NotificationModel> notifications,
    List<TeacherModel> teachers,
    List<StudentsModel> students,
  ) {
    final searchQuery = _searchController.text.trim().toLowerCase();
    final filtered = notifications.where((n) {
      final matchesSearch = searchQuery.isEmpty ||
          n.title.toLowerCase().contains(searchQuery) ||
          n.body.toLowerCase().contains(searchQuery) ||
          n.category.toLowerCase().contains(searchQuery) ||
          n.attachments.any((a) => a.name.toLowerCase().contains(searchQuery));

      final matchesCategory = _selectedCategoryFilter == 'All' ||
          n.category.toLowerCase() == _selectedCategoryFilter.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationModel>> groups = {
      'TODAY': [],
      'YESTERDAY': [],
      'EARLIER': [],
    };

    for (final item in filtered) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (itemDate.isAtSameMomentAs(today)) {
        groups['TODAY']!.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        groups['YESTERDAY']!.add(item);
      } else {
        groups['EARLIER']!.add(item);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Notifications & Broadcasts",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Manage and monitor active school alerts (${filtered.length} total)",
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: IconButton(
                  tooltip: 'Refresh Notifications',
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF1193D4)),
                  onPressed: () {
                    ref.invalidate(notificationsStreamProvider);
                  },
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search title, message, attached files, or links...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Category Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categoryFilters.map((cat) {
                final isSelected = _selectedCategoryFilter == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryFilter = cat;
                      });
                    },
                    selectedColor: const Color(0xFF1193D4),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF1193D4) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Grouped List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: groups.entries.where((e) => e.value.isNotEmpty).map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: entry.key == 'TODAY'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...entry.value.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildNotificationCard(item, teachers, students),
                            )),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            "No Notifications Found",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            "Send a new broadcast or change your filter search.",
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Notification Card Item ──────────────────────────────────────────
  Widget _buildNotificationCard(
    NotificationModel item,
    List<TeacherModel> teachers,
    List<StudentsModel> students,
  ) {
    Color themeColor;
    IconData categoryIcon;

    switch (item.category.toLowerCase()) {
      case 'urgent':
        themeColor = const Color(0xFFEF4444);
        categoryIcon = Icons.warning_amber_rounded;
        break;
      case 'event':
        themeColor = const Color(0xFF8B5CF6);
        categoryIcon = Icons.event_rounded;
        break;
      case 'exam':
        themeColor = const Color(0xFFF59E0B);
        categoryIcon = Icons.assignment_turned_in_rounded;
        break;
      case 'fee':
        themeColor = const Color(0xFF10B981);
        categoryIcon = Icons.payments_rounded;
        break;
      default:
        themeColor = const Color(0xFF3B82F6);
        categoryIcon = Icons.campaign_rounded;
        break;
    }

    final formattedTime =
        "${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} at ${_formatTime(item.createdAt)}";

    final isCurrentlyEditing = _editingNotification?.id == item.id;

    return Container(
      decoration: BoxDecoration(
        color: isCurrentlyEditing ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentlyEditing ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          width: isCurrentlyEditing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoryIcon, color: themeColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedTime,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),

                // ✏️ Edit & Delete Popup Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                  onSelected: (val) async {
                    if (val == 'edit') {
                      _startEditingNotification(item, teachers, students);
                    } else if (val == 'delete') {
                      _confirmDeleteNotification(item.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Color(0xFF1193D4), size: 18),
                          SizedBox(width: 8),
                          Text('Edit Notification', style: TextStyle(color: Color(0xFF1193D4), fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Notification', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message Body
            Text(
              item.body,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // 🔹 MULTI-ATTACHMENT RENDERING CARD
            if (item.attachments.isNotEmpty) ...[
              _buildMultiAttachmentRenderer(item.attachments),
              const SizedBox(height: 12),
            ],

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),

            // Audience Target Badge Row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildAudienceBadge(item),
                if (item.senderName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          "By ${item.senderName}",
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Multi-Attachment Renderer ──────────────────────────────────────
  Widget _buildMultiAttachmentRenderer(List<NotificationAttachmentItem> attachments) {
    final images = attachments.where((a) => a.type == 'image').toList();
    final pdfs = attachments.where((a) => a.type == 'pdf').toList();
    final links = attachments.where((a) => a.type == 'link').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖼️ Image Attachments Grid / List (Opens Center Modal Sheet on same tab)
        if (images.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: images.map((img) {
              return GestureDetector(
                onTap: () => _showMediaViewerModal(
                  context: context,
                  url: img.url,
                  type: 'image',
                  title: img.name,
                ),
                child: Container(
                  width: images.length == 1 ? double.infinity : 150,
                  height: images.length == 1 ? 200 : 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      img.url,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        // 📄 PDF Documents List (Opens Center Modal Sheet on same tab)
        if (pdfs.isNotEmpty) ...[
          ...pdfs.map((pdf) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        pdf.name.isNotEmpty ? pdf.name : "Attached PDF Document",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () => _showMediaViewerModal(
                        context: context,
                        url: pdf.url,
                        type: 'pdf',
                        title: pdf.name,
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 14),
                      label: const Text("View PDF", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        // 🔗 Web Links List
        if (links.isNotEmpty) ...[
          ...links.map((link) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.link_rounded, color: Color(0xFF0284C7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            link.name.isNotEmpty ? link.name : link.url,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF075985)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            link.url,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(link.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, webOnlyWindowName: '_blank');
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text("Open Link", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── 🔹 SAME-TAB CENTER / FULL-SCREEN MEDIA VIEWER MODAL ───────────
  void _showMediaViewerModal({
    required BuildContext context,
    required String url,
    required String type, // 'image' or 'pdf'
    required String title,
  }) {
    bool isFullScreen = false;
    String pdfEngine = 'cloud_image'; // 'cloud_image' (Page Image - Default), 'direct' (Blob Reader), 'pdfjs' (Mozilla)

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final screenSize = MediaQuery.of(ctx).size;

          final double modalWidth = isFullScreen ? screenSize.width : (type == 'image' ? 820 : 950);
          final double modalHeight = isFullScreen ? screenSize.height : (type == 'image' ? 600 : 720);
          final EdgeInsets margin = isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(20);
          final BorderRadius radius = isFullScreen ? BorderRadius.zero : BorderRadius.circular(24);

          return Material(
            type: MaterialType.transparency,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: modalWidth,
                height: modalHeight,
                margin: margin,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Column(
                    children: [
                      // Modal Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: type == 'image'
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                                color: type == 'image' ? const Color(0xFF60A5FA) : const Color(0xFFF87171),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isNotEmpty ? title : (type == 'image' ? 'Image Attachment' : 'PDF Document'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (type == 'pdf')
                                    const Text(
                                      "On-Screen PDF Reader",
                                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),

                            // Custom Engine Switcher for PDFs
                            if (type == 'pdf') ...[
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => setModalState(() => pdfEngine = 'direct'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: pdfEngine == 'direct' ? const Color(0xFF1193D4) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Blob PDF',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: pdfEngine == 'direct' ? Colors.white : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setModalState(() => pdfEngine = 'cloud_image'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: pdfEngine == 'cloud_image' ? const Color(0xFF1193D4) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Page Image',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: pdfEngine == 'cloud_image' ? Colors.white : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setModalState(() => pdfEngine = 'pdfjs'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: pdfEngine == 'pdfjs' ? const Color(0xFF1193D4) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'PDF.js Engine',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: pdfEngine == 'pdfjs' ? Colors.white : const Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Header Fullscreen Toggle Icon
                            IconButton(
                              tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                              icon: Icon(
                                isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  isFullScreen = !isFullScreen;
                                });
                              },
                            ),
                            const SizedBox(width: 4),

                            // Close Button
                            IconButton(
                              tooltip: 'Close Viewer',
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Modal Content Body
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFF0F172A),
                          child: type == 'image'
                              ? Center(
                                  child: InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (ctx, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                          child: CircularProgressIndicator(color: Color(0xFF1193D4)),
                                        );
                                      },
                                      errorBuilder: (ctx, err, stack) => const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                                          SizedBox(height: 8),
                                          Text("Failed to load image preview", style: TextStyle(color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : PdfEmbeddedViewer(url: url, engine: pdfEngine),
                        ),
                      ),

                      // Modal Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              type == 'image'
                                  ? '💡 Scroll or pinch to zoom image'
                                  : '📄 On-Screen Reader Mode (${pdfEngine == 'direct' ? 'Blob Reader' : (pdfEngine == 'cloud_image' ? 'Page Image' : 'PDF.js')})',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      isFullScreen = !isFullScreen;
                                    });
                                  },
                                  icon: Icon(
                                    isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    isFullScreen ? 'Exit Full Screen' : 'Full Screen View',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1193D4),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close Viewer'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudienceBadge(NotificationModel item) {
    String label = "Target: ${item.audienceType}";
    IconData icon = Icons.groups_rounded;
    Color color = const Color(0xFF3B82F6);

    if (item.audienceType == 'All School') {
      label = "Target: 🌐 All School (Teachers, Students & Parents)";
      icon = Icons.public_rounded;
      color = const Color(0xFF2563EB);
    } else if (item.audienceType == 'All Teachers') {
      label = "Target: 👨‍🏫 All Teachers";
      icon = Icons.badge_rounded;
      color = const Color(0xFF8B5CF6);
    } else if (item.audienceType == 'All Parents') {
      label = "Target: 👪 All Parents";
      icon = Icons.family_restroom_rounded;
      color = const Color(0xFF059669);
    } else if (item.audienceType == 'All Students') {
      label = "Target: 🎓 All Students";
      icon = Icons.school_rounded;
      color = const Color(0xFFD97706);
    } else if (item.audienceType == 'Specific Class') {
      label = "Target: 🏫 Class ${item.targetClass}";
      icon = Icons.meeting_room_rounded;
      color = const Color(0xFF0284C7);
    } else if (item.audienceType == 'Specific Teacher(s)') {
      label = item.targetTeacherNames.isNotEmpty
          ? "Target 👨‍🏫 Teachers: ${item.targetTeacherNames.join(', ')}"
          : "Target: Specific Teacher(s)";
      icon = Icons.person_search_rounded;
      color = const Color(0xFF7C3AED);
    } else if (item.audienceType == 'Specific Student(s)') {
      label = item.targetStudentNames.isNotEmpty
          ? "Target 🎓 Students: ${item.targetStudentNames.join(', ')}"
          : "Target: Specific Student(s)";
      icon = Icons.face_rounded;
      color = const Color(0xFFEA580C);
    } else if (item.audienceType.contains('Custom')) {
      final parts = <String>[];
      if (item.targetTeacherNames.isNotEmpty) parts.add("Teachers (${item.targetTeacherNames.length})");
      if (item.targetStudentNames.isNotEmpty) parts.add("Students (${item.targetStudentNames.length})");
      if (item.targetAudienceLabels.contains('All Parents')) parts.add("All Parents");
      if (item.targetClass.isNotEmpty) parts.add("Class ${item.targetClass}");

      label = "Target 👥 Custom: ${parts.isEmpty ? 'Multiple Targets' : parts.join(', ')}";
      icon = Icons.checklist_rtl_rounded;
      color = const Color(0xFF0D9488);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RIGHT: Broadcast Creation / Editing Panel ───────────────────────
  Widget _buildBroadcastCreationPanel(
    List<TeacherModel> teachers,
    List<StudentsModel> students,
    List<ClassModel> classes,
  ) {
    final activeClasses = classes.where((c) => !c.delete).toList();
    final classOptions = activeClasses.map((c) => "${c.classNo}${c.division}").toSet().toList()..sort();

    if (classOptions.isNotEmpty && (_selectedClass.isEmpty || !classOptions.contains(_selectedClass))) {
      _selectedClass = classOptions.first;
    }

    final isEditing = _editingNotification != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isEditing ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0), width: isEditing ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Edit Cancel Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEditing ? const Color(0xFF0284C7).withValues(alpha: 0.1) : const Color(0xFF1193D4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.send_time_extension_rounded,
                  color: isEditing ? const Color(0xFF0284C7) : const Color(0xFF1193D4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Broadcast Alert' : 'Create Broadcast',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      isEditing ? 'Modify existing alert details' : 'Send real-time alerts to target audiences',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (isEditing)
                IconButton(
                  tooltip: 'Cancel Editing',
                  icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
                  onPressed: _resetBroadcastForm,
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Priority Category Selector
          const Text(
            'Priority Category',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['name'];
                final Color catColor = cat['color'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(cat['icon'], size: 16, color: isSelected ? Colors.white : catColor),
                    label: Text(cat['name']),
                    selected: isSelected,
                    selectedColor: catColor,
                    backgroundColor: catColor.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : catColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? catColor : catColor.withValues(alpha: 0.2)),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat['name']);
                    },
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // Target Audience Mode Dropdown
          const Text(
            'Target Audience Mode',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAudienceMode,
                isExpanded: true,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                items: _audienceModes.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode.contains('Teacher')
                              ? Icons.badge_rounded
                              : (mode.contains('Student')
                                  ? Icons.school_rounded
                                  : (mode.contains('Parent')
                                      ? Icons.family_restroom_rounded
                                      : (mode.contains('Class')
                                          ? Icons.meeting_room_rounded
                                          : (mode.contains('Custom')
                                              ? Icons.checklist_rtl_rounded
                                              : Icons.public_rounded)))),
                          size: 16,
                          color: const Color(0xFF1193D4),
                        ),
                        const SizedBox(width: 8),
                        Text(mode),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAudienceMode = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dynamic Audience Configuration Inputs
          if (_selectedAudienceMode == 'Specific Class') ...[
            const Text(
              'Select Class & Division',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass.isNotEmpty ? _selectedClass : null,
                  hint: const Text("Select Class"),
                  isExpanded: true,
                  items: classOptions.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedClass = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_selectedAudienceMode == 'Specific Teacher(s)') ...[
            _buildTeacherPickerButton(teachers),
            const SizedBox(height: 14),
          ],

          if (_selectedAudienceMode == 'Specific Student(s)') ...[
            _buildStudentPickerButton(students),
            const SizedBox(height: 14),
          ],

          if (_selectedAudienceMode == 'Custom (Multiple Targets)') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Combine Multiple Target Audiences:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                  ),
                  const SizedBox(height: 8),

                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1193D4),
                    title: const Text('All Parents', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _customTargetParents,
                    onChanged: (val) => setState(() => _customTargetParents = val ?? false),
                  ),

                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1193D4),
                    title: const Text('Specific Class', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _customTargetClass,
                    onChanged: (val) => setState(() => _customTargetClass = val ?? false),
                  ),
                  if (_customTargetClass) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: DropdownButtonFormField<String>(
                        value: _selectedClass.isNotEmpty ? _selectedClass : null,
                        decoration: const InputDecoration(labelText: "Select Class", isDense: true),
                        items: classOptions.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedClass = val);
                        },
                      ),
                    ),
                  ],

                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1193D4),
                    title: const Text('Specific Teacher(s)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _customTargetTeachers,
                    onChanged: (val) => setState(() => _customTargetTeachers = val ?? false),
                  ),
                  if (_customTargetTeachers) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: _buildTeacherPickerButton(teachers),
                    ),
                  ],

                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF1193D4),
                    title: const Text('Specific Student(s)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: _customTargetStudents,
                    onChanged: (val) => setState(() => _customTargetStudents = val ?? false),
                  ),
                  if (_customTargetStudents) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: _buildStudentPickerButton(students),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Title Input
          const Text(
            'Notification Title',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'e.g. Science Exhibition & Exam Circular',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Message Body Input
          const Text(
            'Message Body',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Type your official broadcast details here...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🔹 MULTI-ATTACHMENT CREATION PANEL
          _buildMultiAttachmentBuilderSection(),
          const SizedBox(height: 20),

          // Send / Update Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isSending || _isUploadingFile) ? null : () => _sendBroadcast(context),
              icon: (_isSending || _isUploadingFile)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(isEditing ? Icons.save_rounded : Icons.send_rounded, size: 18),
              label: Text(
                _isUploadingFile
                    ? 'Uploading Attachments...'
                    : (_isSending
                        ? (isEditing ? 'Updating Broadcast...' : 'Publishing Broadcast...')
                        : (isEditing ? 'Update Broadcast' : 'Publish Broadcast')),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? const Color(0xFF0284C7) : const Color(0xFF1193D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── START EDITING NOTIFICATION ───────────────────────────────────────
  void _startEditingNotification(
    NotificationModel item,
    List<TeacherModel> teachers,
    List<StudentsModel> students,
  ) {
    setState(() {
      _editingNotification = item;
      _titleController.text = item.title;
      _bodyController.text = item.body;
      _selectedCategory = item.category;
      _selectedAudienceMode = item.audienceType;
      _selectedClass = item.targetClass;
      _draftAttachments = List.from(item.attachments);

      _selectedTeachers = teachers.where((t) => item.targetTeacherIds.contains(t.id)).toList();
      _selectedStudents = students.where((s) => item.targetStudentIds.contains(s.studentId)).toList();

      _customTargetTeachers = item.targetTeacherIds.isNotEmpty;
      _customTargetStudents = item.targetStudentIds.isNotEmpty;
      _customTargetParents = item.targetAudienceLabels.contains('All Parents');
      _customTargetClass = item.targetClass.isNotEmpty;
    });
  }

  void _resetBroadcastForm() {
    setState(() {
      _editingNotification = null;
      _titleController.clear();
      _bodyController.clear();
      _draftAttachments = [];
      _selectedTeachers = [];
      _selectedStudents = [];
      _selectedAudienceMode = 'All School';
      _selectedCategory = 'General';
      _customTargetTeachers = false;
      _customTargetStudents = false;
      _customTargetParents = false;
      _customTargetClass = false;
    });
  }

  // ── MULTI-ATTACHMENT CREATION BUILDER SECTION ──────────────────────
  Widget _buildMultiAttachmentBuilderSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF1193D4)),
                  SizedBox(width: 6),
                  Text(
                    'Attachments & Links',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              if (_draftAttachments.isNotEmpty)
                Text(
                  '${_draftAttachments.length} attached',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1193D4)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Action Buttons: Add Images, Add PDFs, Add Web Link
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF3B82F6),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _isUploadingFile ? null : () => _pickMultipleFiles('image'),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('+ Add Images', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFEF4444),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _isUploadingFile ? null : () => _pickMultipleFiles('pdf'),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('+ Add PDFs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0284C7),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onPressed: _isUploadingFile ? null : _showAddLinkDialog,
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: const Text('+ Add Web Link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Attachment Queue Preview List
          if (_draftAttachments.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 10),
            Column(
              children: _draftAttachments.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;

                IconData itemIcon = Icons.insert_drive_file_rounded;
                Color itemColor = Colors.blue;

                if (item.type == 'image') {
                  itemIcon = Icons.image_rounded;
                  itemColor = const Color(0xFF3B82F6);
                } else if (item.type == 'pdf') {
                  itemIcon = Icons.picture_as_pdf_rounded;
                  itemColor = const Color(0xFFEF4444);
                } else if (item.type == 'link') {
                  itemIcon = Icons.link_rounded;
                  itemColor = const Color(0xFF0284C7);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(itemIcon, size: 16, color: itemColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.type == 'link')
                                Text(
                                  item.url,
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _draftAttachments.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Multi-File Picker & Upload Handler ────────────────────────────────
  Future<void> _pickMultipleFiles(String type) async {
    try {
      FilePickerResult? result;
      if (type == 'image') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
          allowMultiple: true,
          withData: true,
        );
      } else if (type == 'pdf') {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          allowMultiple: true,
          withData: true,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        setState(() => _isUploadingFile = true);

        for (final file in result.files) {
          try {
            final uploadedUrl = await _uploadAttachmentToCloudinary(file);
            setState(() {
              _draftAttachments.add(NotificationAttachmentItem(
                url: uploadedUrl,
                type: type,
                name: file.name,
              ));
            });
          } catch (uploadErr) {
            if (mounted) {
              _showToast(context, 'Failed to upload ${file.name}: $uploadErr', isError: true);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast(context, 'Failed to select files: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  // ── Add Web Link Dialog ─────────────────────────────────────────────
  void _showAddLinkDialog() {
    final linkUrlCtrl = TextEditingController();
    final linkTitleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Web Link Attachment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: linkTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Link Title (Optional)',
                hintText: 'e.g. Zoom Meeting / Registration Form',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: linkUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Web URL (https://...)',
                hintText: 'e.g. https://forms.google.com/example',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1193D4), foregroundColor: Colors.white),
            onPressed: () {
              final rawUrl = linkUrlCtrl.text.trim();
              final title = linkTitleCtrl.text.trim();

              if (rawUrl.isEmpty) {
                _showToast(context, 'Please enter a URL link', isError: true);
                return;
              }

              final finalUrl = rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';
              final finalTitle = title.isNotEmpty ? title : rawUrl;

              setState(() {
                _draftAttachments.add(NotificationAttachmentItem(
                  url: finalUrl,
                  type: 'link',
                  name: finalTitle,
                ));
              });

              Navigator.pop(ctx);
            },
            child: const Text('Add Link'),
          ),
        ],
      ),
    );
  }

  // ── Cloudinary Upload Helper ───────────────────────────────────────
  Future<String> _uploadAttachmentToCloudinary(PlatformFile file) async {
    const cloudName = 'dxqqnfxvj';
    const uploadPreset = 'file_uploader';

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ));
    } else if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else {
      throw Exception('File data unavailable');
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      final url = data['secure_url'];
      if (url != null && url.toString().isNotEmpty) {
        return url.toString();
      }
    }
    throw Exception('Cloudinary upload failed: ${response.body}');
  }

  // ── Teacher Picker Button & Dialog ──────────────────────────────────
  Widget _buildTeacherPickerButton(List<TeacherModel> teachers) {
    final count = _selectedTeachers.length;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFF1193D4)),
      ),
      onPressed: () => _openTeacherMultiSelectDialog(teachers),
      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFF1193D4)),
      label: Text(
        count == 0
            ? "Select Specific Teacher(s)"
            : "$count Teacher(s) Selected (${_selectedTeachers.map((t) => t.teacherName).join(', ')})",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1193D4)),
      ),
    );
  }

  void _openTeacherMultiSelectDialog(List<TeacherModel> teachers) {
    final activeTeachers = teachers.where((t) => !t.delete).toList();
    List<TeacherModel> tempSelected = List.from(_selectedTeachers);
    String dialogSearch = "";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredTeachers = activeTeachers.where((t) {
            return dialogSearch.isEmpty ||
                t.teacherName.toLowerCase().contains(dialogSearch.toLowerCase()) ||
                t.subject.toLowerCase().contains(dialogSearch.toLowerCase());
          }).toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Target Teacher(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (tempSelected.length == activeTeachers.length) {
                        tempSelected.clear();
                      } else {
                        tempSelected = List.from(activeTeachers);
                      }
                    });
                  },
                  child: Text(tempSelected.length == activeTeachers.length ? "Clear All" : "Select All"),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search teacher name or subject...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (val) => setDialogState(() => dialogSearch = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredTeachers.length,
                      itemBuilder: (ctx, index) {
                        final teacher = filteredTeachers[index];
                        final isChecked = tempSelected.any((t) => t.id == teacher.id);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(teacher.teacherName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(teacher.subject.isNotEmpty ? teacher.subject : 'Teacher', style: const TextStyle(fontSize: 12)),
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected == true) {
                                tempSelected.add(teacher);
                              } else {
                                tempSelected.removeWhere((t) => t.id == teacher.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1193D4), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() => _selectedTeachers = tempSelected);
                  Navigator.pop(ctx);
                },
                child: Text('Done (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Student Picker Button & Dialog ──────────────────────────────────
  Widget _buildStudentPickerButton(List<StudentsModel> students) {
    final count = _selectedStudents.length;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFF1193D4)),
      ),
      onPressed: () => _openStudentMultiSelectDialog(students),
      icon: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF1193D4)),
      label: Text(
        count == 0
            ? "Select Specific Student(s)"
            : "$count Student(s) Selected (${_selectedStudents.map((s) => s.studentName).join(', ')})",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1193D4)),
      ),
    );
  }

  void _openStudentMultiSelectDialog(List<StudentsModel> students) {
    final activeStudents = students.where((s) => !s.delete).toList();
    List<StudentsModel> tempSelected = List.from(_selectedStudents);
    String dialogSearch = "";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filteredStudents = activeStudents.where((s) {
            return dialogSearch.isEmpty ||
                s.studentName.toLowerCase().contains(dialogSearch.toLowerCase()) ||
                s.admissionNo.toString().contains(dialogSearch) ||
                s.classNo.toString().contains(dialogSearch);
          }).toList();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Target Student(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      if (tempSelected.length == activeStudents.length) {
                        tempSelected.clear();
                      } else {
                        tempSelected = List.from(activeStudents);
                      }
                    });
                  },
                  child: Text(tempSelected.length == activeStudents.length ? "Clear All" : "Select All"),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search student name, admission no, class...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (val) => setDialogState(() => dialogSearch = val),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredStudents.length,
                      itemBuilder: (ctx, index) {
                        final student = filteredStudents[index];
                        final isChecked = tempSelected.any((s) => s.studentId == student.studentId);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(student.studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            "Class ${student.classNo}${student.division} • Adm No: ${student.admissionNo} • Roll: ${student.rollNo}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected == true) {
                                tempSelected.add(student);
                              } else {
                                tempSelected.removeWhere((s) => s.studentId == student.studentId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1193D4), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() => _selectedStudents = tempSelected);
                  Navigator.pop(ctx);
                },
                child: Text('Done (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Send or Update Broadcast Logic ─────────────────────────────────
  Future<void> _sendBroadcast(BuildContext context) async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      _showToast(context, 'Please enter a notification title', isError: true);
      return;
    }
    if (body.isEmpty) {
      _showToast(context, 'Please enter a broadcast message body', isError: true);
      return;
    }

    // Validation for specific audience pickers
    if (_selectedAudienceMode == 'Specific Teacher(s)' && _selectedTeachers.isEmpty) {
      _showToast(context, 'Please select at least one target teacher', isError: true);
      return;
    }
    if (_selectedAudienceMode == 'Specific Student(s)' && _selectedStudents.isEmpty) {
      _showToast(context, 'Please select at least one target student', isError: true);
      return;
    }
    if (_selectedAudienceMode == 'Specific Class' && _selectedClass.isEmpty) {
      _showToast(context, 'Please select a target class', isError: true);
      return;
    }

    List<String> targetAudienceLabels = [];
    List<String> targetTeacherIds = [];
    List<String> targetTeacherNames = [];
    List<String> targetStudentIds = [];
    List<String> targetStudentNames = [];
    String targetClassStr = "";

    if (_selectedAudienceMode == 'Specific Teacher(s)') {
      targetTeacherIds = _selectedTeachers.map((t) => t.id).toList();
      targetTeacherNames = _selectedTeachers.map((t) => t.teacherName).toList();
      targetAudienceLabels.add('Specific Teachers');
    } else if (_selectedAudienceMode == 'Specific Student(s)') {
      targetStudentIds = _selectedStudents.map((s) => s.studentId).toList();
      targetStudentNames = _selectedStudents.map((s) => s.studentName).toList();
      targetAudienceLabels.add('Specific Students');
    } else if (_selectedAudienceMode == 'Specific Class') {
      targetClassStr = _selectedClass;
      targetAudienceLabels.add('Class $_selectedClass');
    } else if (_selectedAudienceMode == 'Custom (Multiple Targets)') {
      if (_customTargetTeachers && _selectedTeachers.isNotEmpty) {
        targetTeacherIds = _selectedTeachers.map((t) => t.id).toList();
        targetTeacherNames = _selectedTeachers.map((t) => t.teacherName).toList();
        targetAudienceLabels.add('Specific Teachers');
      }
      if (_customTargetStudents && _selectedStudents.isNotEmpty) {
        targetStudentIds = _selectedStudents.map((s) => s.studentId).toList();
        targetStudentNames = _selectedStudents.map((s) => s.studentName).toList();
        targetAudienceLabels.add('Specific Students');
      }
      if (_customTargetParents) {
        targetAudienceLabels.add('All Parents');
      }
      if (_customTargetClass && _selectedClass.isNotEmpty) {
        targetClassStr = _selectedClass;
        targetAudienceLabels.add('Class $_selectedClass');
      }
    } else {
      targetAudienceLabels.add(_selectedAudienceMode);
    }

    setState(() => _isSending = true);

    try {
      final repo = ref.read(notificationRepositoryProvider);

      String legacyUrl = "";
      String legacyType = "none";
      String legacyName = "";

      if (_draftAttachments.isNotEmpty) {
        legacyUrl = _draftAttachments.first.url;
        legacyType = _draftAttachments.first.type;
        legacyName = _draftAttachments.first.name;
      }

      if (_editingNotification != null) {
        // ✏️ UPDATE EXISTING NOTIFICATION
        final updated = _editingNotification!.copyWith(
          title: title,
          body: body,
          category: _selectedCategory,
          audienceType: _selectedAudienceMode,
          targetAudienceLabels: targetAudienceLabels,
          targetTeacherIds: targetTeacherIds,
          targetTeacherNames: targetTeacherNames,
          targetStudentIds: targetStudentIds,
          targetStudentNames: targetStudentNames,
          targetClass: targetClassStr,
          attachments: _draftAttachments,
          attachmentUrl: legacyUrl,
          attachmentType: legacyType,
          attachmentName: legacyName,
        );

        await repo.updateNotification(updated);
      } else {
        // ➕ CREATE NEW NOTIFICATION
        final newNotification = NotificationModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          body: body,
          category: _selectedCategory,
          audienceType: _selectedAudienceMode,
          targetAudienceLabels: targetAudienceLabels,
          targetTeacherIds: targetTeacherIds,
          targetTeacherNames: targetTeacherNames,
          targetStudentIds: targetStudentIds,
          targetStudentNames: targetStudentNames,
          targetClass: targetClassStr,
          attachments: _draftAttachments,
          attachmentUrl: legacyUrl,
          attachmentType: legacyType,
          attachmentName: legacyName,
          createdAt: DateTime.now(),
          senderName: 'Admin',
          senderId: SessionManager.schoolId,
        );

        await repo.sendNotification(newNotification);
      }

      if (!mounted) return;

      final isEditMode = _editingNotification != null;
      _resetBroadcastForm();

      _showToast(
        context,
        isEditMode ? 'Broadcast updated successfully! ✅' : 'Broadcast alert sent successfully! ✅',
      );
    } catch (e) {
      if (mounted) {
        _showToast(context, 'Failed to save broadcast: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _confirmDeleteNotification(String notificationId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text('Are you sure you want to remove this notification broadcast?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(notificationRepositoryProvider).deleteNotification(notificationId);
              if (mounted) {
                _showToast(context, 'Notification removed');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showToast(BuildContext context, String text, {bool isError = false}) {
    AlertInfo.show(
      context: context,
      text: text,
      typeInfo: isError ? TypeInfo.error : TypeInfo.success,
      iconColor: Colors.white,
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
      textColor: Colors.white,
      position: MessagePosition.top,
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }
}