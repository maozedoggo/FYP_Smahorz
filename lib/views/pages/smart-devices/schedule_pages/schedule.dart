import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchedulePage extends StatefulWidget {
  final String deviceName;

  const SchedulePage({super.key, required this.deviceName});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime today = DateTime.now();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedulesForDay(today);
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    setState(() {
      today = day;
      _loading = true;
    });
    _loadSchedulesForDay(day);
  }

  /// Fetch schedules for the selected day
  Future<void> _loadSchedulesForDay(DateTime day) async {
    try {
      final selectedDate =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

      final snapshot = await _firestore
          .collection('devices')
          .doc(widget.deviceName)
          .collection('schedules')
          .where('date', isEqualTo: selectedDate)
          .get();

      setState(() {
        _schedules = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'time': doc['time'] ?? '',
            'action': doc['action'] ?? '',
            'date': doc['date'] ?? '',
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading schedules: $e')));
      }
      setState(() => _loading = false);
    }
  }

  /// Add schedule to Firestore
  Future<void> _addSchedule(String time, String action) async {
    final dateKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    await _firestore
        .collection('devices')
        .doc(widget.deviceName)
        .collection('schedules')
        .add({
          'date': dateKey,
          'time': time,
          'action': action,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _loadSchedulesForDay(today);
  }

  /// Delete schedule from Firestore
  Future<void> _deleteSchedule(String id) async {
    await _firestore
        .collection('devices')
        .doc(widget.deviceName)
        .collection('schedules')
        .doc(id)
        .delete();

    await _loadSchedulesForDay(today);
  }

  void _addScheduleDialog() {
    TimeOfDay? selectedTime;
    String selectedAction = "Turn ON"; // default action

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2233),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                "Add Schedule",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time picker
                  ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      selectedTime == null
                          ? "Select time"
                          : selectedTime!.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          // Dark theme for the time picker
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Colors.blueAccent,
                                onSurface: Colors.white,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Action toggle buttons
                  const Text(
                    "Select Action",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Turn ON"),
                        labelStyle: TextStyle(
                          color: selectedAction == "Turn ON"
                              ? Colors.white
                              : Colors.black,
                        ),
                        selected: selectedAction == "Turn ON",
                        selectedColor: Colors.blueAccent,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => selectedAction = "Turn ON");
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Turn OFF"),
                        labelStyle: TextStyle(
                          color: selectedAction == "Turn OFF"
                              ? Colors.white
                              : Colors.black,
                        ),
                        selected: selectedAction == "Turn OFF",
                        selectedColor: Colors.redAccent,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => selectedAction = "Turn OFF");
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text("Add"),
                  onPressed: () async {
                    if (selectedTime != null) {
                      final formattedTime = selectedTime!.format(context);
                      Navigator.pop(context);
                      await _addSchedule(formattedTime, selectedAction);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a time")),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = "${today.day}/${today.month}/${today.year}";

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: _addScheduleDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Device Name
            Align(
              child: Text(
                widget.deviceName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            // Calendar
            TableCalendar(
              focusedDay: today,
              firstDay: DateTime.utc(2025, 10, 1),
              lastDay: DateTime.utc(2050, 12, 31),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              daysOfWeekVisible: true,
              enabledDayPredicate: (day) {
                return !day.isBefore(
                  DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                  ),
                );
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
              ),
              availableGestures: AvailableGestures.all,
              rowHeight: 60,
              onDaySelected: _onDaySelected,
              selectedDayPredicate: (day) => isSameDay(today, day),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.lightBlue[100],
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
                defaultTextStyle: const TextStyle(color: Colors.white),
                disabledTextStyle: const TextStyle(color: Colors.grey),
              ),
            ),

            const SizedBox(height: 10),

            // Schedule title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Schedules for $selectedDate",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Schedule List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  : _schedules.isEmpty
                  ? const Center(
                      child: Text(
                        "No schedules yet.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = _schedules[index];
                        return Card(
                          color: const Color(0xFF1C2233),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.access_time,
                              color: Colors.blueAccent,
                            ),
                            title: Text(
                              schedule['action'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              schedule['time'],
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => _deleteSchedule(schedule['id']),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
