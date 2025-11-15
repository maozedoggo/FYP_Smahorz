import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/schedule_pages/schedule.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class DeviceControlPage extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String deviceType;

  const DeviceControlPage({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
  });

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  bool isUnlocked = false;
  String? householdUid;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instance.ref();
  String _currentStatus = "Unknown";

  @override
  void initState() {
    super.initState();
    _loadHouseholdUid();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    // Listen to motor status
    _realtimeDB.child('motor').onValue.listen((event) {
      if (event.snapshot.exists) {
        final status = event.snapshot.value;
        setState(() {
          isUnlocked = status == true;
          _currentStatus = status == true ? "Extended" : "Retracted";
        });
      }
    });

    // Listen to hanger status for real-time updates
    _realtimeDB.child('hanger/status').onValue.listen((event) {
      if (event.snapshot.exists) {
        final status = event.snapshot.value.toString();
        setState(() {
          _currentStatus = status;
          if (status.contains('extending')) {
            _currentStatus = "Extending...";
          } else if (status.contains('retracting')) {
            _currentStatus = "Retracting...";
          } else if (status.contains('extended')) {
            _currentStatus = "Extended";
            isUnlocked = true;
          } else if (status.contains('retracted')) {
            _currentStatus = "Retracted";
            isUnlocked = false;
          }
        });
      }
    });
  }

  void toggleUnlock() {
    setState(() {
      isUnlocked = !isUnlocked;
    });
    
    // Control clothes hanger via Realtime Database
    _realtimeDB.child('motor').set(isUnlocked);
  }

  Future<void> _loadHouseholdUid() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser!.email!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('householdId')) {
        setState(() {
          householdUid = userDoc['householdId'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Household ID not found.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching household ID: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0063A1), Color(0xFF0982BA), Color(0xFF04111C)],
            stops: [0.21, 0.41, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),

              // Device name
              Text(
                widget.deviceName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Device type
              Text(
                "Type: ${widget.deviceType}",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              
              // Current status
              Text(
                "Status: $_currentStatus",
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),

              // Extend/Retract button
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: toggleUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked ? Colors.red : Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isUnlocked ? "RETRACT" : "EXTEND",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Navigate to Schedule Page
              ElevatedButton.icon(
                onPressed: householdUid == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SchedulePage(
                              deviceName: widget.deviceName,
                              deviceId: widget.deviceId,
                              householdUid: householdUid!,
                              deviceType: widget.deviceType,
                            ),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: householdUid == null ? Colors.grey : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, color: Colors.black),
                label: const Text(
                  "Add Schedule",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}