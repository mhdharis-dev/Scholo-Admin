import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:alert_info/alert_info.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:scholo_admin/models/school_model.dart';
import 'package:scholo_admin/auth/controller/login_controller.dart';
import '../../dashbord/screen/dashboard_screen.dart';

final firestoreSubscriptionPlansProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('subscription_plans').snapshots().map((snapshot) {
    if (snapshot.docs.isEmpty) return [];
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  });
});

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _billingFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final schoolAsync = ref.watch(schoolStreamProvider);
    final school = schoolAsync.asData?.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 🔹 Page Title Header ──────────────────────────────────────────
            _buildPageHeader(context, school),

            const SizedBox(height: 24),

            // ── 🔹 Active Plan Hero Banner ────────────────────────────────────
            _buildActivePlanHeroCard(context, school),

            const SizedBox(height: 36),

            // ── 🔹 Included Plan Features Grid ──────────────────────────────
            _buildIncludedModulesSection(),

            const SizedBox(height: 36),

            // ── 🔹 Billing History & Invoice Records ─────────────────────────
            _buildBillingHistorySection(school),
          ],
        ),
      ),
    );
  }

  // ── 1. Page Header ────────────────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context, SchoolModel? school) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "School Subscription & License",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Manage school license tier, active features, auto-renewals, and invoice records.",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              onPressed: () {
                ref.invalidate(schoolStreamProvider);
                ref.invalidate(totalStudentsProvider);
                ref.invalidate(activeTeachersProvider);
                AlertInfo.show(
                  context: context,
                  text: "Subscription data refreshed",
                  typeInfo: TypeInfo.success,
                  backgroundColor: const Color(0xFF10B981),
                  textColor: Colors.white,
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
              label: const Text("Refresh", style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1193D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: const Color(0xFF1193D4).withValues(alpha: 0.3),
              ),
              onPressed: () => _showUpgradePlanModal(context, school),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: const Text(
                "Upgrade Plan",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 2. Active Plan Hero Card ──────────────────────────────────────────────
  Widget _buildActivePlanHeroCard(BuildContext context, SchoolModel? school) {
    final String planTitle = (school != null && school.subscriptionPlan.isNotEmpty)
        ? school.subscriptionPlan
        : "Pro School Unlimited License";

    final String formattedRenewal = DateFormat('d MMMM yyyy').format(DateTime(DateTime.now().year, DateTime.now().month + 1, 25));
    final int daysRemaining = DateTime.now().isAfter(DateTime(DateTime.now().year, 3, 31))
        ? DateTime(DateTime.now().year + 1, 3, 31).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays + 1
        : DateTime(DateTime.now().year, 3, 31).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF091E36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badges Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
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
                              Text(
                                (school?.status ?? "ACTIVE").toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "ENV: ${(school?.environment ?? 'PROD').toUpperCase()}",
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "School Code: ${school?.schoolCode ?? 'SCH-1001'}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Plan Title & Institution Name
                    Text(
                      planTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Licensed to ${school?.schoolName ?? 'Scholo Academy'} • Principal: ${school?.principalName ?? 'Authorized Admin'}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Right Renewal Card Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          // "Next Renewal: $formattedRenewal",
                          "Next Renewal: 31 March 2027",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$daysRemaining Days Remaining",
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "₹30,000 / year",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),

          // Bottom Bar inside Hero Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Official License Key Verified • Annual Billing (Auto-Renew Enabled)",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showUpgradePlanModal(context, school),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: const [
                      Text(
                        "Manage Billing & Upgrade",
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Color(0xFF38BDF8), size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Included Modules Grid ─────────────────────────────────────────────
  Widget _buildIncludedModulesSection() {
    final modules = [
      {'title': 'Student Directory & Profiles', 'icon': Icons.school_rounded, 'color': const Color(0xFF1193D4)},
      {'title': 'Faculty & Staff Registry', 'icon': Icons.badge_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Attendance & Reports', 'icon': Icons.rule_rounded, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Fee Collections & Receipts', 'icon': Icons.payments_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Broadcast Alerts & Media', 'icon': Icons.campaign_rounded, 'color': const Color(0xFFEC4899)},
      {'title': 'Timetable & Class Schedule', 'icon': Icons.table_chart_rounded, 'color': const Color(0xFF0284C7)},
      {'title': 'Recycle Bin & Data Recovery', 'icon': Icons.restore_from_trash_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Admin Devices & FCM Security', 'icon': Icons.devices_rounded, 'color': const Color(0xFF6366F1)},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Active System Capabilities & Modules",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                "All 8 Core Modules Enabled",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 900 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 3.2,
                ),
                itemBuilder: (ctx, idx) {
                  final item = modules[idx];
                  final Color itemColor = item['color'] as Color;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: itemColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item['icon'] as IconData, color: itemColor, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 4. Billing History Section ───────────────────────────────────────────
  Widget _buildBillingHistorySection(SchoolModel? school) {
    final allHistory = [
      {
        "invoice": "INV-2026-001",
        "date": "10 Aug 2026",
        "plan": "Basic Plan",
        "paidAmount": "₹10,000",
        "balanceAmount": "₹20,000",
        "method": "Cash on Hand",
        "status": "PAID",
        "note": "1st initial Payment (advance)",
      },
    ];

    final filtered = _billingFilter == 'All'
        ? allHistory
        : allHistory.where((h) => h["status"] == _billingFilter.toUpperCase()).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Billing History & Invoices",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Download tax invoices and inspect payment settlement history.",
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Row(
                children: ['All', 'Paid'].map((filter) {
                  final isSelected = _billingFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1193D4),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? const Color(0xFF1193D4) : const Color(0xFFCBD5E1)),
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _billingFilter = filter);
                      },
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.4),
              1: FlexColumnWidth(1.3),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.3),
              4: FlexColumnWidth(1.3),
              5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1.0),
              7: FlexColumnWidth(1.2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                children: const [
                  Padding(padding: EdgeInsets.all(12), child: Text("Invoice ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Billing Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Subscription Plan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Paid Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Balance Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Padding(padding: EdgeInsets.all(12), child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
              ...filtered.map(
                (item) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["invoice"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)))),
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["date"]!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["plan"]!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155)))),
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["paidAmount"]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF059669)))),
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["balanceAmount"]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFD97706)))),
                    Padding(padding: const EdgeInsets.all(14), child: Text(item["method"]!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item["status"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFF1193D4)),
                        ),
                        onPressed: () => _showInvoiceDialog(context, item, school),
                        icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF1193D4)),
                        label: const Text("Invoice", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1193D4))),
                      ),
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

  // ── 5. Upgrade Plan Modal Dialog (Fetches Real Current Plan from Firestore) ────────
  void _showUpgradePlanModal(BuildContext context, SchoolModel? school) {
    final String currentSchoolPlan = (school?.subscriptionPlan ?? '').trim();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final plansAsync = ref.watch(firestoreSubscriptionPlansProvider);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Container(
                width: 920,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1193D4).withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1193D4), Color(0xFF0F172A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Upgrade School Subscription Plan",
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Select the best plan to scale student enrollment limits, teacher slots & cloud capacity.",
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 22),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: SingleChildScrollView(
                        child: plansAsync.when(
                          data: (firestorePlans) {
                            if (firestorePlans.isNotEmpty) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: firestorePlans.map((plan) {
                                  final planName = (plan['planName'] ?? plan['name'] ?? plan['id'] ?? 'Plan').toString();
                                  final price = (plan['price'] ?? plan['amount'] ?? '₹30,000').toString();
                                  final period = (plan['period'] ?? plan['billingCycle'] ?? '/ year').toString();
                                  final description = (plan['description'] ?? '').toString();
                                  final features = List<String>.from(plan['features'] ?? plan['featuresList'] ?? []);
                                  final isPopular = plan['isPopular'] ?? plan['isRecommended'] ?? false;

                                  final isCurrent = currentSchoolPlan.isNotEmpty &&
                                      (currentSchoolPlan.toLowerCase() == planName.toLowerCase() ||
                                          planName.toLowerCase().contains(currentSchoolPlan.toLowerCase()) ||
                                          currentSchoolPlan.toLowerCase().contains(planName.toLowerCase()));

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: _buildModalPlanCard(
                                        context: context,
                                        planName: planName,
                                        price: price.startsWith('₹') ? price : '₹$price',
                                        period: period,
                                        description: description.isNotEmpty ? description : "Full school management capabilities.",
                                        isCurrent: isCurrent,
                                        isPopular: isPopular,
                                        features: features.isNotEmpty ? features : const ["Complete School Management", "Real-time Reports", "Priority Support"],
                                        onSelect: () {
                                          Navigator.pop(context);
                                          AlertInfo.show(
                                            context: context,
                                            text: "Upgrade request for $planName submitted to Super Admin.",
                                            typeInfo: TypeInfo.success,
                                            backgroundColor: const Color(0xFF1193D4),
                                            textColor: Colors.white,
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }

                            // Dynamic Evaluation of current plan from real Firestore school object
                            final bool isStarterCurrent = currentSchoolPlan.toLowerCase().contains("starter");
                            final bool isProCurrent = currentSchoolPlan.isEmpty ||
                                currentSchoolPlan.toLowerCase().contains("pro") ||
                                (!isStarterCurrent && !currentSchoolPlan.toLowerCase().contains("enterprise"));

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Plan 1: Basic School Plan (Web & Android Access)
                                Expanded(
                                  child: _buildModalPlanCard(
                                    context: context,
                                    planName: "Basic Plan",
                                    price: "₹30,000",
                                    period: "/ year",
                                    description: "Full management suite for Web & Android devices.",
                                    isCurrent: isStarterCurrent || currentSchoolPlan.toLowerCase().contains("basic"),
                                    features: const [
                                      "🌐 Web Portal Access (Desktop & Laptop)",
                                      "🤖 Android App Access (Google Play Store)",
                                      "Up to 1,000 Students & 100 Staff",
                                      "Attendance & Student Profiles",
                                      "Fee Collections & Tax Receipts",
                                      "Broadcast Alerts & FCM Notifications",
                                      "Timetable & Class Schedules",
                                      "Recycle Bin & Data Recovery",
                                      "Admin Device Security & Sessions",
                                    ],
                                    onSelect: () {
                                      Navigator.pop(context);
                                      AlertInfo.show(
                                        context: context,
                                        text: "Basic Plan request submitted to Super Admin.",
                                        typeInfo: TypeInfo.success,
                                        backgroundColor: const Color(0xFF1193D4),
                                        textColor: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 20),

                                // Plan 2: Pro Plan (Web, Android & iOS Support)
                                Expanded(
                                  child: _buildModalPlanCard(
                                    context: context,
                                    planName: "Pro Plan",
                                    price: "₹45,000",
                                    period: "/ year",
                                    description: "Complete institution suite with iOS App support included.",
                                    isCurrent: isProCurrent && !currentSchoolPlan.toLowerCase().contains("basic"),
                                    isPopular: true,
                                    features: const [
                                      "🌐 Web Portal Access (Desktop & Laptop)",
                                      "🤖 Android App Access (Google Play Store)",
                                      "🍏 Extra iOS App Support (Apple App Store)",
                                      "Apple APNs & FCM Push Engine",
                                      "Unlimited Students & Staff Slots",
                                      "Advanced Attendance & Report Cards",
                                      "Fee Collections & Online Payments",
                                      "Multi-Device Concurrent Admin Sessions",
                                      "Priority 24/7 Dedicated Support",
                                    ],
                                    onSelect: () {
                                      Navigator.pop(context);
                                      AlertInfo.show(
                                        context: context,
                                        text: "Upgrade request to Pro Plan sent to Super Admin.",
                                        typeInfo: TypeInfo.success,
                                        backgroundColor: const Color(0xFF1193D4),
                                        textColor: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1193D4))),
                          error: (_, __) => const Center(child: Text("Unable to load subscription plans")),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalPlanCard({
    required BuildContext context,
    required String planName,
    required String price,
    required String period,
    required String description,
    required List<String> features,
    required VoidCallback onSelect,
    bool isCurrent = false,
    bool isPopular = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF1193D4)
              : (isPopular ? const Color(0xFF1193D4).withValues(alpha: 0.6) : const Color(0xFFE2E8F0)),
          width: isCurrent || isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular
                ? const Color(0xFF1193D4).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1193D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1193D4).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "Current Plan",
                    style: TextStyle(
                      color: Color(0xFF1193D4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1193D4), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "RECOMMENDED",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent
                    ? const Color(0xFFF1F5F9)
                    : (isPopular ? const Color(0xFF1193D4) : const Color(0xFF0F172A)),
                foregroundColor: isCurrent ? const Color(0xFF64748B) : Colors.white,
                elevation: isCurrent ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isCurrent ? null : onSelect,
              child: Text(
                isCurrent ? "Active Plan" : "Request Upgrade",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Invoice Details Modal Dialog (With Real Logo, Print & PDF Download) ──
  void _showInvoiceDialog(BuildContext context, Map<String, String> item, SchoolModel? school) {
    final String schoolName = school?.schoolName.isNotEmpty == true ? school!.schoolName : "Duhss Thootha";
    final String schoolCode = school?.schoolCode.isNotEmpty == true ? school!.schoolCode : "10098";
    final String email = school?.officialEmail.isNotEmpty == true ? school!.officialEmail : "duhssthootha@gmail.com";
    final String phone = school?.phoneNumber.isNotEmpty == true ? school!.phoneNumber : "+91 4933 285 240 / +91 9447 123 456";
    final String address = school?.schoolAddress.isNotEmpty == true ? school!.schoolAddress : "Thootha, Malappuram Dt., Kerala - 679357";
    final String statusText = item['status'] ?? "PARTIALLY PAID";
    final bool isPaid = statusText.toUpperCase() == "PAID";

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 640,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 🔹 Top Dark Header Bar ────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                color: const Color(0xFF0A1322),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(
                            Icons.article_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "TAX INVOICE & RECEIPT",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  "Ref: ",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF132B45),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item['invoice'] ?? 'INV-2026-001',
                                    style: const TextStyle(
                                      color: Color(0xFF7DD3FC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _handlePrintInvoice(context, item, school),
                          icon: const Icon(Icons.print_outlined, color: Colors.white, size: 19),
                          tooltip: "Print Invoice",
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          tooltip: "Close",
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── 🔹 Main Modal Scrollable Body ─────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Institution Header Card ───────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Real School Logo or Crest Fallback Avatar
                                _buildSchoolLogoWidget(school),
                                const SizedBox(width: 14),

                                // School Name & Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              schoolName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              "CODE : $schoolCode",
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF475569),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: const [
                                          Icon(Icons.verified_user_outlined, size: 13, color: Color(0xFF0284C7)),
                                          SizedBox(width: 4),
                                          Text(
                                            "Govt. Aided HSS • Affln No: KL-ED-10098",
                                            style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              address,
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Pill Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isPaid ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        statusText.toUpperCase(),
                                        style: TextStyle(
                                          color: isPaid ? const Color(0xFF047857) : const Color(0xFFB45309),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 10),

                            // Contact Row
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: Color(0xFF0284C7)),
                                const SizedBox(width: 6),
                                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                                const Text("•", style: TextStyle(color: Color(0xFFCBD5E1))),
                                const SizedBox(width: 16),
                                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 2. Payment Fulfillment & Progress Card ────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "Payment Fulfillment",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "33.3% Paid",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF15803D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: const [
                                    Text(
                                      "Total Invoiced: ",
                                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                    ),
                                    Text(
                                      "Rs. 30,000",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: const LinearProgressIndicator(
                                value: 0.333,
                                backgroundColor: Color(0xFFE2E8F0),
                                color: Color(0xFF10B981),
                                minHeight: 7,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Paid Amount vs Remaining Due Cards Row
                            Row(
                              children: [
                                // Left Paid Box
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
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
                                              "PAID AMOUNT",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF047857),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['paidAmount'] ?? "Rs. 10,000",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Right Remaining Box
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFD97706),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              "REMAINING DUE",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFB45309),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['balanceAmount'] ?? "Rs. 20,000",
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 3. Detailed Itemized Table List ──────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildMockInvoiceDetailRow(
                              "Billing Date",
                              item['date'] ?? "10 Aug 2026",
                              icon: Icons.calendar_today_outlined,
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _buildMockInvoiceDetailRow(
                              "Subscription Plan",
                              "${item['plan'] ?? 'Basic Plan'} (Academic Year 2026-27)",
                              icon: Icons.star_border_rounded,
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _buildMockInvoiceDetailRow(
                              "Payment Method",
                              item['method'] ?? "Cash on Hand",
                              icon: Icons.payments_outlined,
                              hasDot: true,
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _buildMockInvoiceDetailRow(
                              "Paid Amount",
                              item['paidAmount'] ?? "Rs. 10,000",
                              icon: Icons.account_balance_wallet_outlined,
                              valueColor: const Color(0xFF059669),
                              isBold: true,
                            ),
                            const Divider(height: 20, color: Color(0xFFF1F5F9)),
                            _buildMockInvoiceDetailRow(
                              "Balance Amount",
                              item['balanceAmount'] ?? "Rs. 20,000",
                              icon: Icons.monetization_on_outlined,
                              valueColor: const Color(0xFFD97706),
                              isBold: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── 4. Payment Remarks / Note Banner ─────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF0284C7),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "PAYMENT REMARKS / NOTE",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0369A1),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item['note'] ?? "1st initial Payment (advance)",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 🔹 Bottom Action Footer Bar ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF475569)),
                      label: const Text(
                        "Close",
                        style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _handlePrintInvoice(context, item, school),
                      icon: const Icon(Icons.print_outlined, size: 16, color: Color(0xFF475569)),
                      label: const Text(
                        "Print",
                        style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        elevation: 1,
                      ),
                      onPressed: () => _handleDownloadInvoice(context, item, school),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text(
                        "Download PDF",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to render real school logo image or crest shield fallback
  Widget _buildSchoolLogoWidget(SchoolModel? school) {
    if (school != null && school.imageUrl.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            school.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultShieldAvatar(),
          ),
        ),
      );
    }
    return _buildDefaultShieldAvatar();
  }

  Widget _buildDefaultShieldAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        Icons.shield_outlined,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildMockInvoiceDetailRow(
    String label,
    String value, {
    required IconData icon,
    Color? valueColor,
    bool isBold = false,
    bool hasDot = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (hasDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0284C7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: isBold ? 14 : 13,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 7. Real PDF Generation, Print & Download Handlers ──────────────────────
  Future<void> _handlePrintInvoice(BuildContext context, Map<String, String> item, SchoolModel? school) async {
    try {
      final pdfBytes = await _generateInvoicePdf(item, school);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: '${item['invoice'] ?? "INV-2026-001"}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Error printing invoice: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _handleDownloadInvoice(BuildContext context, Map<String, String> item, SchoolModel? school) async {
    try {
      final String invoiceId = item['invoice'] ?? "INV-2026-001";
      final pdfBytes = await _generateInvoicePdf(item, school);

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', '$invoiceId.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Printing.sharePdf(bytes: pdfBytes, filename: '$invoiceId.pdf');
      }

      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Downloaded $invoiceId.pdf successfully",
          typeInfo: TypeInfo.success,
          backgroundColor: const Color(0xFF10B981),
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AlertInfo.show(
          context: context,
          text: "Error downloading invoice: $e",
          typeInfo: TypeInfo.error,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<Uint8List> _generateInvoicePdf(Map<String, String> item, SchoolModel? school) async {
    final pdf = pw.Document();

    final String schoolName = _cleanPdfText(school?.schoolName.isNotEmpty == true ? school!.schoolName : "Duhss Thootha");
    final String schoolCode = _cleanPdfText(school?.schoolCode.isNotEmpty == true ? school!.schoolCode : "10098");
    final String email = _cleanPdfText(school?.officialEmail.isNotEmpty == true ? school!.officialEmail : "duhssthootha@gmail.com");
    final String phone = _cleanPdfText(school?.phoneNumber.isNotEmpty == true ? school!.phoneNumber : "+91 4933 285 240 / +91 9447 123 456");
    final String address = _cleanPdfText(school?.schoolAddress.isNotEmpty == true ? school!.schoolAddress : "Thootha, Malappuram Dt., Kerala - 679357");
    final String invoiceId = _cleanPdfText(item['invoice'] ?? "INV-2026-001");
    final String statusText = _cleanPdfText(item['status'] ?? "PARTIALLY PAID");
    final String paidAmount = _cleanPdfText(item['paidAmount'] ?? "Rs. 10,000");
    final String balanceAmount = _cleanPdfText(item['balanceAmount'] ?? "Rs. 20,000");

    pw.MemoryImage? schoolLogoImage;
    if (school != null && school.imageUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(school.imageUrl));
        if (response.statusCode == 200) {
          schoolLogoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Top Header Banner ──────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F172A'),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "TAX INVOICE & RECEIPT",
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.Text(
                              "Ref: ",
                              style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 12),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#1E293B'),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                invoiceId,
                                style: pw.TextStyle(
                                  color: PdfColor.fromHex('#38BDF8'),
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── Institution Card ───────────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (schoolLogoImage != null)
                          pw.Container(
                            width: 48,
                            height: 48,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.ClipRRect(
                              horizontalRadius: 10,
                              verticalRadius: 10,
                              child: pw.Image(schoolLogoImage, fit: pw.BoxFit.cover),
                            ),
                          )
                        else
                          pw.Container(
                            width: 48,
                            height: 48,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#0284C7'),
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                schoolName.isNotEmpty ? schoolName[0].toUpperCase() : 'S',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text(
                                    schoolName,
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#0F172A'),
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('#E2E8F0'),
                                      borderRadius: pw.BorderRadius.circular(4),
                                    ),
                                    child: pw.Text(
                                      "CODE: $schoolCode",
                                      style: pw.TextStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColor.fromHex('#475569'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                "Govt. Aided HSS | Affln No: KL-ED-10098",
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  color: PdfColor.fromHex('#0284C7'),
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                address,
                                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B')),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#FFFBEB'),
                            borderRadius: pw.BorderRadius.circular(12),
                            border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
                          ),
                          child: pw.Text(
                            statusText.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColor.fromHex('#B45309'),
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Text(
                          "$email   |   $phone",
                          style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── Payment Fulfillment Card ──────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Text(
                              "Payment Fulfillment",
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#334155'),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColor.fromHex('#DCFCE7'),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Text(
                                "33.3% Paid",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#15803D'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.Text(
                          "Total Invoiced: Rs. 30,000",
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#ECFDF5'),
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0')),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "PAID AMOUNT",
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#047857'),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  paidAmount,
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#059669'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#FFFBEB'),
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "REMAINING DUE",
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#B45309'),
                                  ),
                                ),
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  balanceAmount,
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#D97706'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── Itemized Table Section ─────────────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    _buildPdfRow("Billing Date", _cleanPdfText(item['date'] ?? "10 Aug 2026")),
                    pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5),
                    _buildPdfRow("Subscription Plan", _cleanPdfText("${item['plan'] ?? 'Basic Plan'} (Academic Year 2026-27)")),
                    pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5),
                    _buildPdfRow("Payment Method", _cleanPdfText(item['method'] ?? "Cash on Hand")),
                    pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5),
                    _buildPdfRow("Paid Amount", paidAmount, color: PdfColor.fromHex('#059669'), isBold: true),
                    pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5),
                    _buildPdfRow("Balance Amount", balanceAmount, color: PdfColor.fromHex('#D97706'), isBold: true),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // ── Payment Remarks / Note ─────────────────────────────────────
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F0F9FF'),
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: PdfColor.fromHex('#BAE6FD')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "PAYMENT REMARKS / NOTE",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0369A1'),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _cleanPdfText(item['note'] ?? "1st initial Payment (advance)"),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F172A'),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // ── Footer Lines ──────────────────────────────────────────────
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "This is a system-generated receipt.\nNo signature required for validity.",
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                  ),
                  pw.Text(
                    "Authorised Signatory",
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#334155')),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  String _cleanPdfText(String? input) {
    if (input == null) return '';
    return input
        .replaceAll('₹', 'Rs. ')
        .replaceAll('•', '|')
        .replaceAll('·', '|')
        .replaceAll('●', '')
        .trim();
  }

  pw.Widget _buildPdfRow(String label, String val, {PdfColor? color, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B')),
          ),
          pw.Text(
            _cleanPdfText(val),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColor.fromHex('#0F172A'),
            ),
          ),
        ],
      ),
    );
  }
}
