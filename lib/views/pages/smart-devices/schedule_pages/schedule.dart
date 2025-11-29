import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

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
        'status': widget.deviceType.toLowerCase().contains('parcel')
            ? {'insideStatus': false, 'outsideStatus': false}
            : false,
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
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final devicePath = '${widget.householdUid}/${widget.deviceId}';

      // Load from Realtime Database
      final snapshot = await _realtimeDB.child('$devicePath/schedules').once();

      final schedules = <Map<String, dynamic>>[];

      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          if (value['date'] == dateKey) {
            schedules.add({
              'id': key,
              'time': value['time'] ?? '',
              'action': value['action'] ?? '',
              'door': value['door'] ?? '',
              'date': value['date'] ?? '',
              'executed': value['executed'] ?? false,
              'executedAt': value['executedAt'],
            });
          }
        });

        // Sort by time
        schedules.sort((a, b) => a['time'].compareTo(b['time']));
      }

      setState(() {
        _schedules = schedules;
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

  Future<void> _addSchedule(
    String time,
    String action, {
    String door = '',
  }) async {
    final devicePath = '${widget.householdUid}/${widget.deviceId}';

    final scheduleData = {
      'time': time,
      'date': DateFormat('yyyy-MM-dd').format(selectedDay),
      'action': action,
      'executed': false,
    };

    // Add door for parcel box
    if (widget.deviceType.toLowerCase().contains('parcel') && door.isNotEmpty) {
      scheduleData['door'] = door;
    }

    // Save directly to Realtime Database
    await _realtimeDB.child('$devicePath/schedules').push().set(scheduleData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule added successfully!')),
      );
    }

    await _loadSchedulesForDay(selectedDay);
  }

  Future<void> _deleteSchedule(String id) async {
    final devicePath = '${widget.householdUid}/${widget.deviceId}';
    await _realtimeDB.child('$devicePath/schedules/$id').remove();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule deleted!')));
    }

    await _loadSchedulesForDay(selectedDay);
  }

  // Manual trigger for testing
  Future<void> _triggerScheduleNow(
    String scheduleId,
    String action, {
    String door = '',
  }) async {
    try {
      final devicePath = '${widget.householdUid}/${widget.deviceId}';

      // Update device status
      if (widget.deviceType.toLowerCase().contains('parcel')) {
        final doorPath = door == 'Inside' ? 'insideStatus' : 'outsideStatus';
        final status = action == 'Unlock';
        await _realtimeDB.child('$devicePath/$doorPath').set(status);
      } else {
        final status = action == 'Extend';
        await _realtimeDB.child('$devicePath/status').set(status);
      }

      // Mark as executed
      await _realtimeDB.child('$devicePath/schedules/$scheduleId').update({
        'executed': true,
        'executedAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Schedule executed: $action ${door.isNotEmpty ? '($door)' : ''}',
            ),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 300));
      await _loadSchedulesForDay(selectedDay);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error executing schedule: $e')));
      }
    }
  }

  void _addScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TimeOfDay? selectedTime = TimeOfDay.now();
        String selectedAction =
            widget.deviceType.toLowerCase().contains('parcel')
            ? "Unlock"
            : "Extend";
        String selectedDoor = "Inside";

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1C2233),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                "Add Schedule for ${widget.deviceName}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time Selection
                  ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      selectedTime == null
                          ? "Select time"
                          : selectedTime!.format(dialogContext),
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
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
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Door Selection (Only for Parcel Box)
                  if (widget.deviceType.toLowerCase().contains('parcel')) ...[
                    const Text(
                      "Select Door",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text("Inside"),
                          labelStyle: TextStyle(
                            color: selectedDoor == "Inside"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedDoor == "Inside",
                          selectedColor: Colors.blueAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedDoor = "Inside";
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text("Outside"),
                          labelStyle: TextStyle(
                            color: selectedDoor == "Outside"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedDoor == "Outside",
                          selectedColor: Colors.greenAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedDoor = "Outside";
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Selection
                  const Text(
                    "Select Action",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),

                  // Inline action chips (not using separate method)
                  if (widget.deviceType.toLowerCase().contains('parcel'))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text("Unlock"),
                          labelStyle: TextStyle(
                            color: selectedAction == "Unlock"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedAction == "Unlock",
                          selectedColor: Colors.green,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedAction = "Unlock";
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text("Lock"),
                          labelStyle: TextStyle(
                            color: selectedAction == "Lock"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedAction == "Lock",
                          selectedColor: Colors.redAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedAction = "Lock";
                              });
                            }
                          },
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text("Extend"),
                          labelStyle: TextStyle(
                            color: selectedAction == "Extend"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedAction == "Extend",
                          selectedColor: Colors.blueAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedAction = "Extend";
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text("Retract"),
                          labelStyle: TextStyle(
                            color: selectedAction == "Retract"
                                ? Colors.white
                                : Colors.black,
                          ),
                          selected: selectedAction == "Retract",
                          selectedColor: Colors.redAccent,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedAction = "Retract";
                              });
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
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text("Add"),
                  onPressed: () async {
                    if (selectedTime != null) {
                      final formattedTime =
                          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
                      Navigator.pop(dialogContext);

                      if (widget.deviceType.toLowerCase().contains('parcel')) {
                        await _addSchedule(
                          formattedTime,
                          selectedAction,
                          door: selectedDoor,
                        );
                      } else {
                        await _addSchedule(formattedTime, selectedAction);
                      }
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

  Widget _buildParcelBoxActions(String selectedAction, Function setState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text("Unlock"),
          labelStyle: TextStyle(
            color: selectedAction == "Unlock" ? Colors.white : Colors.black,
          ),
          selected: selectedAction == "Unlock",
          selectedColor: Colors.green,
          onSelected: (selected) {
            if (selected) setState(() => selectedAction = "Unlock");
          },
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text("Lock"),
          labelStyle: TextStyle(
            color: selectedAction == "Lock" ? Colors.white : Colors.black,
          ),
          selected: selectedAction == "Lock",
          selectedColor: Colors.redAccent,
          onSelected: (selected) {
            if (selected) setState(() => selectedAction = "Lock");
          },
        ),
      ],
    );
  }

  Widget _buildClothesHangerActions(String selectedAction, Function setState) {
    return Row(
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
    );
  }

  String _getScheduleDisplayText(Map<String, dynamic> schedule) {
    if (widget.deviceType.toLowerCase().contains('parcel')) {
      final door = schedule['door'] ?? '';
      final action = schedule['action'] ?? '';
      return '$door Door - $action';
    } else {
      return schedule['action'] ?? '';
    }
  }

  Color _getScheduleStatusColor(Map<String, dynamic> schedule) {
    return schedule['executed'] == true ? Colors.green : Colors.blueAccent;
  }

  String _getExecutionInfo(Map<String, dynamic> schedule) {
    if (schedule['executed'] == true) {
      final executedAt = schedule['executedAt'];
      if (executedAt != null) {
        final date = executedAt.toDate();
        return 'Executed at ${DateFormat('HH:mm').format(date)}';
      }
      return 'Executed';
    }
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateStr = DateFormat('dd/MM/yyyy').format(selectedDay);

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
                "${widget.deviceName} Schedules",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            TableCalendar(
              focusedDay: selectedDay,
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              onDaySelected: _onDaySelected,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.grey[850],
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
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: Colors.white70,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: Colors.white70,
                ),
                titleTextStyle: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),

            const SizedBox(height: 10),

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
                    "Schedules for $selectedDateStr",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

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
                        "No schedules yet.\nTap + to add one!",
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                        textAlign: TextAlign.center,
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
                            leading: Icon(
                              Icons.access_time,
                              color: _getScheduleStatusColor(schedule),
                            ),
                            title: Text(
                              _getScheduleDisplayText(schedule),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                decoration: schedule['executed'] == true
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schedule['time'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Text(
                                  _getExecutionInfo(schedule),
                                  style: TextStyle(
                                    color: schedule['executed'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Manual trigger button
                                if (schedule['executed'] != true)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _triggerScheduleNow(
                                      schedule['id'],
                                      schedule['action'],
                                      door: schedule['door'] ?? '',
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () =>
                                      _deleteSchedule(schedule['id']),
                                ),
                              ],
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
