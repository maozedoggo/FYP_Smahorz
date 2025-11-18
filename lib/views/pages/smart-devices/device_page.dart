import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
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
  // ===========================================================================
  // STATE VARIABLES
  // ===========================================================================
  dynamic _deviceStatus = false;
  String? householdUid;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  StreamSubscription<DatabaseEvent>? _deviceSubscription;
  StreamSubscription<DatabaseEvent>? _parcelInsideSubscription;
  StreamSubscription<DatabaseEvent>? _parcelOutsideSubscription;
  bool _isControlling = false; // Add this to prevent multiple rapid toggles

  // ===========================================================================
  // LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _loadHouseholdUid();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _parcelInsideSubscription?.cancel();
    _parcelOutsideSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // REALTIME DATABASE METHODS - FIXED
  // ===========================================================================
  void _setupRealtimeListener(String householdId) {
    final deviceType = widget.deviceType.toLowerCase();

    // Cancel any existing subscriptions
    _deviceSubscription?.cancel();
    _parcelInsideSubscription?.cancel();
    _parcelOutsideSubscription?.cancel();

    if (deviceType.contains('parcel')) {
      // Parcel box - listen to individual status paths
      final insidePath = '$householdId/${widget.deviceId}/insideStatus';
      final outsidePath = '$householdId/${widget.deviceId}/outsideStatus';

      print("DeviceControlPage listening to parcel paths:");
      print(" - $insidePath");
      print(" - $outsidePath");

      _parcelInsideSubscription = _realtimeDB.child(insidePath).onValue.listen((
        DatabaseEvent event,
      ) {
        if (event.snapshot.exists && mounted && !_isControlling) {
          final insideStatus = event.snapshot.value == true;
          _updateParcelStatus(insideStatus, true);
        }
      });

      _parcelOutsideSubscription = _realtimeDB
          .child(outsidePath)
          .onValue
          .listen((DatabaseEvent event) {
            if (event.snapshot.exists && mounted && !_isControlling) {
              final outsideStatus = event.snapshot.value == true;
              _updateParcelStatus(outsideStatus, false);
            }
          });
    } else {
      // All other devices - simple status
      final path = '$householdId/${widget.deviceId}/status';
      print("DeviceControlPage listening to: $path");

      _deviceSubscription = _realtimeDB
          .child(path)
          .onValue
          .listen(
            (DatabaseEvent event) {
              if (event.snapshot.exists && mounted && !_isControlling) {
                final data = event.snapshot.value;
                final bool isOn = data == true;

                setState(() {
                  _deviceStatus = isOn;
                });

                print("DeviceControlPage update: ${widget.deviceId} = $isOn");
              }
            },
            onError: (error) {
              print("DeviceControlPage listener error: $error");
            },
          );
    }
  }

  void _updateParcelStatus(bool status, bool isInside) {
    setState(() {
      if (_deviceStatus is! Map) {
        _deviceStatus = {'insideStatus': false, 'outsideStatus': false};
      }

      if (isInside) {
        _deviceStatus['insideStatus'] = status;
      } else {
        _deviceStatus['outsideStatus'] = status;
      }
    });

    print(
      "DeviceControlPage parcel update: inside=${_deviceStatus['insideStatus']}, outside=${_deviceStatus['outsideStatus']}",
    );
  }

  // ===========================================================================
  // DEVICE CONTROL METHODS - FIXED
  // ===========================================================================
  void _toggleDevice() async {
    if (householdUid == null || _isControlling) {
      return;
    }

    try {
      _isControlling = true; // Prevent multiple rapid toggles

      final deviceType = widget.deviceType.toLowerCase();
      final newStatus = _getNewStatus();

      print("=== DEVICE CONTROL PAGE - TOGGLING DEVICE ===");
      print("Device ID: ${widget.deviceId}");
      print("Device Type: ${widget.deviceType}");
      print("Household ID: $householdUid");
      print("New Status: $newStatus");

      // Update local state first (but don't setState yet to avoid UI flicker)
      final previousStatus = _deviceStatus;

      if (deviceType.contains('parcel')) {
        await _updateParcelBoxStatus(newStatus);
      } else {
        await _updateSimpleDeviceStatus(newStatus);
      }

      // Only update UI after successful operation
      setState(() {
        _deviceStatus = newStatus;
      });

      print("✓ DeviceControlPage successfully updated device");
    } catch (error) {
      print("✗ Error controlling device: $error");
      // Don't revert UI - keep previous state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error controlling device: $error")),
      );
    } finally {
      _isControlling = false; // Re-enable controls
    }
  }

  dynamic _getNewStatus() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('parcel')) {
      // For parcel box, toggle both doors together in control page
      final currentInside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final currentOutside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;

      // Toggle both doors to the same state
      final newState = !(currentInside || currentOutside);
      return {'insideStatus': newState, 'outsideStatus': newState};
    } else {
      // Simple toggle for other devices
      return !(_deviceStatus == true);
    }
  }

  // ---------- Activity logging helper ----------
  Future<void> _logActivity({
    required String householdId,
    required String userEmail,
    required String deviceId,
    required String deviceName,
    required String action,
  }) async {
    try {
      // Ensure member document exists with username and role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();
      final username = userDoc.data()?['username'] ?? userEmail;
      final role = userDoc.data()?['role'] ?? 'member';
      final memberRef = FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(userEmail);
      await memberRef.set({
        'username': username,
        'role': role,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(userEmail)
          .collection('activityLog')
          .add({
            'userEmail': userEmail,
            'deviceId': deviceId,
            'deviceName': deviceName,
            'action': action,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("DeviceControlPage: Error logging activity: $e");
    }
  }

  Future<void> _updateSimpleDeviceStatus(bool newStatus) async {
    // Update Firestore
    await _firestore.collection('devices').doc(widget.deviceId).update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print("✓ Updated Firestore: status = $newStatus");

    // Update Realtime Database
    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/status')
        .set(newStatus);
    print(
      "✓ Updated Realtime DB: $householdUid/${widget.deviceId}/status = $newStatus",
    );

    // Log activity
    final user = FirebaseAuth.instance.currentUser;
    final deviceName = widget.deviceName;
    if (user != null && householdUid != null) {
      final action =
          (widget.deviceType.toLowerCase().contains('hanger') ||
              widget.deviceType.toLowerCase().contains('clothe'))
          ? (newStatus ? 'Extended clothes hanger' : 'Retracted clothes hanger')
          : (newStatus ? 'Turned ON $deviceName' : 'Turned OFF $deviceName');

      await _logActivity(
        householdId: householdUid!,
        userEmail: user.email ?? user.uid,
        deviceId: widget.deviceId,
        deviceName: deviceName,
        action: action,
      );
    }
  }

  Future<void> _updateParcelBoxStatus(Map<String, bool> newStatus) async {
    final insideStatus = newStatus['insideStatus'] ?? false;
    final outsideStatus = newStatus['outsideStatus'] ?? false;

    // Update Firestore
    await _firestore.collection('devices').doc(widget.deviceId).update({
      'status': {'insideStatus': insideStatus, 'outsideStatus': outsideStatus},
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print("✓ Updated Firestore parcel box status");

    // Update Realtime Database - set both values
    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/insideStatus')
        .set(insideStatus);
    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/outsideStatus')
        .set(outsideStatus);
    print(
      "✓ Updated Realtime DB parcel box: inside=$insideStatus, outside=$outsideStatus",
    );

    // Log activity
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && householdUid != null) {
      final action = (insideStatus || outsideStatus)
          ? 'Opened parcel box (inside:${insideStatus ? 'Open' : 'Closed'} / outside:${outsideStatus ? 'Open' : 'Closed'})'
          : 'Closed parcel box';

      await _logActivity(
        householdId: householdUid!,
        userEmail: user.email ?? user.uid,
        deviceId: widget.deviceId,
        deviceName: widget.deviceName,
        action: action,
      );
    }
  }

  // ===========================================================================
  // HOUSEHOLD METHODS
  // ===========================================================================
  Future<void> _loadHouseholdUid() async {
    try {
      final userEmail = FirebaseAuth.instance.currentUser!.email!;
      final userDoc = await _firestore.collection('users').doc(userEmail).get();

      if (userDoc.exists && userDoc.data()!.containsKey('householdId')) {
        final householdId = userDoc['householdId'];
        setState(() {
          householdUid = householdId;
        });
        _setupRealtimeListener(householdId);
        print("DeviceControlPage loaded household: $householdId");

        // Also load initial device status
        _loadInitialDeviceStatus();
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

  Future<void> _loadInitialDeviceStatus() async {
    try {
      final deviceDoc = await _firestore
          .collection('devices')
          .doc(widget.deviceId)
          .get();

      if (deviceDoc.exists && mounted) {
        final data = deviceDoc.data()!;
        final status = data['status'];
        final deviceType = widget.deviceType.toLowerCase();

        setState(() {
          if (deviceType.contains('parcel')) {
            _deviceStatus = status is Map
                ? Map<String, bool>.from(status)
                : {'insideStatus': false, 'outsideStatus': false};
          } else {
            _deviceStatus = status == true;
          }
        });

        print("Loaded initial device status: $_deviceStatus");
      }
    } catch (e) {
      print("Error loading initial device status: $e");
    }
  }

  // ===========================================================================
  // UI HELPER METHODS
  // ===========================================================================
  String _getStatusText() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('hanger') || deviceType.contains('clothe')) {
      return _deviceStatus == true ? "Extended" : "Retracted";
    } else if (deviceType.contains('parcel')) {
      final inside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final outside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;
      return 'In: ${inside ? "Open" : "Closed"}, Out: ${outside ? "Open" : "Closed"}';
    }
    return _deviceStatus == true ? "On" : "Off";
  }

  Color _getStatusColor() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('parcel')) {
      final inside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final outside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;
      return (inside || outside) ? Colors.green : Colors.red;
    }
    return _deviceStatus == true ? Colors.green : Colors.red;
  }

  String _getButtonText() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('hanger') || deviceType.contains('clothe')) {
      return _deviceStatus == true ? "RETRACT" : "EXTEND";
    } else if (deviceType.contains('parcel')) {
      final inside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final outside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;
      return (inside || outside) ? "CLOSE ALL" : "OPEN ALL";
    }
    return _deviceStatus == true ? "TURN OFF" : "TURN ON";
  }

  Color _getButtonColor() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('parcel')) {
      final inside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final outside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;
      return (inside || outside) ? Colors.red : Colors.green;
    }
    return _deviceStatus == true ? Colors.red : Colors.green;
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
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
                  fontWeight: FontWeight.bold,
                ),
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
                  onPressed: _isControlling ? null : _toggleDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getButtonColor(),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isControlling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _getButtonText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),

              // Navigate to Schedule Page
              ElevatedButton.icon(
                onPressed: householdUid == null || _isControlling
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
                  backgroundColor: householdUid == null
                      ? Colors.grey
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.calendar_month, color: Colors.black),
                label: const Text(
                  "Add Schedule",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
