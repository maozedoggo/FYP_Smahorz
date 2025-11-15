import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class SchedulePage extends StatefulWidget {
  final String deviceName;
  final String deviceId;
  final String householdUid;
  final String deviceType;

  const SchedulePage({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.householdUid,
    required this.deviceType,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime selectedDay = DateTime.now();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureDeviceDocument();
      await _loadSchedulesForDay(selectedDay);
    });
  }

  Future<void> _ensureDeviceDocument() async {
    final deviceDocRef = _firestore
        .collection('households')
        .doc(widget.householdUid)
        .collection('devices')
        .doc(widget.deviceId);

    final docSnapshot = await deviceDocRef.get();
    if (!docSnapshot.exists) {
      await deviceDocRef.set({
        'name': widget.deviceName,
        'type': widget.deviceType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _onDaySelected(DateTime day, DateTime focusedDay) {
    if (day.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      return;
    }
    setState(() {
      selectedDay = day;
      _loading = true;
    });
    _loadSchedulesForDay(day);
  }

  Future<void> _loadSchedulesForDay(DateTime day) async {
    try {
      final dateKey =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

      final snapshot = await _firestore
          .collection('households')
          .doc(widget.householdUid)
          .collection('devices')
          .doc(widget.deviceId)
          .collection('schedules')
          .where('date', isEqualTo: dateKey)
          .orderBy('time')
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading schedules: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _addSchedule(String time, String action) async {
    await _ensureDeviceDocument();
    final dateKey =
        "${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}";

    await _firestore
        .collection('households')
        .doc(widget.householdUid)
        .collection('devices')
        .doc(widget.deviceId)
        .collection('schedules')
        .add({
          'date': dateKey,
          'time': time,
          'action': action,
          'createdAt': FieldValue.serverTimestamp(),
        });

    // If this is for clothes hanger, you can add logic to trigger Realtime Database
    if (widget.deviceType.toLowerCase().contains('hanger') || 
        widget.deviceType.toLowerCase().contains('clothe')) {
      // You could set up a Cloud Function to trigger this based on schedule
      // For now, we just store the schedule in Firestore
    }

    await _loadSchedulesForDay(selectedDay);
  }

  Future<void> _deleteSchedule(String id) async {
    await _firestore
        .collection('households')
        .doc(widget.householdUid)
        .collection('devices')
        .doc(widget.deviceId)
        .collection('schedules')
        .doc(id)
        .delete();

    await _loadSchedulesForDay(selectedDay);
  }

  void _addScheduleDialog() {
    TimeOfDay? selectedTime;
    String selectedAction = "Turn ON";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2233),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                "Add Schedule",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                    title: Text(
                      selectedTime == null ? "Select time" : selectedTime!.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
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
                        setState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text("Select Action", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("Extend"),
                        labelStyle: TextStyle(
                          color: selectedAction == "Extend" ? Colors.white : Colors.black,
                        ),
                        selected: selectedAction == "Extend",
                        selectedColor: Colors.blueAccent,
                        onSelected: (selected) {
                          if (selected) setState(() => selectedAction = "Extend");
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("Retract"),
                        labelStyle: TextStyle(
                          color: selectedAction == "Retract" ? Colors.white : Colors.black,
                        ),
                        selected: selectedAction == "Retract",
                        selectedColor: Colors.redAccent,
                        onSelected: (selected) {
                          if (selected) setState(() => selectedAction = "Retract");
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
    final selectedDateStr = "${selectedDay.day}/${selectedDay.month}/${selectedDay.year}";

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

            Align(
              child: Text(
                widget.deviceName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),

            TableCalendar(
              focusedDay: selectedDay,
              firstDay: DateTime.now(),
              lastDay: DateTime.utc(2050, 12, 31),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              onDaySelected: _onDaySelected,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: Colors.grey[850], shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
                defaultTextStyle: const TextStyle(color: Colors.white),
                disabledTextStyle: const TextStyle(color: Colors.grey),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
                titleTextStyle: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Schedules for $selectedDateStr",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : _schedules.isEmpty
                  ? const Center(child: Text("No schedules yet.", style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = _schedules[index];
                        return Card(
                          color: const Color(0xFF1C2233),
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: const Icon(Icons.access_time, color: Colors.blueAccent),
                            title: Text(
                              schedule['action'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(schedule['time'], style: const TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
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