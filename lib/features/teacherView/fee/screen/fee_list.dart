// lib/features/teacherView/fee/screen/feelist_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constant/firebase_constant.dart';
import '../../../../core/constant/image_constant.dart';
import '../../../../models/fees_model.dart';
import '../../../../models/teacher_model.dart';
import '../controller/feelist_controller.dart';
import '../repository/feelist_repository.dart';
import 'fee_collection.dart';

class FeeListScreen extends ConsumerStatefulWidget {
  final String teacherId;
  const FeeListScreen({super.key, required this.teacherId});

  @override
  ConsumerState<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends ConsumerState<FeeListScreen> {
  // Combined Add/Edit bottom sheet
  Future<void> _showFeeBottomSheet({
    required TeacherModel teacher,
    FeeModel? existingFee,
  }) async {
    final descriptionController = TextEditingController(text: existingFee?.description ?? "");
    final amountController = TextEditingController(text: existingFee != null ? existingFee.fee.toStringAsFixed(0) : "");
    List<Map<String, dynamic>> studentList = [];
    int totalAmount = existingFee != null ? existingFee.totalAmount.toInt() : 0;

    // Load students via provider (fallback to repository)
    try {
      studentList = await ref.read(studentsOfTeacherProvider(widget.teacherId).future);
    } catch (e) {
      // fallback: get directly
      studentList = await FeeListRepository().getStudentsOfTeacher(widget.teacherId);
    }

    if (existingFee != null) {
      studentList = List<Map<String, dynamic>>.from(existingFee.students);
    }

    // compute initial totalAmount
    if (amountController.text.isNotEmpty) {
      final per = int.tryParse(amountController.text) ?? 0;
      totalAmount = per * studentList.length;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return Center(
            child: Container(
              width: 480,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(existingFee == null ? "Add Fee" : "Edit Fee", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Description with suggestions
                    _descriptionField(
                      controller: descriptionController,
                      onSelectSuggestion: (selected) async {
                        // prefill amount if description exists for this class/division
                        final snap = await FirebaseFirestore.instance.collection(FirebaseConstant.fees).doc(selected).get();
                        if (snap.exists) {
                          final map = snap.data();
                          final mapped = map?[teacher.classNo.toString()]?[teacher.division];
                          if (mapped != null && (mapped['fee'] != null || mapped['amount'] != null)) {
                            final val = (mapped['fee'] ?? mapped['amount']).toString();
                            amountController.text = val;
                            setState(() {
                              final per = int.tryParse(amountController.text) ?? 0;
                              totalAmount = per * studentList.length;
                            });
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // Amount
                    _buildTextField(
                      amountController,
                      "Amount (per student)",
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(4)],
                      onChanged: (txt) {
                        setState(() {
                          final per = int.tryParse(txt) ?? 0;
                          totalAmount = per * studentList.length;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _rowInfo("Class:", "${teacher.classNo} ${teacher.division}"),
                          _rowInfo("Teacher:", teacher.teacherName),
                          _rowInfo("Students:", studentList.length.toString()),
                          const SizedBox(height: 4),
                          _rowInfo("Total Amount:", "₹$totalAmount", valueColor: Colors.green, isBold: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff1193D4)),
                        onPressed: () async {
                          if (descriptionController.text.isEmpty || amountController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fill all fields")));
                            return;
                          }

                          final feeModel = FeeModel(
                            description: descriptionController.text.trim(),
                            fee: double.parse(amountController.text),
                            totalAmount: totalAmount.toDouble(),
                            classNo: teacher.classNo,
                            collectedCount: existingFee?.collectedCount ?? 0,
                            division: teacher.division,
                            teacherName: teacher.teacherName,
                            teacherId: teacher.id,
                            delete: existingFee?.delete ?? false,
                            completed: existingFee?.completed ?? false,
                            createdDate: existingFee?.createdDate ?? DateTime.now(),
                            students: studentList,
                          );

                          // save using provider
                          await ref.read(saveFeeProvider)(feeModel);

                          Navigator.pop(context);
                        },
                        child: Text(existingFee == null ? "Add Fee" : "Update Fee", style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // UI helpers
  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        List<TextInputFormatter>? inputFormatters,
        ValueChanged<String>? onChanged,
      }) {
    return SizedBox(
      height: 65,
      child: TextFormField(
        controller: controller,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _rowInfo(String label, String value, {Color valueColor = Colors.black, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: valueColor)),
      ]),
    );
  }

  Widget _descriptionField({required TextEditingController controller, required Function(String) onSelectSuggestion}) {
    return Consumer(builder: (context, ref, child) {
      final suggestionsAsync = ref.watch(feeDescriptionsProvider);

      return suggestionsAsync.when(
        data: (list) {
          final suggestions = list.where((s) => s.toLowerCase().contains(controller.text.toLowerCase())).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                onChanged: (_) => (context as Element).markNeedsBuild(),
                decoration: InputDecoration(
                  labelText: "Description",
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              if (controller.text.isNotEmpty && suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    children: suggestions.map((s) {
                      return ListTile(
                        dense: true,
                        title: Text(s),
                        onTap: () {
                          controller.text = s;
                          onSelectSuggestion(s);
                          (context as Element).markNeedsBuild();
                        },
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xff1193D4))),
        error: (e, _) => Text("Error: $e"),
      );
    });
  }

  // ---------- Build UI ----------
  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(teacherProvider(widget.teacherId));
    final pendingAsync = ref.watch(pendingFeesProvider(widget.teacherId));
    final completedAsync = ref.watch(completedFeesProvider(widget.teacherId));
    final totalStudentsAsync = ref.watch(totalStudentsProvider(widget.teacherId));
    final deleteFee = ref.read(deleteFeeProvider);

    return Scaffold(
      body: teacherAsync.when(
        data: (teacher) {
          if (teacher == null) return const Center(child: Text("Teacher not found"));

          return DefaultTabController(
            length: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Manage Fees",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const TabBar(labelColor: Colors.blue, unselectedLabelColor: Colors.grey, tabs: [Tab(text: "Pending Fees"), Tab(text: "Completed Fees")]),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical:15,horizontal: 10),
                      child: TabBarView(
                        children: [
                          _buildFeeTab(feesAsync: pendingAsync, teacher: teacher, totalStudentsAsync: totalStudentsAsync, completed: false),
                          _buildFeeTab(feesAsync: completedAsync, teacher: teacher, totalStudentsAsync: totalStudentsAsync, completed: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.blue)),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }

  Widget _buildFeeTab({required AsyncValue<List<FeeModel>> feesAsync, required TeacherModel teacher, required AsyncValue<int> totalStudentsAsync, required bool completed}) {
    return feesAsync.when(
      data: (fees) {
        fees.sort((a, b) => b.createdDate.compareTo(a.createdDate));
        final totalStudents = totalStudentsAsync.value ?? 0;

        final cards = fees.map((fee) {
          return _feeCard(teacher: teacher, fee: fee, totalStudents: totalStudents, completed: completed);
        }).toList();

        if (!completed) cards.add(_addFeeCard(teacher));

        return GridView.count(crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.9, children: cards);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text("$e"),
    );
  }

  Widget _feeCard({
    required TeacherModel teacher,
    required FeeModel fee,
    required int totalStudents,
    required bool completed,
  }) {
    final deleteFee = ref.read(deleteFeeProvider);

    final date =
        "${fee.createdDate.day}/${fee.createdDate.month}/${fee.createdDate.year}";
    final collected =
        fee.students.where((s) => s["collected"] == true).length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeeCollectionPage(
              description: fee.description,
              teacherId: teacher.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --------- DATE + MENU / COMPLETED ICON ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                // Completed icon
                completed
                    ? SizedBox(
                  height: 40,
                  width: 40,
                  child: SvgPicture.asset(ImageConstant.completed),
                )
                    : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black54),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _showFeeBottomSheet(
                        teacher: teacher,
                        existingFee: fee,
                      );
                    }
                    if (value == 'delete') {
                      await deleteFee(
                        fee.description,
                        fee.classNo.toString(),
                        fee.division,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit,
                              size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit Fee'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Fee'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 15),

            // ---------- DESCRIPTION + AMOUNT ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fee.description,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${fee.fee.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ---------- STUDENT COUNTS ----------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Students : $totalStudents',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Collected : $collected',
                  style: const TextStyle(
                    color: Colors.grey,
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

  Widget _addFeeCard(TeacherModel teacher) {
    return GestureDetector(
      onTap: () => _showFeeBottomSheet(teacher: teacher),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: const Center(child: Icon(Icons.add, size: 30)),
      ),
    );
  }
}
