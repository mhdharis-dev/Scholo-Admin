// fee_collection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constant/firebase_constant.dart';
import '../controller/fee_collection_controller.dart';

class FeeCollectionPage extends ConsumerStatefulWidget {
  final String teacherId;
  final String description;

  const FeeCollectionPage({
    super.key,
    required this.teacherId,
    required this.description,
  });

  @override
  ConsumerState<FeeCollectionPage> createState() => _FeeCollectionPageState();
}

class _FeeCollectionPageState extends ConsumerState<FeeCollectionPage> {
  List<Map<String, dynamic>> studentDetails = [];
  int totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  // 🔥 Fetch full student details
  Future<void> _fetchStudentDetails() async {
    final snapshot = await FirebaseFirestore.instance
        .schoolCollection(FirebaseConstant.student)
        .where("delete", isEqualTo: false)
        .where("teacherId", isEqualTo: widget.teacherId)
        .get();

    final list = snapshot.docs.map((doc) {
      return {
        "studentId": doc["studentId"] ?? "",
        "studentName": doc["studentName"] ?? "",
        "imageUrl": doc["imageUrl"] ?? "",
        "rollNo": doc["rollNo"] ?? "",
      };
    }).toList();

    setState(() {
      studentDetails = list;
      totalStudents = list.length;
    });
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    if (ts is Timestamp) {
      final d = ts.toDate();
      return "${d.day}/${d.month}/${d.year}";
    }
    return ts.toString();
  }

  Widget completedButton(Map<String, dynamic> feeData) {
    final isCompleted = feeData["completed"] == true;

    return TextButton.icon(
      style: TextButton.styleFrom(
        backgroundColor: isCompleted ? Colors.green : const Color(0xff1193D4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () async {
        await ref.read(toggleCompletedProvider)(
          description: feeData["description"],
          classNo: int.parse(feeData["classNo"].toString()),
          division: feeData["division"],
          currentValue: isCompleted,
        );
      },
      label: Text(
        isCompleted ? "Completed" : "Non-Completed",
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(teacherDetailsProvider(widget.teacherId));
    final feesAsync = ref.watch(feesProvider(widget.teacherId));
    final updateStudent = ref.watch(updateStudentCollectedProvider);

    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      body: teacherAsync.when(
        data: (teacher) {
          if (teacher == null) {
            return const Center(child: Text("Teacher not found"));
          }

          return feesAsync.when(
            data: (fees) {
              final fee = fees.firstWhere(
                (f) =>
                    f["description"] == widget.description &&
                    f["classNo"].toString() == teacher.classNo.toString() &&
                    f["division"].toString() == teacher.division.toString(),
                orElse: () => {},
              );

              if (fee.isEmpty) {
                return const Center(child: Text("Fee not found"));
              }

              // --------------------------
              // MERGE + SORT BY ROLL NUMBER
              // --------------------------
              final studentsRaw = List<Map<String, dynamic>>.from(
                fee["students"] ?? [],
              );

              final students = studentsRaw.map((s) {
                final sid = s["id"].toString();

                final match = studentDetails.firstWhere(
                  (m) => m["studentId"].toString() == sid,
                  orElse: () => {},
                );

                return {
                  ...s,
                  "studentName": match["studentName"] ?? s["name"],
                  "imageUrl": match["imageUrl"] ?? "",
                  "rollNo": match["rollNo"] ?? "",
                };
              }).toList();

              // Sort by rollNo
              students.sort((a, b) {
                final ra = int.tryParse(a["rollNo"].toString()) ?? 9999;
                final rb = int.tryParse(b["rollNo"].toString()) ?? 9999;
                return ra.compareTo(rb);
              });

              final perAmount = (fee["fee"] ?? fee["amount"] ?? 0);
              final amountInt = perAmount is num
                  ? perAmount.toInt()
                  : int.tryParse(perAmount.toString()) ?? 0;

              final collectedCount = students
                  .where((s) => (s["collected"] ?? false))
                  .length;
              final totalCollectedAmount = collectedCount * amountInt;

              final createdDate = _formatDate(fee["createdDate"]);

              // ------------------------------------------------
              // UI
              // ------------------------------------------------
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        const Text(
                          "Fee Collection Details",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: completedButton(fee),
                        )
                      ],
                    ),
                    const SizedBox(height: 20),

                    _header(createdDate, fee["description"].toString()),

                    const SizedBox(height: 20),

                    // Stats
                    Row(
                      children: [
                        _statCard("Fees Amount", "₹$amountInt"),
                        const SizedBox(width: 12),
                        _statCard(
                          "Total Collected",
                          "₹$totalCollectedAmount",
                          valueColor: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _statCard("Total Students", "$totalStudents"),
                        const SizedBox(width: 12),
                        _statCard("Collected Students", "$collectedCount"),
                      ],
                    ),

                    const SizedBox(height: 25),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black12.withValues(alpha: 0.04), blurRadius: 8),
                        ],
                      ),
                      child: Column(
                        children: [
                          _tableHeader(),
                          const Divider(height: 30),

                          ...students.asMap().entries.map((entry) {
                            final index = entry.key;
                            final student = entry.value;
                            final collected = student["collected"] == true;

                            return _studentTile(
                              student: student,
                              collected: collected,
                              index: index,
                              fee: fee,
                              amountInt: amountInt,
                              context: context,
                              updateStudent: updateStudent,
                            );
                          }),
                        ],
                      ),
                    ),

                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("Error: $e")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  // ---------------- UI WIDGETS ----------------

  Widget _studentTile({
    required Map student,
    required bool collected,
    required int index,
    required Map fee,
    required int amountInt,
    required BuildContext context,
    required var updateStudent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: (student["imageUrl"] ?? "").isNotEmpty
                      ? NetworkImage(student["imageUrl"])
                      : null,
                  child: (student["imageUrl"] ?? "").isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student["studentName"],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Roll No: ${student["rollNo"]}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // STATUS
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: collected
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  collected ? "Paid" : "Unpaid",
                  style: TextStyle(
                    color: collected
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // ACTION
          Expanded(
            flex: 1,
            child: Center(
              child: collected
                  ? GestureDetector(
                      onTap: () => _showUnpaidDialog(
                        context,
                        fee,
                        index,
                        amountInt,
                        updateStudent,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Collected",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () async {
                        await updateStudent(
                          description: fee['description'],
                          classNo: fee['classNo'].toString(),
                          division: fee['division'].toString(),
                          studentIndex: index,
                          collected: true,
                          perStudentAmount: amountInt,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text("Collect"),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- HEADER
  Widget _header(String createdDate, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black12.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Created Date"),
                const SizedBox(height: 6),
                _topField(createdDate),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Description"),
                const SizedBox(height: 6),
                _topField(description),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Row(
      children: const [
        Expanded(
          flex: 3,
          child: Text(
            "STUDENT NAME",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            "STATUS",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            "ACTION",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showUnpaidDialog(
    BuildContext ctx,
    Map fee,
    int index,
    int amountInt,
    var updateStudent,
  ) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text("Already Collected"),
        content: const Text("You collected this fee. Mark unpaid?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await updateStudent(
                description: fee['description'].toString(),
                classNo: fee['classNo'].toString(),
                division: fee['division'].toString(),
                studentIndex: index,
                collected: false,
                perStudentAmount: amountInt,
              );
            },
            child: const Text("Mark Unpaid"),
          ),
        ],
      ),
    );
  }

  Widget _topField(String val) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          val,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value, {
    Color valueColor = Colors.black,
  }) {
    return Expanded(
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
