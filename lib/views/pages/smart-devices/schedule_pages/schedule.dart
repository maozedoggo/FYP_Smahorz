import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
  final DatabaseReference _realtimeDB = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  List<Map<String, dynamic>> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSchedulesForDay(selectedDay);
    });
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

      print('📅 Loading schedules from Realtime DB for: $dateKey');
      print('📁 Path: $devicePath/schedules');

      // Load from Realtime Database
      final snapshot = await _realtimeDB.child('$devicePath/schedules').once();

      final schedules = <Map<String, dynamic>>[];

      if (snapshot.snapshot.value != null) {
        final data = snapshot.snapshot.value as Map<dynamic, dynamic>;

        print('📦 Raw schedule data: $data');

        data.forEach((key, value) {
          if (value is Map && value['date'] == dateKey) {
            print('✅ Found matching schedule: $key -> $value');
            schedules.add({
              'id': key.toString(),
              'time': value['time']?.toString() ?? '',
              'action': value['action']?.toString() ?? '',
              'door': value['door']?.toString() ?? '',
              'date': value['date']?.toString() ?? '',
              'executed': value['executed'] == true,
            });
          }
        });

        // Sort by time
        schedules.sort((a, b) => a['time'].compareTo(b['time']));
      } else {
        print('⚠️ No schedule data found at path: $devicePath/schedules');
      }

      print('📋 Total schedules loaded: ${schedules.length}');

      setState(() {
        _schedules = schedules;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading schedules: $e');
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
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Add door for parcel box
    if (widget.deviceType.toLowerCase().contains('parcel') && door.isNotEmpty) {
      scheduleData['door'] = door;
    }

    print('➕ Adding schedule to Realtime DB: $scheduleData');

    try {
      // PRIMARY: Save to Realtime Database (where Cloud Function reads)
      final newScheduleRef = _realtimeDB.child('$devicePath/schedules').push();
      final scheduleId = newScheduleRef.key!;

      await newScheduleRef.set(scheduleData);
      print('✅ Schedule added to Realtime DB with ID: $scheduleId');

      // ✅ ADD LOGGING HERE
      await _logScheduleActivity(
        action: action,
        scheduleTime: time,
        door: door,
      );

      // SECONDARY: Optional backup to Firestore
      try {
        await _firestore
            .collection('households')
            .doc(widget.householdUid)
            .collection('devices')
            .doc(widget.deviceId)
            .collection('schedules')
            .doc(scheduleId) // Use same ID for consistency
            .set(scheduleData);
        print('✅ Backup saved to Firestore');
      } catch (firestoreError) {
        print('⚠️ Firestore backup failed (non-critical): $firestoreError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule added successfully!')),
        );
      }

      await _loadSchedulesForDay(selectedDay);
    } catch (e) {
      print('❌ Error adding schedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding schedule: $e')));
      }
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final devicePath = '${widget.householdUid}/${widget.deviceId}';

    print('🗑️ Deleting schedule from Realtime DB: $id');

    try {
      // Get schedule details before deleting (for logging)
      final scheduleSnapshot = await _realtimeDB
          .child('$devicePath/schedules/$id')
          .once();

      final scheduleData =
          scheduleSnapshot.snapshot.value as Map<dynamic, dynamic>?;

      // Delete from Realtime Database
      await _realtimeDB.child('$devicePath/schedules/$id').remove();
      print('✅ Schedule deleted from Realtime DB');

      // Log deletion activity
      if (scheduleData != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          try {
            await _firestore
                .collection('households')
                .doc(widget.householdUid)
                .collection('members')
                .doc(user.email!)
                .collection('activityLog')
                .add({
                  'userEmail': user.email!,
                  'deviceId': widget.deviceId,
                  'deviceName': widget.deviceName,
                  'action':
                      'Deleted schedule for ${scheduleData['time'] ?? 'unknown time'}',
                  'timestamp': FieldValue.serverTimestamp(),
                });
            print('✅ Schedule deletion logged');
          } catch (e) {
            print('⚠️ Failed to log schedule deletion: $e');
          }
        }
      }

      // Also delete from Firestore backup
      try {
        await _firestore
            .collection('households')
            .doc(widget.householdUid)
            .collection('devices')
            .doc(widget.deviceId)
            .collection('schedules')
            .doc(id)
            .delete();
        print('✅ Also deleted from Firestore backup');
      } catch (firestoreError) {
        print('⚠️ Firestore delete failed (non-critical): $firestoreError');
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule deleted!')));
      }

      await _loadSchedulesForDay(selectedDay);
    } catch (e) {
      print('❌ Error deleting schedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting schedule: $e')));
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

                  // Inline action chips
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

  // Add this method inside _SchedulePageState class
  Future<void> _logScheduleActivity({
    required String action,
    required String scheduleTime,
    String door = '',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        print("User not logged in, skipping schedule logging");
        return;
      }

      final householdDoc = await _firestore
          .collection('households')
          .doc(widget.householdUid)
          .get();

      if (!householdDoc.exists) {
        print("Household not found, skipping logging");
        return;
      }

      // Get user's username
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
      final username = userDoc.data()?['username'] ?? user.email!;
      final role = userDoc.data()?['role'] ?? 'member';

      // Ensure member document exists
      final memberRef = _firestore
          .collection('households')
          .doc(widget.householdUid)
          .collection('members')
          .doc(user.email!);

      await memberRef.set({
        'username': username,
        'role': role,
      }, SetOptions(merge: true));

      // Log the schedule creation activity
      await _firestore
          .collection('households')
          .doc(widget.householdUid)
          .collection('members')
          .doc(user.email!)
          .collection('activityLog')
          .add({
            'userEmail': user.email!,
            'deviceId': widget.deviceId,
            'deviceName': widget.deviceName,
            'action': _formatScheduleAction(action, scheduleTime, door),
            'timestamp': FieldValue.serverTimestamp(),
          });

      print("✅ Schedule creation logged to activity log");
    } catch (e) {
      print("❌ Error logging schedule activity: $e");
      // Don't show error to user - logging failure shouldn't affect schedule creation
    }
  }

  // Helper method to format the schedule action text
  String _formatScheduleAction(String action, String time, String door) {
    final formattedTime = time.padLeft(5, '0'); // Ensure HH:MM format

    if (widget.deviceType.toLowerCase().contains('parcel')) {
      final doorText = door.isNotEmpty ? " ($door Door)" : "";
      return "Scheduled to $action$doorText at $formattedTime";
    } else {
      return "Scheduled to $action at $formattedTime";
    }
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

  String _getExecutionStatus(Map<String, dynamic> schedule) {
    return schedule['executed'] == true ? 'Executed' : 'Pending';
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
                selectedDecoration: const BoxDecoration(
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
                        "No schedules yet",
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
                              schedule['time'],
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
                                  _getScheduleDisplayText(schedule),
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getExecutionStatus(schedule),
                                  style: TextStyle(
                                    color: schedule['executed'] == true
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
