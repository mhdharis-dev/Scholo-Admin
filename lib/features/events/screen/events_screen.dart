import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/event_model.dart';
import '../controller/event_controller.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  // Available colors for events
  final List<Color> eventColors = const [
    Color(0xff2970FF), // Blue
    Color(0xff22C55E), // Green
    Color(0xffFACC15), // Yellow
    Color(0xffF97316), // Orange
    Color(0xffEF4444), // Red
    Color(0xffA855F7), // Purple
    Color(0xff64748B), // Grey
  ];

  // All classes (1 - 12)
  final List<String> allClasses = const [
    "5",
    "6",
    "7",
    "8",
    "9",
    "10",
    "11",
    "12",
  ];

  // ---------------- INPUT BOX HELPER ----------------
  Widget _inputBox({required Widget child, double height = 50}) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff4f7fa),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xffE2E8F0),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================================================
  // ADD / EDIT EVENT DIALOG
  // =========================================================
  void _showAddEditEventDialog({EventModel? existingEvent,  DateTime? date,
  }) {
    final isEdit = existingEvent != null;

    final titleController =
    TextEditingController(text: existingEvent?.title ?? "");
    final descController =
    TextEditingController(text: existingEvent?.description ?? "");

    DateTime? startDate =
        existingEvent?.startDateTime ?? date;

    DateTime? endDate =
        existingEvent?.endDateTime ?? date;

    TimeOfDay? startTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.startDateTime)
        : null;

    TimeOfDay? endTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.endDateTime)
        : null;

    Color? selectedColor =
    existingEvent != null ? _parseColor(existingEvent.color) : null;

    // classes selected
    List<String> selectedClasses =
    existingEvent != null ? List<String>.from(existingEvent.classes) : [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 650,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HEADER ------------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEdit ? "Edit Event" : "Add New Event",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 25),

                        // EVENT TITLE
                        const Text("Event Title",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _inputBox(
                          child: TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              hintText: "e.g., Annual Sports Day",
                              border: InputBorder.none,
                              fillColor: Color(0xfff4f7fa),
                              hoverColor: Color(0xfff4f7fa),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // EVENT DESCRIPTION
                        const Text("Event Description",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _inputBox(
                          height: 90,
                          child: TextField(
                            controller: descController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: "Provide a brief summary of the event.",
                              border: InputBorder.none,
                              fillColor: Color(0xfff4f7fa),
                              hoverColor: Color(0xfff4f7fa),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        // DATE ROW ------------------------
                        Row(
                          children: [
                            // Start Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Start date",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate: startDate ??
                                              DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(
                                                  () => startDate = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            startDate == null
                                                ? "Select a date"
                                                : DateFormat('dd MMM yyyy')
                                                .format(startDate!),
                                          ),
                                          const Icon(Icons.calendar_today,
                                              size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Start Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Start time",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked =
                                        await showTimePicker(
                                          context: context,
                                          initialTime: startTime ??
                                              TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setState(
                                                  () => startTime = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(startTime == null
                                              ? "--:-- --"
                                              : startTime!.format(context)),
                                          const Icon(Icons.schedule, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // End Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("End date",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate:
                                          endDate ?? DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null) {
                                          setState(
                                                  () => endDate = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            endDate == null
                                                ? "Select a date"
                                                : DateFormat('dd MMM yyyy')
                                                .format(endDate!),
                                          ),
                                          const Icon(Icons.calendar_today,
                                              size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // End Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("End time",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  _inputBox(
                                    child: InkWell(
                                      onTap: () async {
                                        final picked =
                                        await showTimePicker(
                                          context: context,
                                          initialTime:
                                          endTime ?? TimeOfDay.now(),
                                        );
                                        if (picked != null) {
                                          setState(
                                                  () => endTime = picked);
                                        }
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(endTime == null
                                              ? "--:-- --"
                                              : endTime!.format(context)),
                                          const Icon(Icons.schedule, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // COLOR SELECTOR -----------------------
                        const Text(
                          "Event Color",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: eventColors.map((color) {
                            final isSelected = selectedColor == color;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => selectedColor = color),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xff4583FF)
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 30),

                        // CLASS SELECTION -----------------------
                        const Text(
                          "Class selection",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            // ALL
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (selectedClasses.length == allClasses.length) {
                                    // ✅ already all selected → unselect all
                                    selectedClasses.clear();
                                  } else {
                                    // ✅ not all selected → select all
                                    selectedClasses = List.from(allClasses);
                                  }
                                });
                              },
                              child: _classChip(
                                "ALL",
                                selectedClasses.length == allClasses.length,
                              ),
                            ),
                            ...allClasses
                                .map(
                                  (cls) => GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (selectedClasses.contains(cls)) {
                                      selectedClasses.remove(cls);
                                    } else {
                                      selectedClasses.add(cls);
                                    }
                                  });
                                },
                                child: _classChip(
                                  cls,
                                  selectedClasses.contains(cls),
                                ),
                              ),
                            )
                                .toList(),
                          ],
                        ),

                        const SizedBox(height: 35),
                        Container(height: 1, color: Colors.grey.shade300),
                        const SizedBox(height: 22),

                        // BUTTONS ROW -----------------------
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff2970FF),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                if (titleController.text.trim().isEmpty) {
                                  return _showSnack("Enter event title");
                                }
                                if (descController.text.trim().isEmpty) {
                                  return _showSnack("Enter description");
                                }
                                if (startDate == null ||
                                    startTime == null ||
                                    endDate == null ||
                                    endTime == null) {
                                  return _showSnack(
                                      "Select date & time");
                                }
                                if (selectedColor == null) {
                                  return _showSnack("Select a color");
                                }
                                if (selectedClasses.isEmpty) {
                                  return _showSnack(
                                      "Select at least 1 class");
                                }

                                final startDateTime = DateTime(
                                  startDate!.year,
                                  startDate!.month,
                                  startDate!.day,
                                  startTime!.hour,
                                  startTime!.minute,
                                );

                                final endDateTime = DateTime(
                                  endDate!.year,
                                  endDate!.month,
                                  endDate!.day,
                                  endTime!.hour,
                                  endTime!.minute,
                                );

                                final colorString =
                                    "0x${selectedColor!.value.toRadixString(16)}";

                                final event = EventModel(
                                  title: titleController.text.trim(),
                                  description:
                                  descController.text.trim(),
                                  color: colorString,
                                  startDateTime: startDateTime,
                                  endDateTime: endDateTime,
                                  classes: selectedClasses,
                                  createdAt: existingEvent?.createdAt ??
                                      DateTime.now(),
                                  delete:
                                  existingEvent?.delete ?? false,
                                );

                                try {
                                  await ref
                                      .read(eventControllerProvider.notifier)
                                      .saveEvent(
                                    event,
                                    oldTitle: existingEvent?.title,
                                  );

                                  Navigator.pop(context);
                                  _showSnack(
                                    isEdit
                                        ? "Event updated successfully"
                                        : "Event saved successfully",
                                    success: true,
                                  );
                                } catch (e) {
                                  _showSnack("Error: $e");
                                }
                              },
                              child: Text(
                                isEdit ? "Update Event" : "Save Event",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _classChip(String label, bool selected) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xff4583FF) : Colors.grey.shade300,
        ),
        color: selected ? const Color(0xffE8F0FF) : const Color(0xfff4f7fa),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color:
          selected ? const Color(0xff2970FF) : Colors.black87,
        ),
      ),
    );
  }

  void _showAddEventConfirm(DateTime date) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Event"),
          content: Text(
              "Do you want to mark an event on ${DateFormat('dd MMM yyyy').format(date)}?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                /// 👉 OPEN EVENT DIALOG WITH PREFILLED DATE
                _showAddEditEventDialog(date: date);
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  void _showEventsListDialog(List<EventModel> events) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Events"),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final e = events[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(e.color),
                  ),
                  title: Text(e.title),
                  subtitle: Text(
                    "${DateFormat('dd MMM, hh:mm a').format(e.startDateTime)}",
                  ),

                  /// 👉 CLICK TO EDIT
                  onTap: () {
                    Navigator.pop(context);

                    _showAddEditEventDialog(existingEvent: e);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
  // ------------------------------------------------------------
  // MAIN PAGE UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f9fc),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildCalendarCard()),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildQuickLinks()),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CALENDAR CARD
  // ------------------------------------------------------------
  Widget _buildCalendarCard() {
    final currentMonth = ref.watch(selectedMonthProvider);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _calendarHeader(currentMonth),
          const SizedBox(height: 15),
          _weekDaysRow(),
          const SizedBox(height: 10),
          Expanded(
            child: ref.watch(eventControllerProvider).when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) {
                log(error.toString());
                return Center(child: Text("Error :$error"),);
              },
              data: (events) {

                final eventsByDate = _groupEventsByDate(events);
                return _buildCalendarGrid(currentMonth, eventsByDate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarHeader(DateTime currentMonth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(currentMonth),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            _arrowButton(Icons.chevron_left, () {
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(currentMonth.year, currentMonth.month - 1);
            }),
            const SizedBox(width: 5),
            _arrowButton(Icons.chevron_right, () {
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(currentMonth.year, currentMonth.month + 1);
            }),
          ],
        )
      ],
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 22),
      onPressed: onPressed,
    );
  }

  Widget _weekDaysRow() {
    const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => Text(
          day,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _buildCalendarGrid(
      DateTime currentMonth,
      Map<DateTime, List<EventModel>> eventsByDate,
      ) {
    final first = DateTime(currentMonth.year, currentMonth.month, 1);
    final last = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    final totalDays = last.day;
    final emptySlots = first.weekday % 7;

    List<Widget> cells = [];

    for (int i = 0; i < emptySlots; i++) {
      cells.add(_emptyBox());
    }

    for (int day = 1; day <= totalDays; day++) {
      final dateKey = DateTime(currentMonth.year, currentMonth.month, day);
      final events = eventsByDate[dateKey];
      cells.add(_dateBox(day, events));
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 1.2,
      scrollDirection: Axis.vertical,
      children: cells,
    );
  }

  Widget _dateBox(int day, List<EventModel>? eventsForDay) {
    final currentMonth = ref.read(selectedMonthProvider);

    final date = DateTime(
      currentMonth.year,
      currentMonth.month,
      day,
    );

    final hasEvent = eventsForDay != null && eventsForDay.isNotEmpty;

    Color? dotColor;
    if (hasEvent) {
      dotColor = _parseColor(eventsForDay.first.color);
    }

    /// ✅ Build tooltip message
    String tooltipMessage = "";

    if (hasEvent) {
      tooltipMessage = eventsForDay!
          .map((e) =>
      "Event Tittle    : ${e.title}\nStarting date : ${DateFormat('dd MMM, hh:mm a').format(e.startDateTime)}\nEnding Date  : ${DateFormat('dd MMM, hh:mm a').format(e.endDateTime)} ")
          .join("\n\n\n");
    }

    return Tooltip(
      message: tooltipMessage,
      preferBelow: true,
      textStyle: TextStyle(fontSize: 12,fontWeight: FontWeight.w500,color: Colors.white),
      decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(10),),
      verticalOffset: 20,
      child: InkWell(
        onTap: () {
          if (hasEvent) {
            _showEventsListDialog(eventsForDay!);
          }else{
            _showAddEventConfirm(date);
          }
        },
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: _dayBoxDecoration(date),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.toString().padLeft(2, "0"),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              if (hasEvent)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyBox() {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
    );
  }

  Map<DateTime, List<EventModel>> _groupEventsByDate(
      List<EventModel> events) {
    final Map<DateTime, List<EventModel>> map = {};

    for (final e in events) {
      DateTime current = DateTime(
        e.startDateTime.year,
        e.startDateTime.month,
        e.startDateTime.day,
      );
      final last = DateTime(
        e.endDateTime.year,
        e.endDateTime.month,
        e.endDateTime.day,
      );

      while (!current.isAfter(last)) {
        final key = DateTime(current.year, current.month, current.day);
        map.putIfAbsent(key, () => []);
        map[key]!.add(e);
        current = current.add(const Duration(days: 1));
      }
    }

    return map;
  }

  // ------------------------------------------------------------
  // QUICK LINKS (EVENTS LIST for selected month)
  // ------------------------------------------------------------
  Widget _buildQuickLinks() {
    final currentMonth = ref.watch(selectedMonthProvider);
    final eventState = ref.watch(eventControllerProvider);

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Quick Links",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff3478FF),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showAddEditEventDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  "Add Event",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: eventState.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (allEvents) {
                final monthStart = DateTime(
                    currentMonth.year, currentMonth.month, 1);
                final monthEnd = DateTime(
                    currentMonth.year, currentMonth.month + 1, 0);

                final monthEvents = allEvents.where((event) {
                  return event.startDateTime.isBefore(
                      monthEnd.add(const Duration(days: 1))) &&
                      event.endDateTime.isAfter(
                          monthStart.subtract(const Duration(days: 1)));
                }).toList()
                  ..sort((a, b) =>
                      b.startDateTime.compareTo(a.startDateTime));

                if (monthEvents.isEmpty) {
                  return const Center(
                    child: Text(
                      "Events are empty",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: monthEvents.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _eventTile(monthEvents[index], currentMonth);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EVENT TILE WITH 3 DOT MENU
  // ------------------------------------------------------------
  Widget _eventTile(EventModel event, DateTime currentMonth) {
    final baseColor = _parseColor(event.color);
    final bgColor = baseColor.withOpacity(0.15);

    final monthText =
    DateFormat('MMM').format(currentMonth).toUpperCase();
    final dayLabel = _buildMonthSpecificDayLabel(event, currentMonth);
    final subtitle = _buildEventSubtitle(event);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _eventCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date box
          Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  monthText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dayLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // 3 DOT MENU
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showAddEditEventDialog(existingEvent: event);
              } else if (value == 'delete') {
                _confirmDeleteEvent(event);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text("Edit"),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text("Delete"),
              ),
            ],
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }

  // SUBTITLE LOGIC
  String _buildEventSubtitle(EventModel event) {
    final start = event.startDateTime;
    final end = event.endDateTime;

    final startDateOnly =
    DateTime(start.year, start.month, start.day);
    final endDateOnly =
    DateTime(end.year, end.month, end.day);

    if (startDateOnly == endDateOnly) {
      final startTimeStr = DateFormat('h:mm a').format(start);
      final endTimeStr = DateFormat('h:mm a').format(end);
      return '$startTimeStr - $endTimeStr';
    } else {
      final startStr = DateFormat('dd MMM yyyy').format(start);
      final endStr = DateFormat('dd MMM yyyy').format(end);
      return '$startStr - $endStr';
    }
  }

  // DAY LABEL LOGIC (only days inside selected month)
  String _buildMonthSpecificDayLabel(
      EventModel event, DateTime month) {
    final start = event.startDateTime;
    final end = event.endDateTime;

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final visibleStart =
    start.isBefore(monthStart) ? monthStart : start;
    final visibleEnd = end.isAfter(monthEnd) ? monthEnd : end;

    if (visibleStart.day == visibleEnd.day) {
      return visibleStart.day.toString();
    } else {
      return '${visibleStart.day} - ${visibleEnd.day}';
    }
  }

  // DELETE CONFIRMATION
  void _confirmDeleteEvent(EventModel event) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Event"),
          content: Text(
              'Are you sure you want to delete "${event.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(eventControllerProvider.notifier)
                      .deleteEvent(event.title);
                  Navigator.pop(context);
                  _showSnack("Event deleted", success: true);
                } catch (e) {
                  Navigator.pop(context);
                  _showSnack("Error deleting: $e");
                }
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------- HELPERS -----------------
  Color _parseColor(String colorString) {
    try {
      String value = colorString;
      if (value.startsWith('0x')) {
        value = value.substring(2);
      } else if (value.startsWith('#')) {
        value = value.substring(1);
      }
      final intColor = int.parse(value, radix: 16);
      return Color(intColor);
    } catch (_) {
      return const Color(0xff2970FF);
    }
  }

  // ------------------------------------------------------------
  // DECORATIONS
  // ------------------------------------------------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  BoxDecoration _dayBoxDecoration(DateTime date) {
    final now = DateTime.now();

    final bool isToday =
        date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

    return BoxDecoration(
      color: isToday
          ? const Color(0xff2970FF).withOpacity(0.1) // 🔵 TODAY
          : Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    );
  }

  BoxDecoration _eventCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
    );
  }
}
