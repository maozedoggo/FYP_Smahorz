import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:smart_horizon_home/ui/view_devices.dart';
import 'package:smart_horizon_home/services/weather_services.dart';
import 'package:smart_horizon_home/views/pages/notification-page/notification_page.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/device_page.dart';
import 'package:smart_horizon_home/views/pages/profile-page/profile_page.dart';
import 'package:smart_horizon_home/views/pages/settings-page/settings_page.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/qr_scanner.dart';
import 'package:smart_horizon_home/utils/route_observer.dart';

// =============================================================================
// HOME PAGE WIDGET
// =============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// =============================================================================
// HOME PAGE STATE
// =============================================================================
class _HomePageState extends State<HomePage> with RouteAware {
  // ===========================================================================
  // DEPENDENCIES & SERVICES
  // ===========================================================================
  final WeatherService weatherAPI = WeatherService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  // ===========================================================================
  // WEATHER STATE VARIABLES
  // ===========================================================================
  bool _isLoadingWeather = true;
  String _cityName = "City";
  int _temp = 0;
  String _stateName = "State";
  String _weatherLabel = "Weather";

  // ===========================================================================
  // DEVICE STATE VARIABLES
  // ===========================================================================
  List<Map<String, dynamic>> _devices = [];
  final ValueNotifier<Map<String, bool>> _deviceStatus = ValueNotifier({});
  bool _isAddingDevice = false; // Loading state for adding device

  // Store subscriptions so we can cancel them on dispose
  Map<String, StreamSubscription<DocumentSnapshot>> _deviceSubscriptions = {};

  // ===========================================================================
  // LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadUserDevices();
    _testRealtimeDBConnection();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal != null) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    // Cancel all device subscriptions
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();

    // unsubscribe from route events
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadUserDevices();
    _loadWeather();
    super.didPopNext();
  }

  // ===========================================================================
  // FIRESTORE METHODS
  // ===========================================================================
  void _setupFirestoreListeners() {
    print("Setting up Firestore listeners for ${_devices.length} devices");

    // Cancel old subscriptions first
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();

    // Listen to each device's status in Firestore
    for (final device in _devices) {
      final deviceId = device['id'];
      print("Listening to Firestore document: devices/$deviceId");

      final subscription = _firestore
          .collection('devices')
          .doc(deviceId)
          .snapshots()
          .listen(
            (documentSnapshot) {
              if (documentSnapshot.exists && mounted) {
                final data = documentSnapshot.data();
                if (data != null && data.containsKey('status')) {
                  final bool isOn = data['status'] == true;

                  print("Firestore update - $deviceId: $isOn");

                  // Update the device status in the ValueNotifier
                  _deviceStatus.value = {
                    ..._deviceStatus.value,
                    deviceId: isOn,
                  };
                }
              }
            },
            onError: (error) {
              print("Firestore listener error for $deviceId: $error");
            },
          );

      // Store subscription for later cleanup
      _deviceSubscriptions[deviceId] = subscription;
    }
  }

  // ===========================================================================
  // REALTIME DATABASE METHODS
  // ===========================================================================
  void _setupRealtimeDBListeners() async {
    print("Setting up Realtime DB listeners for ${_devices.length} devices");

    // Get household ID first
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.email).get();

    final householdId = userDoc.data()?['householdId'];
    if (householdId == null) {
      print("No household ID found for Realtime DB listeners");
      return;
    }

    print("Realtime DB listeners using household: $householdId");

    // Listen to each device's status in Realtime Database
    for (final device in _devices) {
      final deviceId = device['id'];
      final path = '$householdId/$deviceId/status';
      print("Listening to Realtime DB: $path");

      _realtimeDB
          .child(path)
          .onValue
          .listen(
            (DatabaseEvent event) {
              if (event.snapshot.exists && mounted) {
                final status = event.snapshot.value;
                final bool isOn = status == true;

                print("Realtime DB update - $deviceId: $isOn");

                // Update the device status in the ValueNotifier
                _deviceStatus.value = {..._deviceStatus.value, deviceId: isOn};
              }
            },
            onError: (error) {
              print("Realtime DB listener error for $deviceId: $error");
            },
          );
    }
  }

  void _testRealtimeDBConnection() async {
    try {
      final testPath = 'test_connection';
      print("Testing Realtime DB connection...");

      await _realtimeDB
          .child(testPath)
          .set({
            'test': 'Hello from Flutter',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          })
          .then((_) {
            print("✓ Realtime DB test write SUCCESS");

            // Try to read it back
            _realtimeDB.child(testPath).get().then((snapshot) {
              if (snapshot.exists) {
                print("✓ Realtime DB test read SUCCESS: ${snapshot.value}");
              } else {
                print("✗ Realtime DB test read FAILED");
              }
            });
          })
          .catchError((error) {
            print("✗ Realtime DB test write FAILED: $error");
          });
    } catch (e) {
      print("✗ Realtime DB test exception: $e");
    }
  }

  Future<bool> _testRealtimeDBWrite(String householdId, String deviceId) async {
    try {
      final testPath = '$householdId/test_$deviceId';
      final testData = {
        'test': 'write_test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      print("🧪 Testing Realtime DB write to: $testPath");

      await _realtimeDB
          .child(testPath)
          .set(testData)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print("❌ Realtime DB write test TIMEOUT");
              return false;
            },
          );

      // Verify the write
      final snapshot = await _realtimeDB
          .child(testPath)
          .once()
          .timeout(const Duration(seconds: 3));

      if (snapshot.snapshot.exists) {
        print("✅ Realtime DB write test SUCCESS");
        // Clean up test data
        await _realtimeDB.child(testPath).remove();
        return true;
      } else {
        print("❌ Realtime DB write test FAILED - data not found");
        return false;
      }
    } catch (e) {
      print("❌ Realtime DB write test ERROR: $e");
      return false;
    }
  }

  // ===========================================================================
  // DEVICE MANAGEMENT METHODS
  // ===========================================================================
  Future<void> _loadUserDevices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() ?? {};
      final householdId = userData['householdId'];
      if (householdId == null || householdId.toString().isEmpty) return;

      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();
      if (!householdDoc.exists) return;

      final deviceIds = List<String>.from(
        householdDoc.data()?['devices'] ?? [],
      );
      final loaded = <Map<String, dynamic>>[];
      final statusMap = <String, bool>{};

      for (final id in deviceIds) {
        final d = await _firestore.collection('devices').doc(id).get();
        if (!d.exists) continue;
        final dd = d.data() ?? {};
        loaded.add({
          'id': id,
          'name': dd['name'] ?? id,
          'type': dd['type'] ?? 'Unknown',
        });
        statusMap[id] = dd['status'] ?? false;
      }

      if (!mounted) return;
      setState(() => _devices = loaded);
      _deviceStatus.value = statusMap;

      // Setup both Firestore and Realtime DB listeners
      _setupFirestoreListeners();
      _setupRealtimeDBListeners();
    } catch (e) {
      debugPrint("Error loading household devices: $e");
    }
  }

  Future<void> _addDeviceById(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to add a device.'),
          ),
        );
        return;
      }

      // --- 1️ Get device from Firestore ---
      final deviceRef = _firestore.collection('devices').doc(id);
      final deviceDoc = await deviceRef.get();

      if (!deviceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device not found in the system.')),
        );
        return;
      }

      final deviceData = deviceDoc.data() ?? {};
      final existingHouseholdId = deviceData['householdId'];

      // --- 2️ Check if device already assigned to another household ---
      if (existingHouseholdId != null &&
          existingHouseholdId.toString().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This device is already assigned to another household.',
            ),
          ),
        );
        return;
      }

      // --- 3️ Get user's household ID ---
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User profile not found.')),
        );
        return;
      }

      final userData = userDoc.data() ?? {};
      final householdId = userData['householdId'];

      if (householdId == null || householdId.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are not assigned to any household. Please contact administrator.',
            ),
          ),
        );
        return;
      }

      // --- 4️ Verify household exists ---
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();
      if (!householdDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your household does not exist.')),
        );
        return;
      }

      print("=== ADDING DEVICE TO HOUSEHOLD ===");
      print("Device ID: $id");
      print("Household ID: $householdId");
      print("User: ${user.email}");

      // Show full page loading
      if (mounted) {
        setState(() {
          _isAddingDevice = true;
        });
      }

      // --- 5️ Add device to household's device array in Firestore ---
      await _firestore.collection('households').doc(householdId).set({
        'devices': FieldValue.arrayUnion([id]),
      }, SetOptions(merge: true));

      print("✓ Added device to household Firestore array");

      // --- 6️ Update device document to mark it as assigned in Firestore ---
      await deviceRef.update({
        'householdId': householdId,
        'status': false, // Initialize status to false
        'addedAt': FieldValue.serverTimestamp(),
      });

      print("✓ Updated device Firestore document");

      // --- 7️ CREATE REALTIME DATABASE ENTRY (SIMPLIFIED VERSION) ---
      final deviceType = deviceData['type'] ?? 'Unknown';
      final deviceName = deviceData['name'] ?? id;

      final realtimePath = '$householdId/$id';
      print("=== REALTIME DATABASE CREATION ===");
      print("Path: $realtimePath");

      // Test Realtime DB connection first
      final canWriteToRTDB = await _testRealtimeDBWrite(householdId, id);

      if (canWriteToRTDB) {
        try {
          print("🔄 Writing device data to Realtime Database...");

          // Write only the essential data first
          await _realtimeDB
              .child('$realtimePath/status')
              .set(false)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  throw TimeoutException("Realtime DB status write timeout");
                },
              );

          print("✅ Basic device status written to Realtime DB");

          // Add additional device info with separate writes
          await _realtimeDB.child('$realtimePath/type').set(deviceType);
          await _realtimeDB.child('$realtimePath/name').set(deviceName);
          await _realtimeDB
              .child('$realtimePath/addedAt')
              .set(DateTime.now().millisecondsSinceEpoch);

          print("✅ All device data written to Realtime DB");
        } catch (e) {
          print("❌ Error writing to Realtime DB: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Device added but Realtime Database setup had issues.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        print("⚠️ Skipping Realtime DB setup due to connection issues");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Device added but could not connect to Realtime Database.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // --- 8️ Refresh UI ---
      print("Refreshing UI...");
      await _loadUserDevices();
      print("✓ UI refreshed");

      // Hide loading indicator
      if (mounted) {
        setState(() {
          _isAddingDevice = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device added to household successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      print("=== DEVICE ADDITION COMPLETED ===");
    } catch (e) {
      print("❌ ERROR IN _addDeviceById: $e");
      debugPrint('Error adding device: $e');

      // Hide loading indicator on error
      if (mounted) {
        setState(() {
          _isAddingDevice = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding device: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add device dialog pane
  Future<void> _showAddDeviceDialog() async {
    final inHousehold = await _isUserInHousehold();
    if (!inHousehold) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be part of a household before adding a device.',
          ),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your Device ID:'),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Device ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, "scan"),
              child: const Text('Scan QR'),
            ),
            ElevatedButton(
              onPressed: () {
                final id = controller.text.trim();
                if (id.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a Device ID')),
                  );
                  return;
                }
                Navigator.pop(context, id);
              },
              child: const Text('Add Device'),
            ),
          ],
        );
      },
    );

    if (res == "scan") {
      final scannedId = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QRScannerPage()),
      );

      if (scannedId != null && scannedId.toString().isNotEmpty) {
        await _addDeviceById(scannedId.toString());
      }
    } else if (res != null && res.isNotEmpty) {
      await _addDeviceById(res);
    }
  }

  // Check if user is in household
  Future<bool> _isUserInHousehold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
      if (!userDoc.exists) return false;
      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) return false;
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .get();
      return householdDoc.exists;
    } catch (e) {
      debugPrint('Error checking household: $e');
      return false;
    }
  }

  // ===========================================================================
  // WEATHER METHODS
  // ===========================================================================
  Future<void> _loadWeather() async {
    try {
      await weatherAPI.fetchData();
      await weatherAPI.callApi();
      if (!mounted) return;
      setState(() {
        _stateName = weatherAPI.stateName ?? "Unknown";
        _cityName = weatherAPI.cityName ?? "Unknown";
        _temp = weatherAPI.currentTemp;
        _weatherLabel =
            weatherAPI.weatherMain ??
            weatherAPI.weatherDescription ??
            "Weather";
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() => _isLoadingWeather = false);
      debugPrint("Error loading weather: $e");
    }
  }

  Widget _weatherIconForId(int id, {double size = 24.0}) {
    String svgPath;
    if (id >= 200 && id < 300) {
      svgPath = 'lib/icons/weather/thunderstorm.svg';
    } else if (id >= 300 && id < 500) {
      svgPath = 'lib/icons/weather/rainy.svg';
    } else if (id >= 500 && id < 600) {
      svgPath = 'lib/icons/weather/rainy.svg';
    } else if (id >= 600 && id < 700) {
      svgPath = 'lib/icons/weather/snowy.svg';
    } else if (id >= 700 && id < 800) {
      svgPath = 'lib/icons/weather/foggy.svg';
    } else if (id == 800) {
      svgPath = 'lib/icons/weather/sunny.svg';
    } else if (id > 800 && id < 900) {
      svgPath = 'lib/icons/weather/cloudy.svg';
    } else {
      svgPath = 'lib/icons/weather/cloudy.svg';
    }

    return SvgPicture.asset(
      svgPath,
      width: size,
      height: size,
      color: Colors.white,
    );
  }

  // ===========================================================================
  // AUTHENTICATION METHODS
  // ===========================================================================
  Future<void> _signout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ===========================================================================
  // DEVICE CONTROL METHODS
  // ===========================================================================
  void powerSwitchChanged(bool value, String deviceId) async {
    print("=== SWITCH TOGGLED ===");
    print("Device ID: $deviceId");
    print("New Status: $value");

    try {
      // Get current user's household ID
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();

      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) {
        print("✗ No household ID found for user");
        return;
      }

      print("Household ID: $householdId");

      // Update local state for immediate UI response
      _deviceStatus.value = {..._deviceStatus.value, deviceId: value};

      // Update Firestore for data persistence
      await _firestore.collection('devices').doc(deviceId).update({
        'status': value,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      print("✓ Updated Firestore: devices/$deviceId = $value");

      // Update Realtime Database under household path
      await _realtimeDB.child('$householdId/$deviceId/status').set(value);
      print("✓ Updated Realtime DB: $householdId/$deviceId/status = $value");

      // Verify the write
      final snapshot = await _realtimeDB
          .child('$householdId/$deviceId/status')
          .get();
      if (snapshot.exists) {
        print(
          "✓ Verification - Current value in Realtime DB: ${snapshot.value}",
        );
      } else {
        print("✗ Verification failed - No data at path");
      }
    } catch (e) {
      print("✗ Error controlling device: $e");
      // Revert local state on error
      _deviceStatus.value = {..._deviceStatus.value, deviceId: !value};
    }
  }

  Widget _pageForDevice(Map<String, dynamic> device) {
    return DeviceControlPage(
      deviceId: device['id'] ?? '',
      deviceName: device['name'] ?? 'Unknown Device',
      deviceType: device['type'] ?? 'Unknown Type',
    );
  }

  String _getStatusText(String deviceId, String deviceType) {
    return _deviceStatus.value[deviceId] == true ? 'On' : 'Off';
  }

  Color _getStatusColor(String deviceId, String deviceType) {
    return _deviceStatus.value[deviceId] == true ? Colors.green : Colors.red;
  }

  // ===========================================================================
  // ACTIVITY LOGGING
  // ===========================================================================
  Future<void> logActivity({required String action, String? deviceId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.email).get();

    final userData = userDoc.data() ?? {};
    final householdId = userData['householdId'];
    final username = userData['username'] ?? "Unknown User";

    if (householdId == null) return;

    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('activityLogs')
        .add({
          'userId': user.uid,
          'username': username,
          'deviceId': deviceId,
          'action': action,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final drawerController = AdvancedDrawerController();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final horizontalPadding = screenWidth * 0.05;
    final verticalPadding = screenHeight * 0.02;
    final iconSize = screenWidth * 0.08;
    final titleFontSize = screenWidth * 0.08;
    final subtitleFontSize = screenWidth * 0.05;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          AdvancedDrawer(
            controller: drawerController,
            openScale: 0.7,
            openRatio: 0.65,
            animationCurve: Curves.easeInOutSine,
            animateChildDecoration: true,
            childDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            backdropColor: const Color.fromARGB(255, 22, 22, 22),
            drawer: Container(
              color: const Color.fromARGB(255, 36, 36, 36),
              child: SafeArea(
                child: ListTileTheme(
                  textColor: Colors.white,
                  iconColor: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ListTile(
                              onTap: _isAddingDevice
                                  ? null
                                  : () => drawerController.hideDrawer(),
                              leading: const Icon(Icons.home),
                              title: const Text('Home'),
                            ),
                            ListTile(
                              onTap: _isAddingDevice
                                  ? null
                                  : () async {
                                      drawerController.hideDrawer();
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfilePage(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      await _loadUserDevices();
                                    },
                              leading: const Icon(Icons.account_circle_rounded),
                              title: const Text('Profile'),
                            ),
                            ListTile(
                              onTap: _isAddingDevice
                                  ? null
                                  : () async {
                                      drawerController.hideDrawer();
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SettingsPage(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      await _loadUserDevices();
                                    },
                              leading: const Icon(Icons.settings),
                              title: const Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isAddingDevice ? null : _signout,
                          icon: Icon(
                            Icons.logout_rounded,
                            color: Colors.red[700],
                            size: iconSize,
                          ),
                          label: Text(
                            "Logout",
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: subtitleFontSize,
                            ),
                          ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: screenWidth * 0.03,
                          color: Colors.white,
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 16.0),
                          child: const Text('Smart Horizon Home'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: Scaffold(
              body: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0063A1),
                      Color(0xFF0982BA),
                      Color(0xFF04111C),
                    ],
                    stops: [0.21, 0.41, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===========================================================
                      // TOP APP BAR
                      // ===========================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding - 10,
                          vertical: verticalPadding,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.menu,
                                size: iconSize,
                                color: Colors.white,
                              ),
                              onPressed: _isAddingDevice
                                  ? null
                                  : () => drawerController.toggleDrawer(),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.notifications,
                                size: iconSize,
                                color: Colors.white,
                              ),
                              onPressed: _isAddingDevice
                                  ? null
                                  : () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => NotificationPage(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      await _loadUserDevices();
                                    },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                size: iconSize,
                                color: Colors.white,
                              ),
                              onPressed: _isAddingDevice
                                  ? null
                                  : _showAddDeviceDialog,
                            ),
                          ],
                        ),
                      ),

                      // ===========================================================
                      // WELCOME SECTION
                      // ===========================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome Home",
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black54,
                                    offset: Offset(1, 2),
                                  ),
                                ],
                              ),
                            ),
                            if (userEmail != null)
                              StreamBuilder<DocumentSnapshot>(
                                stream: _firestore
                                    .collection("users")
                                    .doc(userEmail)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Text(
                                      "...",
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Colors.white70,
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists) {
                                    return Text(
                                      "No username",
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Colors.white70,
                                      ),
                                    );
                                  }
                                  final data =
                                      snapshot.data!.data()
                                          as Map<String, dynamic>?;
                                  return Text(
                                    data?['username'] ?? "",
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 2,
                                          color: Colors.black54,
                                          offset: Offset(0.5, 1),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            else
                              Text(
                                "Not logged in",
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        child: Divider(thickness: 3, color: Colors.white38),
                      ),

                      // ===========================================================
                      // WEATHER CARD
                      // ===========================================================
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.15),
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.05,
                            ),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.1),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(255, 255, 255, 0.15),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: screenHeight * 0.02,
                          ),
                          child: _isLoadingWeather
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _weatherIconForId(
                                      weatherAPI.statusID,
                                      size: screenWidth * 0.15,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: screenWidth * 0.25,
                                          ),
                                          child: Text(
                                            _weatherLabel,
                                            style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          "$_temp°C",
                                          style: TextStyle(
                                            fontSize: subtitleFontSize * 1.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 4,
                                                color: Colors.black45,
                                                offset: Offset(1, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: screenWidth * 0.3,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _cityName,
                                            style: TextStyle(
                                              fontSize: subtitleFontSize,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            _stateName,
                                            style: TextStyle(
                                              fontSize: subtitleFontSize * 1.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 4,
                                                  color: Colors.black54,
                                                  offset: Offset(1, 2),
                                                ),
                                              ],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // ===========================================================
                      // DEVICES GRID
                      // ===========================================================
                      Expanded(
                        child: ValueListenableBuilder<Map<String, bool>>(
                          valueListenable: _deviceStatus,
                          builder: (context, statusMap, _) {
                            if (_devices.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.device_hub,
                                      size: 56,
                                      color: Colors.white24,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "No devices added yet",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                ),
                              );
                            }

                            return GridView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                              ),
                              itemCount: _devices.length,
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: screenWidth * 0.5,
                                    childAspectRatio: 0.8,
                                    mainAxisSpacing: screenHeight * 0.02,
                                    crossAxisSpacing: screenWidth * 0.03,
                                  ),
                              itemBuilder: (context, index) {
                                final dev = _devices[index];
                                final type = (dev['type'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final iconPath =
                                    type.contains('clothe') ||
                                        type.contains('hanger')
                                    ? 'lib/icons/drying-rack.png'
                                    : 'lib/icons/door-open.png';

                                final statusText = _getStatusText(
                                  dev['id'],
                                  dev['type'],
                                );
                                final statusColor = _getStatusColor(
                                  dev['id'],
                                  dev['type'],
                                );

                                return GestureDetector(
                                  onTap: _isAddingDevice
                                      ? null
                                      : () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  _pageForDevice(dev),
                                            ),
                                          );
                                          if (!mounted) return;
                                          await _loadUserDevices();
                                        },
                                  child: AbsorbPointer(
                                    absorbing: _isAddingDevice,
                                    child: ViewDevices(
                                      deviceType: dev['type'] ?? '',
                                      devicePart: statusText,
                                      iconPath: iconPath,
                                      status: statusMap[dev['id']] ?? true,
                                      onChanged: _isAddingDevice
                                          ? null
                                          : (value) => powerSwitchChanged(
                                              value,
                                              dev['id'],
                                            ),
                                      statusColor: statusColor,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Full page loading overlay
          if (_isAddingDevice)
            Container(
              color: Colors.black54, // Semi-transparent black overlay
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
