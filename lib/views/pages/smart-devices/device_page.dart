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
  bool _isUpdating = false;
  dynamic _deviceStatus = false;
  dynamic _displayedStatus = false;
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
  StreamSubscription<DatabaseEvent>? _connectionStatusSubscription;

  bool _deviceConnected = false;
  bool _isInitialLoad = true;

  // ===========================================================================
  // LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _loadHouseholdUid();

    // Reduced initial load time to 1 second for better UX
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _parcelInsideSubscription?.cancel();
    _parcelOutsideSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // REALTIME DATABASE METHODS
  // ===========================================================================
  void _setupRealtimeListener(String householdId) {
    final deviceType = widget.deviceType.toLowerCase();

    _deviceSubscription?.cancel();
    _parcelInsideSubscription?.cancel();
    _parcelOutsideSubscription?.cancel();
    _connectionStatusSubscription?.cancel();

    // ===========================================================================
    // CONNECTION STATUS LISTENER
    // ===========================================================================
    final connectionPath = '$householdId/${widget.deviceId}/connectionStatus';
    print("DeviceControlPage listening to connection status: $connectionPath");

    _connectionStatusSubscription = _realtimeDB
        .child(connectionPath)
        .onValue
        .listen(
          (DatabaseEvent event) {
            if (event.snapshot.exists && mounted) {
              final connectionStatus = event.snapshot.value == true;
              setState(() {
                _deviceConnected = connectionStatus;
              });
              print(
                "DeviceControlPage connection update: ${widget.deviceId} = $connectionStatus",
              );
            } else {
              setState(() {
                _deviceConnected = false;
              });
              print(
                "DeviceControlPage connection update: ${widget.deviceId} = OFFLINE (no data)",
              );
            }
          },
          onError: (error) {
            print("DeviceControlPage connection listener error: $error");
            setState(() {
              _deviceConnected = false;
            });
          },
        );

    if (deviceType.contains('parcel')) {
      final insidePath = '$householdId/${widget.deviceId}/insideStatus';
      final outsidePath = '$householdId/${widget.deviceId}/outsideStatus';

      print("DeviceControlPage listening to parcel paths:");
      print(" - $insidePath");
      print(" - $outsidePath");

      _parcelInsideSubscription = _realtimeDB.child(insidePath).onValue.listen((
        DatabaseEvent event,
      ) {
        if (event.snapshot.exists && mounted) {
          final insideStatus = event.snapshot.value == true;
          _updateParcelStatus(insideStatus, true);
        }
      });

      _parcelOutsideSubscription = _realtimeDB
          .child(outsidePath)
          .onValue
          .listen((DatabaseEvent event) {
            if (event.snapshot.exists && mounted) {
              final outsideStatus = event.snapshot.value == true;
              _updateParcelStatus(outsideStatus, false);
            }
          });
    } else {
      final path = '$householdId/${widget.deviceId}/status';
      print("DeviceControlPage listening to: $path");

      _deviceSubscription = _realtimeDB
          .child(path)
          .onValue
          .listen(
            (DatabaseEvent event) {
              if (event.snapshot.exists && mounted) {
                final data = event.snapshot.value;
                final bool isOn = data == true;

                // Only update if not currently performing a user action
                if (!_isUpdating) {
                  setState(() {
                    _deviceStatus = isOn;
                    _displayedStatus = isOn;
                  });
                }

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
    // Only update if not currently performing a user action
    if (_isUpdating) return;

    setState(() {
      if (_deviceStatus is! Map) {
        _deviceStatus = {'insideStatus': false, 'outsideStatus': false};
        _displayedStatus = {'insideStatus': false, 'outsideStatus': false};
      }

      if (isInside) {
        _deviceStatus['insideStatus'] = status;
        _displayedStatus['insideStatus'] = status;
      } else {
        _deviceStatus['outsideStatus'] = status;
        _displayedStatus['outsideStatus'] = status;
      }
    });

    print(
      "DeviceControlPage parcel update: inside=${_deviceStatus['insideStatus']}, outside=${_deviceStatus['outsideStatus']}",
    );
  }

  // ===========================================================================
  // DEVICE CONTROL METHODS
  // ===========================================================================
  Future<void> _toggleDevice() async {
    if (_isUpdating || householdUid == null || !_deviceConnected) {
      return;
    }

    final previousStatus = _deviceStatus;
    final previousDisplayStatus = _displayedStatus;

    try {
      setState(() {
        _isUpdating = true;

        // IMMEDIATELY update displayed status for instant UI feedback
        final deviceType = widget.deviceType.toLowerCase();
        if (deviceType.contains('parcel')) {
          final currentInside = _displayedStatus is Map
              ? _displayedStatus['insideStatus'] ?? false
              : false;
          final currentOutside = _displayedStatus is Map
              ? _displayedStatus['outsideStatus'] ?? false
              : false;
          final newState = !(currentInside || currentOutside);
          _displayedStatus = {
            'insideStatus': newState,
            'outsideStatus': newState,
          };
        } else {
          _displayedStatus = !(_displayedStatus == true);
        }
      });

      final deviceType = widget.deviceType.toLowerCase();
      final newStatus = _getNewStatus();

      print("=== USER TOGGLING DEVICE ===");
      print("Device: ${widget.deviceName} (${widget.deviceId})");
      print("From: $previousStatus");
      print("To: $newStatus");

      if (deviceType.contains('parcel')) {
        await _updateParcelBoxStatus(newStatus);
      } else {
        await _updateSimpleDeviceStatus(newStatus);
      }

      setState(() {
        _deviceStatus = newStatus;
      });

      print("✓ DeviceControlPage successfully updated device");
    } catch (error) {
      print("✗ Error controlling device: $error");

      setState(() {
        _deviceStatus = previousStatus;
        _displayedStatus = previousDisplayStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${error.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // FIXED: Remove delay - allow immediate subsequent clicks
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  dynamic _getNewStatus() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('parcel')) {
      final currentInside = _deviceStatus is Map
          ? _deviceStatus['insideStatus'] ?? false
          : false;
      final currentOutside = _deviceStatus is Map
          ? _deviceStatus['outsideStatus'] ?? false
          : false;

      final newState = !(currentInside || currentOutside);
      return {'insideStatus': newState, 'outsideStatus': newState};
    } else {
      return !(_deviceStatus == true);
    }
  }

  Future<void> _logActivity({
    required String householdId,
    required String userEmail,
    required String deviceId,
    required String deviceName,
    required String action,
  }) async {
    try {
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
    await _firestore.collection('devices').doc(widget.deviceId).update({
      'status': newStatus,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print("✓ Updated Firestore: status = $newStatus");

    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/status')
        .set(newStatus);
    print(
      "✓ Updated Realtime DB: $householdUid/${widget.deviceId}/status = $newStatus",
    );

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

    await _firestore.collection('devices').doc(widget.deviceId).update({
      'status': {'insideStatus': insideStatus, 'outsideStatus': outsideStatus},
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print("✓ Updated Firestore parcel box status");

    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/insideStatus')
        .set(insideStatus);
    await _realtimeDB
        .child('$householdUid/${widget.deviceId}/outsideStatus')
        .set(outsideStatus);
    print(
      "✓ Updated Realtime DB parcel box: inside=$insideStatus, outside=$outsideStatus",
    );

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

        _loadInitialDeviceStatus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Household ID not found.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching household ID: $e")),
        );
      }
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
            _displayedStatus = _deviceStatus;
          } else {
            _deviceStatus = status == true;
            _displayedStatus = _deviceStatus;
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
      return _displayedStatus == true ? "Extended" : "Retracted";
    } else if (deviceType.contains('parcel')) {
      final inside = _displayedStatus is Map
          ? _displayedStatus['insideStatus'] ?? false
          : false;
      final outside = _displayedStatus is Map
          ? _displayedStatus['outsideStatus'] ?? false
          : false;
      return 'In: ${inside ? "Open" : "Closed"}, Out: ${outside ? "Open" : "Closed"}';
    }
    return _displayedStatus == true ? "On" : "Off";
  }

  String _getButtonText() {
    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('hanger') || deviceType.contains('clothe')) {
      return _displayedStatus == true ? "RETRACT" : "EXTEND";
    } else if (deviceType.contains('parcel')) {
      final inside = _displayedStatus is Map
          ? _displayedStatus['insideStatus'] ?? false
          : false;
      final outside = _displayedStatus is Map
          ? _displayedStatus['outsideStatus'] ?? false
          : false;
      return (inside || outside) ? "CLOSE ALL" : "OPEN ALL";
    }
    return _displayedStatus == true ? "TURN OFF" : "TURN ON";
  }

  Color _getButtonColor() {
    if (_isUpdating) return Colors.grey;

    final deviceType = widget.deviceType.toLowerCase();

    if (deviceType.contains('parcel')) {
      final inside = _displayedStatus is Map
          ? _displayedStatus['insideStatus'] ?? false
          : false;
      final outside = _displayedStatus is Map
          ? _displayedStatus['outsideStatus'] ?? false
          : false;
      return (inside || outside) ? Colors.redAccent : Colors.green;
    }
    return _displayedStatus == true ? Colors.redAccent : Colors.green;
  }

  String _getDeviceIcon() {
    final deviceType = widget.deviceType.toLowerCase();
    String deviceIcon;

    if (deviceType.contains("hanger") || deviceType.contains("clothes")) {
      deviceIcon = "lib/icons/drying-rack.png";
      return deviceIcon;
    } else {
      deviceIcon = "lib/icons/parcel-box.png";
    }

    return deviceIcon;
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
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

            const SizedBox(height: 20),

            Align(
              child: Text(
                widget.deviceName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "Type: ${widget.deviceType}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: Card(
                color: const Color(0xFF1C2233),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Image.asset(
                        _getDeviceIcon(),
                        width: 80,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Current Status",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _deviceConnected ? Icons.wifi : Icons.wifi_off,
                            color: _deviceConnected
                                ? Colors.green
                                : Colors.redAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _deviceConnected
                                ? "Device Online"
                                : "Device Offline",
                            style: TextStyle(
                              color: _deviceConnected
                                  ? Colors.green
                                  : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // FIXED: Removed _isInitialLoad from condition
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed:
                    (_isUpdating || householdUid == null || !_deviceConnected)
                    ? null
                    : _toggleDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getButtonColor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  shadowColor: _getButtonColor().withOpacity(0.5),
                ),
                child: _isUpdating
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              color: const Color(0xFF1C2233),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_month,
                  color: Colors.blueAccent,
                ),
                title: const Text(
                  "Schedules",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  "Manage automated schedules",
                  style: TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.blueAccent,
                  size: 16,
                ),
                onTap: (householdUid == null)
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
