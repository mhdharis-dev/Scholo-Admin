import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Sample data model (replace with your real provider/model) ──
class NotificationItem {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

// ── Sample grouped data (replace with your real Riverpod providers) ──
final _sampleGroups = <String, List<NotificationItem>>{
  'TODAY': [
    NotificationItem(
      title: 'Attendance Marked',
      body: 'Your attendance for Mathematics has been recorded successfully.',
      time: '10:30 AM',
      icon: Icons.how_to_reg_outlined,
      iconColor: const Color(0xFF3B82F6),
      iconBg: const Color(0xFFEFF6FF),
    ),
    NotificationItem(
      title: 'Fee Payment Success',
      body: 'Payment of ₹4,500 for the semester fee has been confirmed.',
      time: '2h ago',
      icon: Icons.payments_outlined,
      iconColor: const Color(0xFF22C55E),
      iconBg: const Color(0xFFEFFFF5),
    ),
  ],
  'YESTERDAY': [
    NotificationItem(
      title: 'Schedule Updated',
      body: 'The Physics lab session has been rescheduled to 2:00 PM Friday.',
      time: 'Yesterday',
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFFF97316),
      iconBg: const Color(0xFFFFF7ED),
    ),
    NotificationItem(
      title: 'New Assignment',
      body: 'Prof. Sarah posted a new assignment in Computer Science.',
      time: 'Yesterday',
      icon: Icons.assignment_outlined,
      iconColor: const Color(0xFF8B5CF6),
      iconBg: const Color(0xFFF5F3FF),
    ),
    NotificationItem(
      title: 'Library Notice',
      body: "Please return the issued book 'Clean Code' by the end of this week.",
      time: 'Oct 24',
      icon: Icons.info_outline,
      iconColor: const Color(0xFF64748B),
      iconBg: const Color(0xFFF1F5F9),
    ),
  ],
};

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _broadcastController = TextEditingController();
  String _selectedFilter = 'All';
  String _selectedAudience = 'All';

  final List<String> _filters = ['All', 'Week', 'Month', 'Year'];
  final List<String> _audiences = ['All', 'Teachers', 'Specific Class'];
  final List<String> _classes = [
    '11A', '11B', '11C', '11D',
    '10A', '10B', '10C', '10D',
    '9A',  '9B',  '9C',  '9D',
    '8A',  '8B',  '8C',  '8D',
  ];
  String _selectedClass = '11A';

  @override
  void dispose() {
    _searchController.dispose();
    _broadcastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replace with your real provider watches here:
    // final notifications = ref.watch(notificationsProvider);

    final isWide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isWide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildNotificationList()),
          const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildQuickNotificationsPanel(),
                  const SizedBox(height: 16),
                  _buildHistoryPanel(),
                ],
              ),
            ),
          ),
        ],
      )
          : _buildNotificationList(),
    );
  }

  // ── Left: Notification List ──────────────────────────────────────
  Widget _buildNotificationList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search student name or roll no...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: _filters.map((label) {
              final isSelected = _selectedFilter == label;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFilter = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                        isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Grouped notification list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: _sampleGroups.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, top: 4),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...entry.value.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(item: item),
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Right: Quick Notifications Panel ────────────────────────────
  Widget _buildQuickNotificationsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: const [
              Icon(Icons.bolt, color: Color(0xFF3B82F6), size: 20),
              SizedBox(width: 6),
              Text(
                'Quick Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Send a high-priority message to specific segments of the school community.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 16),

          // Target Audience
          const Text(
            'Target Audience',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _DropdownField(
            value: _selectedAudience,
            items: _audiences,
            onChanged: (val) {
              if (val != null) setState(() => _selectedAudience = val);
            },
          ),

          // Specific Class dropdown — shown only when "Specific Class" is selected
          if (_selectedAudience == 'Specific Class') ...[
            const SizedBox(height: 12),
            const Text(
              'Select Class',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            _DropdownField(
              value: _selectedClass,
              items: _classes,
              onChanged: (val) {
                if (val != null) setState(() => _selectedClass = val);
              },
            ),
          ],
          const SizedBox(height: 16),

          // Message
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _broadcastController,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Broadcast a quick alert...',
                fillColor: Colors.transparent,
                hintStyle:
                TextStyle(color: Colors.grey[400], fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Send Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: wire up your broadcast logic here
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text(
                'Send Broadcast',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Right: History Panel ─────────────────────────────────────────
  Widget _buildHistoryPanel() {
    // Replace with your real history data/provider
    final historyItems = _sampleGroups['TODAY'] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.history, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...historyItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: item.iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon,
                        color: item.iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              item.time,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.body,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Reusable Dropdown Field ──────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF64748B)),
          items: items
              .map((a) => DropdownMenuItem(value: a, child: Text(a)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Notification Card Widget ─────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  const _NotificationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}