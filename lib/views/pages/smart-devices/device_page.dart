import 'dart:async';

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
  bool _deviceStatus = false;
  String? householdUid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    _loadHouseholdUid();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListener(String householdId) {
    final path = '$householdId/${widget.deviceId}/status';
    print("DeviceControlPage listening to: $path");

    _deviceSubscription = _realtimeDB
        .child(path)
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.exists && mounted) {
        final status = event.snapshot.value;
        final bool isOn = status == true;
        
        setState(() {
          _deviceStatus = isOn;
        });
        
        print("DeviceControlPage update: ${widget.deviceId} = $isOn");
      }
    }, onError: (error) {
      print("DeviceControlPage listener error: $error");
    });
  }

  void _toggleDevice() async {
    if (householdUid == null) {
      print("No household ID available");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Household ID not found.")),
      );
      return;
    }

    final newStatus = !_deviceStatus;
    setState(() {
      _deviceStatus = newStatus;
    });
    
    try {
      print("=== DEVICE CONTROL PAGE - TOGGLING DEVICE ===");
      print("Device ID: ${widget.deviceId}");
      print("Household ID: $householdUid");
      print("New Status: $newStatus");

      // Update Firestore
      await _firestore
          .collection('devices')
          .doc(widget.deviceId)
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
      print("✓ DeviceControlPage updated Firestore");

      // Update Realtime Database under household
      await _realtimeDB
          .child('$householdUid/${widget.deviceId}/status')
          .set(newStatus);
      print("✓ DeviceControlPage updated Realtime DB: $householdUid/${widget.deviceId}/status = $newStatus");

      // Verify the write
      final snapshot = await _realtimeDB.child('$householdUid/${widget.deviceId}/status').get();
      if (snapshot.exists) {
        print("✓ Verification - Current value in Realtime DB: ${snapshot.value}");
      } else {
        print("✗ Verification failed - No data at path");
      }

    } catch (error) {
      print("✗ Error controlling device: $error");
      // Revert on error
      setState(() {
        _deviceStatus = !newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error controlling device: $error")),
      );
    }
  }

  Future<void> _loadHouseholdUid() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser!.email!;
      final userDoc = await _firestore
          .collection('users')
          .doc(userEmail)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('householdId')) {
        final householdId = userDoc['householdId'];
        setState(() {
          householdUid = householdId;
        });
        _setupRealtimeListener(householdId);
        print("DeviceControlPage loaded household: $householdId");
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

  String _getStatusText() {
    if (widget.deviceType.toLowerCase().contains('hanger') || 
        widget.deviceType.toLowerCase().contains('clothe')) {
      return _deviceStatus ? "Extended" : "Retracted";
    }
    return _deviceStatus ? "On" : "Off";
  }

  Color _getStatusColor() {
    return _deviceStatus ? Colors.green : Colors.red;
  }

  String _getButtonText() {
    if (widget.deviceType.toLowerCase().contains('hanger') || 
        widget.deviceType.toLowerCase().contains('clothe')) {
      return _deviceStatus ? "RETRACT" : "EXTEND";
    }
    return _deviceStatus ? "TURN OFF" : "TURN ON";
  }

  Color _getButtonColor() {
    return _deviceStatus ? Colors.red : Colors.green;
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
                "Status: ${_getStatusText()}",
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Control button
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: _toggleDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _getButtonText(),
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