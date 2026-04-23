import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constant/firebase_constant.dart';

/// ------------------------------------------------
/// MODEL
/// ------------------------------------------------
class RecycleStudent {
  final String name;
  final String id;
  final String admissionId;
  final String className;
  final String imageUrl;
  final int rollNumber;
  final String deletedDate;

  RecycleStudent({
    required this.name,
    required this.id,
    required this.admissionId,
    required this.rollNumber,
    required this.className,
    required this.imageUrl,
    required this.deletedDate,
  });
}

class RecycleTeacher {
  final String name;
  final String id;
  final String employeeId;
  final String className;
  final String imageUrl;
  final String subject;
  final String deletedDate;

  RecycleTeacher({
    required this.name,
    required this.id,
    required this.employeeId,
    required this.className,
    required this.subject,
    required this.imageUrl,
    required this.deletedDate,
  });
}

class RecycleFee {
  final String title;
  final int amount;
  final String className;
  final String deletedDate;
  final String classTooltip;
  final String createdDate;

  RecycleFee({
    required this.title,
    required this.amount,
    required this.className,
    required this.deletedDate,
    required this.classTooltip,
    required this.createdDate,
  });
}

class RecycleEvent {
  final String title;
  final String createdDate;
  final String className;
  final String deletedDate;
  final String? color;
  final String eventDate;

  RecycleEvent({
    required this.title,
    required this.createdDate,
    required this.className,
    required this.deletedDate,
    this.color,
    required this.eventDate,
  });
}

class RecycleMark {
  final String title;
  final String className;
  final String deletedDate;
  final String createdDate;
  final String type;

  RecycleMark({
    required this.title,
    required this.className,
    required this.deletedDate,
    required this.createdDate,
    required this.type,
  });
}

class RecycleOtherFiles {
  final String title;
  final String className;
  final String deletedDate;
  final String createdDate;
  final String fileUrl;
  final String id;

  RecycleOtherFiles({
    required this.title,
    required this.className,
    required this.deletedDate,
    required this.createdDate,
    required this.fileUrl,
    required this.id,
  });
}

/// ------------------------------------------------
/// PROVIDER
/// ------------------------------------------------
String _formatDate(dynamic timestamp) {
  if (timestamp == null) return '';

  final date = (timestamp as Timestamp).toDate();
  return DateFormat('MMM dd, yyyy').format(date);
}

String getClassName(dynamic classes) {
  if (classes == null || classes.isEmpty) return '';

  List<String> classList = List<String>.from(classes);

  // sort numerically
  classList.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

  // required range 5–12
  List<String> fullList = List.generate(
    8,
    (index) => (index + 5).toString(),
  ); // 5 to 12

  // check ALL (5–12)
  if (classList.length == fullList.length &&
      classList.every((e) => fullList.contains(e))) {
    return "ALL";
  }

  return classList.join(",");
}

final recycleStudentsProvider = StreamProvider<List<RecycleStudent>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.student)
      .where('delete', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return RecycleStudent(
            name: data['studentName'] ?? '',
            admissionId: data['admissionNo']?.toString() ?? '',
            id: doc.id,
            className: "${data['classNo'] ?? ''}-${data['division'] ?? ''}",
            deletedDate: data['deletedAt'] is Timestamp
                ? _formatDate(data['deletedAt'])
                : "—",
            rollNumber: data['rollNo'] ?? 0,
            imageUrl: data['imageUrl'] ?? '',
          );
        }).toList();
      });
});

final recycleTeachersProvider = StreamProvider<List<RecycleTeacher>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.teacher)
      .where('delete', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          final classNo = data['classNo'] ?? '';
          final division = data['division'] ?? '';

          return RecycleTeacher(
            id: doc.id,
            name: data['teacherName'] ?? '',
            employeeId: data['employeeId'] ?? '',
            className: "$classNo-$division",
            deletedDate: data['deletedAt'] is Timestamp
                ? _formatDate(data['deletedAt'])
                : "—",
            subject: data['subject'] ?? '',
            imageUrl: data['imageUrl'] ?? '',
          );
        }).toList();
      });
});

final recycleEventsProvider = StreamProvider<List<RecycleEvent>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.events)
      .where('delete', isEqualTo: true)
      .snapshots()
      .map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();

          return RecycleEvent(
            title: data['title'] ?? '',
            createdDate: _formatDate(data['createdAt']),
            className: getClassName(data['classes']),
            deletedDate: data['deletedAt'] != null
                ? _formatDate(data['deletedAt'])
                : "—",
            color: data['color'] ?? '',
            eventDate: _formatDate(data['startDateTime']),
          );
        }).toList();
      });
});

final recycleOtherFilesProvider = StreamProvider<List<RecycleOtherFiles>>((ref,) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.otherFile)
      .where('delete', isEqualTo: true)
      .snapshots()
      .map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          final String className='${data['classNo']}-${data['division']}';
          print(data);

          return RecycleOtherFiles(
            title: data['tittle'] ?? '',
            createdDate: _formatDate(data['uploadedAt']),
            className: className,
            deletedDate: data['deletedDate'] != null
                ? _formatDate(data['deletedDate'])
                : "—",
            fileUrl: data['fileUrl'] ?? '',
            id: doc.id,
          );
        }).toList();
      });
});

final recycleFeesProvider = StreamProvider<List<RecycleFee>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.fees)
      .snapshots()
      .map((snap) {
        final List<RecycleFee> list = [];

        for (final doc in snap.docs) {
          final root = doc.data();

          Map<int, List<String>> classMap = {};
          int amount = 0;

          Timestamp? latestDeletedAt;
          Timestamp? createdAt;

          bool hasDeleted = false;

          root.forEach((classNo, classData) {
            if (classData is Map) {
              classData.forEach((division, feeData) {
                if (feeData is Map) {
                  final isDeleted = feeData['delete'] ?? false;

                  /// take amount once
                  if (amount == 0) {
                    amount = (feeData['fee'] ?? feeData['amount'] ?? 0);
                  }

                  /// take created date
                  createdAt = feeData['createdDate'];

                  if (isDeleted == true) {
                    hasDeleted = true;

                    final deletedAt = feeData['deletedAt'];

                    /// 🔥 track latest deleted date
                    if (deletedAt != null) {
                      if (latestDeletedAt == null ||
                          (deletedAt as Timestamp).toDate().isAfter(
                            latestDeletedAt!.toDate(),
                          )) {
                        latestDeletedAt = deletedAt;
                      }
                    }

                    /// --------------------
                    /// CLASS MAP
                    /// --------------------
                    int cNo = int.tryParse(classNo.toString()) ?? 0;
                    classMap.putIfAbsent(cNo, () => []);
                    classMap[cNo]!.add(division);
                  }
                }
              });
            }
          });

          /// ❌ skip if no deleted data
          if (!hasDeleted) continue;

          /// --------------------
          /// CLASS LOGIC (UNCHANGED)
          /// --------------------
          List<int> classes = classMap.keys.toList()..sort();

          List<int> full = List.generate(8, (i) => i + 5);

          String classText = "";
          String tooltip = "";

          bool isAll =
              classes.length == full.length &&
              classes.every((e) => full.contains(e));

          if (isAll) {
            classText = "ALL";
          } else if (classes.length == 1) {
            classText = classes.first.toString();
            tooltip =
                "${classes.first} : ${classMap[classes.first]!.join(",")}";
          } else {
            bool isContinuous = true;

            for (int i = 0; i < classes.length - 1; i++) {
              if (classes[i] + 1 != classes[i + 1]) {
                isContinuous = false;
                break;
              }
            }

            if (isContinuous) {
              classText = "${classes.first} to ${classes.last}";
            } else if (classes.length == 2) {
              classText = "${classes[0]} & ${classes[1]}";
            } else {
              classText = "${classes.length} Classes";
            }

            tooltip = classMap.entries
                .map((e) => "${e.key} : ${e.value.join(",")}")
                .join("\n");
          }

          list.add(
            RecycleFee(
              title: doc.id,
              amount: amount,
              className: classText,
              classTooltip: tooltip,

              /// ✅ NEW
              deletedDate: latestDeletedAt != null
                  ? _formatDate(latestDeletedAt)
                  : "—",

              createdDate: _formatDate(createdAt),
            ),
          );
        }

        return list;
      });
});

final recycleMarksProvider = StreamProvider<List<RecycleMark>>((ref) {
  return FirebaseFirestore.instance
      .collection(FirebaseConstant.studentsMark)
      .snapshots()
      .map((snap) {
    final List<RecycleMark> list = [];

    for (final doc in snap.docs) {
      final root = doc.data();

      Map<int, List<String>> classMap = {};
      Timestamp? latestDeletedAt;
      Timestamp? createdAt;
      String type = "";
      bool hasDeleted = false;

      /// 🔥 HELPER FUNCTION
      void handleMarkData(dynamic markData, dynamic classNo, String division) {
        if (markData is Map) {
          final isDeleted = markData['delete'] ?? false;

          /// ✅ created date (safe)
          createdAt ??= markData['uploadedAt'] ?? markData['createdDate'];

          if (isDeleted) {
            hasDeleted = true;

            final deletedAt = markData['deletedAt'];

            if (deletedAt != null && deletedAt is Timestamp) {
              if (latestDeletedAt == null ||
                  deletedAt.toDate().isAfter(latestDeletedAt!.toDate())) {
                latestDeletedAt = deletedAt;
              }
            }

            int cNo = int.tryParse(classNo.toString()) ?? 0;
            classMap.putIfAbsent(cNo, () => []);
            classMap[cNo]!.add(division);
          }
        }
      }

      /// 🔥 MAIN LOOP
      root.forEach((classNo, classData) {
        if (classData is Map) {
          classData.forEach((division, divData) {
            if (divData is Map) {

              /// type
              type = divData['markType'] ?? type;

              /// -------------------------
              /// studentsMark
              /// -------------------------
              final studentsMark = divData['studentsMark'];

              if (studentsMark != null) {
                if (studentsMark is Map) {
                  studentsMark.forEach((_, markData) {
                    handleMarkData(markData, classNo, division);
                  });
                } else if (studentsMark is List) {
                  for (var markData in studentsMark) {
                    handleMarkData(markData, classNo, division);
                  }
                }
              }

              /// -------------------------
              /// marks
              /// -------------------------
              final marks = divData['marks'];

              if (marks != null) {
                if (marks is Map) {
                  marks.forEach((_, markData) {
                    handleMarkData(markData, classNo, division);
                  });
                } else if (marks is List) {
                  for (var markData in marks) {
                    handleMarkData(markData, classNo, division);
                  }
                }
              }
            }
          });
        }
      });

      /// ❌ skip if no deleted items
      if (!hasDeleted) continue;

      /// -------------------------
      /// CLASS LOGIC (UNCHANGED)
      /// -------------------------
      List<int> classes = classMap.keys.toList()..sort();
      List<int> full = List.generate(8, (i) => i + 5);

      String classText = "";
      String tooltip = "";

      bool isAll =
          classes.length == full.length &&
              classes.every((e) => full.contains(e));

      if (isAll) {
        classText = "ALL";
      } else if (classes.length == 1) {
        classText = classes.first.toString();
        tooltip = "${classes.first} : ${classMap[classes.first]!.join(",")}";
      } else {
        bool isContinuous = true;

        for (int i = 0; i < classes.length - 1; i++) {
          if (classes[i] + 1 != classes[i + 1]) {
            isContinuous = false;
            break;
          }
        }

        if (isContinuous) {
          classText = "${classes.first} to ${classes.last}";
        } else if (classes.length == 2) {
          classText = "${classes[0]} & ${classes[1]}";
        } else {
          classText = "${classes.length} Classes";
        }

        tooltip = classMap.entries
            .map((e) => "${e.key} : ${e.value.join(",")}")
            .join("\n");
      }

      /// -------------------------
      /// ADD TO LIST
      /// -------------------------
      list.add(
        RecycleMark(
          title: doc.id,
          className: classText,
          type: type,
          createdDate:
          createdAt != null ? _formatDate(createdAt) : "—",
          deletedDate:
          latestDeletedAt != null ? _formatDate(latestDeletedAt) : "—",
        ),
      );
    }

    return list;
  });
});

/// ------------------------------------------------
/// PAGE
/// ------------------------------------------------
class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  int selectedIndex = 2;

  Map<int, DateTime> lastOpened = {};

  void _openFilePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: Container(
            width: double.infinity,
            height: 500,
            child: Column(
              children: [
                /// 🔴 CLOSE BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,color: Colors.white,),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                /// 📄 FILE VIEW
                Expanded(
                  child: _buildFileViewer(url),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int getNewCount(List items, int tabIndex, String Function(dynamic) getDate) {
    final last = lastOpened[tabIndex];

    if (last == null) return items.isNotEmpty ? 1 : 0;

    bool hasNew = items.any((e) {
      final dateStr = getDate(e);

      if (dateStr == "—" || dateStr.isEmpty) return false;

      final date = DateFormat('MMM dd, yyyy').parse(dateStr);

      return date.isAfter(last);
    });

    return hasNew ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(recycleStudentsProvider);
    final teachers = ref.watch(recycleTeachersProvider);
    final fees = ref.watch(recycleFeesProvider);
    final events = ref.watch(recycleEventsProvider);
    final marks = ref.watch(recycleMarksProvider);
    final otherFiles = ref.watch(recycleOtherFilesProvider);

    int total =
        (students.value?.length ?? 0) +
        (teachers.value?.length ?? 0) +
        (fees.value?.length ?? 0) +
        (events.value?.length ?? 0) +
        (marks.value?.length ?? 0) +
        (otherFiles.value?.length ?? 0);

    String formatSize(double bytes) {
      const suffixes = ["B", "KB", "MB", "GB", "TB"];

      int i = 0;
      while (bytes >= 1024 && i < suffixes.length - 1) {
        bytes /= 1024;
        i++;
      }

      return "${bytes.toStringAsFixed(2)} ${suffixes[i]}";
    }

    double estimatedBytes = total * 2048; // 2KB per record approx

    String storage = formatSize(estimatedBytes);

    return Scaffold(
      backgroundColor: const Color(0xfff6f8fb),

      /// ✅ PAGE SCROLL
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Recycle Bin",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Manage and restore deleted records across the system",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    elevation: 0,
                  ), onPressed: () => showEmptyTrashDialog(),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text("Empty Trash"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// INFO CARDS
            Row(
              children: [
                _infoCard(
                  icon: Icons.history,
                  title: "TOTAL ITEMS",
                  value: "$total Records in Trash",
                ),
                const SizedBox(width: 16),
                _infoCard(
                  icon: Icons.storage,
                  title: "STORAGE USED",
                  value: "$storage Recoverable",
                ),
              ],
            ),

            const SizedBox(height: 24),

            /// TABS
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tab(
                      0,
                      Icons.payments_outlined,
                      "Fees",
                      count: fees.hasValue
                          ? getNewCount(
                        fees.value!,
                        0,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                    _tab(
                      1,
                      Icons.event_outlined,
                      "Events",
                      count: events.hasValue
                          ? getNewCount(
                        events.value!,
                        1,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                    _tab(
                      2,
                      Icons.school,
                      "Students",
                      count: students.hasValue
                          ? getNewCount(
                        students.value!,
                        2,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                    _tab(
                      3,
                      Icons.groups_outlined,
                      "Teachers",
                      count: teachers.hasValue
                          ? getNewCount(
                        teachers.value!,
                        3,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                    _tab(
                      4,
                      Icons.star_border,
                      "Student Marks",
                      count: marks.hasValue
                          ? getNewCount(
                        marks.value!,
                        4,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                    _tab(5, Icons.calendar_month_outlined, "Class Timetable",count: 5),
                    _tab(
                      6,
                      Icons.file_copy,
                      "Other Files",
                      count: otherFiles.hasValue
                          ? getNewCount(
                        otherFiles.value!,
                        6,
                            (e) => e.deletedDate,
                      )
                          : 0,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// CONTENT
            _buildContent(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// TAB
  /// ------------------------------------------------
  Widget _tab(int index, IconData icon, String title, {int? count}) {
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          selectedIndex = index;
          lastOpened[index] = DateTime.now(); // ✅ mark as seen
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.blue : Colors.grey),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.blue : Colors.grey,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  "$count",
                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedIndex) {
      case 0:
        final data = ref.watch(recycleFeesProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _feesTable(list),
        );

      case 1:
        final data = ref.watch(recycleEventsProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _eventTable(list),
        );

      case 2:
        final data = ref.watch(recycleStudentsProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _studentsTable(list),
        );

      case 3:
        final data = ref.watch(recycleTeachersProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _teacherTable(list),
        );
      case 4:
        final data = ref.watch(recycleMarksProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _marksTable(list),
        );
      case 6:
        final data = ref.watch(recycleOtherFilesProvider);
        return data.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text("Error: $e"),
          data: (list) => _otherFilesTable(list, _openFilePreview),
        );

      default:
        return _empty("No Data");
    }
  }

  static String limitText(String text, {int max = 13}) {
    if (text.length <= max) return text;
    return "${text.substring(0, max)}...";
  }

  Widget _buildFileViewer(String url) {
    return InteractiveViewer(
      child: Image.network(
        url,
        fit: BoxFit.fill,

        /// ✅ LOADING
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },

        /// ✅ ERROR → NOT IMAGE
        errorBuilder: (context, error, stackTrace) {
          final lower = url.toLowerCase();

          /// PDF fallback
          if (lower.contains("pdf")) {
            return const Center(
              child: Text("PDF preview not supported.\nOpen in browser."),
            );
          }

          return Center(
            child: Text("Preview not available\n$url"),
          );
        },
      ),
    );
  }

  static Widget _action(String text, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
        child:  Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
    color: color.withOpacity(.1),
    borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(color: color)),
    ),
    );
  }

  Future<void> restoreItem(String collection, String docId) async {
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .update({
      'delete': false,
      'deletedAt': null,
    });
  }

  Future<void> showRestoreDialog({
    required BuildContext context,
    required String collection,
    required String docId,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Restore Item"),
        content: const Text("Do you want to restore this item?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(docId)
                  .update({
                'delete': false,
                'deletedAt': null,
              });
              Navigator.pop(context);
            },
            child: const Text("Restore"),
          ),
        ],
      ),
    );
  }

  Future<void> showDeleteDialog({
    required BuildContext context,
    required String collection,
    required String docId,}) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permanent Delete"),
        content: const Text(
          "This action cannot be undone.\nDo you want to delete permanently?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(collection)
                  .doc(docId)
                  .delete();

              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> showEmptyTrashDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Empty Trash"),
        content: const Text(
          "All deleted data will be permanently removed.\nContinue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final firestore = FirebaseFirestore.instance;

              final collections = [
                FirebaseConstant.student,
                FirebaseConstant.teacher,
                FirebaseConstant.events,
                FirebaseConstant.otherFile,
              ];

              for (String col in collections) {
                final snapshot = await firestore
                    .collection(col)
                    .where('delete', isEqualTo: true)
                    .get();

                for (var doc in snapshot.docs) {
                  await doc.reference.delete();
                }
              }

              Navigator.pop(context);
            },
            child: const Text("Empty"),
          ),
        ],
      ),
    );
  }
  /// ------------------------------------------------
  /// STUDENT TABLE (NO SCROLL)
  /// ------------------------------------------------
   Widget _studentsTable(List<RecycleStudent> students) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("NAME", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("ROLL NO", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("ID NUMBER", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          students.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: students.map((student) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage:
                                      (student.imageUrl != null &&
                                          student.imageUrl.isNotEmpty)
                                      ? NetworkImage(student.imageUrl)
                                      : null,
                                  child:
                                      (student.imageUrl == null ||
                                          student.imageUrl.isEmpty)
                                      ? Text(student.name[0])
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: student.name,
                                    child: Text(
                                      limitText(student.name),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(student.rollNumber.toString()),
                          ),
                          Expanded(flex: 2, child: Text("#${student.admissionId}")),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  student.className,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(student.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.student,
                                    docId: student.id,
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.student,
                                    docId: student.id,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

   Widget _teacherTable(List<RecycleTeacher> teachers) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("NAME", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "EMPLOYEE ID",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("SUBJECT", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          teachers.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: teachers.map((teacher) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage:
                                      (teacher.imageUrl != null &&
                                          teacher.imageUrl.isNotEmpty)
                                      ? NetworkImage(teacher.imageUrl)
                                      : null,
                                  child:
                                      (teacher.imageUrl == null ||
                                          teacher.imageUrl.isEmpty)
                                      ? Text(teacher.name[0])
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: teacher.name,
                                    child: Text(
                                      limitText(teacher.name),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text("#${teacher.employeeId}")),
                          Expanded(
                            flex: 2,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.contextMenu,
                              child: Tooltip(
                                waitDuration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(color: Colors.white),
                                message: teacher.subject,
                                child: Text(
                                  limitText(teacher.subject),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  teacher.className,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(teacher.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.teacher,
                                    docId: teacher.id,
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.teacher,
                                    docId: teacher.id,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

   Widget _eventTable(List<RecycleEvent> events) {
    Color hexToColor(String value) {
      value = value.trim();

      // case 1: already 0xff format
      if (value.startsWith("0x")) {
        return Color(int.parse(value));
      }

      // case 2: #ffffff
      if (value.startsWith("#")) {
        value = value.replaceAll("#", "");

        if (value.length == 6) {
          value = "FF$value";
        }

        return Color(int.parse(value, radix: 16));
      }

      // case 3: plain hex (ffffff)
      if (value.length == 6) {
        return Color(int.parse("FF$value", radix: 16));
      }

      // fallback
      return Colors.grey;
    }

    String getDayFromString(String date) {
      return date.split(" ")[1].replaceAll(",", "");
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("TITTLE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("EVENT DATE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "CREATED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          events.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: events.map((event) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: event.color != null
                                      ? hexToColor(event.color!)
                                      : Colors.grey,
                                  child: Center(
                                    child: Text(
                                      getDayFromString(event.eventDate),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: event.title,
                                    child: Text(
                                      limitText(event.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(event.eventDate)),
                          Expanded(flex: 2, child: Text(event.createdDate)),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  event.className,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(event.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.student,
                                    docId: event.title,
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.events,
                                    docId: event.title,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

   Widget _feesTable(List<RecycleFee> fees) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("TITTLE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("PER AMOUNT", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "CREATED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          fees.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: fees.map((fee) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                const SizedBox(width: 9),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: fee.title,
                                    child: Text(
                                      limitText(fee.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(fee.amount.toString())),
                          Expanded(flex: 2, child: Text(fee.createdDate)),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: fee.classTooltip.isEmpty
                                    ? Text(
                                        fee.className,
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : Tooltip(
                                        message: fee.classTooltip,
                                        child: Text(
                                          fee.className,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(fee.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.fees,
                                    docId: fee.title, // ⚠️ doc.id actually
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.fees,
                                    docId: fee.title,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

   Widget _marksTable(List<RecycleMark> marks) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("TITTLE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("TYPE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "CREATED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          marks.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: marks.map((mark) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                const SizedBox(width: 9),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: mark.title,
                                    child: Text(
                                      limitText(mark.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(flex: 2, child: Text(mark.type)),
                          Expanded(flex: 2, child: Text(mark.createdDate)),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  mark.className,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                // mark.classTooltip.isEmpty
                                //     ? Text(
                                //         fee.className,
                                //         style: const TextStyle(fontSize: 12),
                                //       )
                                //     : Tooltip(
                                //         message: fee.classTooltip,
                                //         child: Text(
                                //           fee.className,
                                //           style: const TextStyle(fontSize: 12),
                                //         ),
                                //       ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(mark.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.studentsMark,
                                    docId: mark.title,
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.studentsMark,
                                    docId: mark.title,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

   Widget _otherFilesTable(List<RecycleOtherFiles> otherFiles, Function(BuildContext, String) onOpenFile,) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text("TITTLE", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text("FILE URL", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "CREATED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("CLASS", style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  "DELETED DATE",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text("ACTIONS", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          const Divider(),

          /// ✅ NO ListView — page scroll handles everything
          otherFiles.isEmpty
              ? _empty("No records in recycle bin")
              : Column(
                  children: otherFiles.map((otherFiles) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                const SizedBox(width: 9),
                                MouseRegion(
                                  cursor: SystemMouseCursors.contextMenu,
                                  child: Tooltip(
                                    waitDuration: const Duration(
                                      milliseconds: 300,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      color: Colors.white,
                                    ),
                                    message: otherFiles.title,
                                    child: Text(
                                      limitText(otherFiles.title),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.contextMenu,
                              child: Tooltip(
                                waitDuration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(color: Colors.white),
                                message: otherFiles.fileUrl,
                                child: InkWell(
                                  onTap: () {
                                    onOpenFile(context,otherFiles.fileUrl);
                                  },
                                  child: Text(
                                    limitText(otherFiles.fileUrl),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(otherFiles.createdDate)),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child:  Text(
                                          otherFiles.className,
                                          style: const TextStyle(fontSize: 12),
                                        ),

                                // fee.classTooltip.isEmpty
                                //     ? Text(
                                //         fee.className,
                                //         style: const TextStyle(fontSize: 12),
                                //       )
                                //     : Tooltip(
                                //         message: fee.classTooltip,
                                //         child: Text(
                                //           fee.className,
                                //           style: const TextStyle(fontSize: 12),
                                //         ),
                                //       ),
                              ),
                            ),
                          ),
                          Expanded(flex: 2, child: Text(otherFiles.deletedDate)),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                _action("Restore", Colors.green, () {
                                  showRestoreDialog(
                                    context: context,
                                    collection: FirebaseConstant.otherFile,
                                    docId: otherFiles.id, // ⚠️ fix below
                                  );
                                }),

                                const SizedBox(width: 8),

                                _action("Delete", Colors.red, () {
                                  showDeleteDialog(
                                    context: context,
                                    collection: FirebaseConstant.otherFile,
                                    docId: otherFiles.id,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  static Widget _empty(String text) => Container(
    height: 200,
    alignment: Alignment.center,
    child: Text(
      "$text data will appear here",
      style: const TextStyle(color: Colors.grey),
    ),
  );

  static Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
