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
  // ========================
  // DEPENDENCIES & SERVICES
  // ========================
  final WeatherService weatherAPI = WeatherService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Use the app instance to initialize the correct RTDB URL (keep your URL)
  final DatabaseReference _realtimeDB = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  // ========================
  // WEATHER STATE VARIABLES
  // ========================
  bool _isLoadingWeather = true;
  String _cityName = "City";
  int _temp = 0;
  String _stateName = "State";
  String _weatherLabel = "Weather";

  // ========================
  // DEVICE STATE VARIABLES
  // ========================
  List<Map<String, dynamic>> _devices = [];
  final ValueNotifier<Map<String, bool>> _deviceStatus = ValueNotifier({});
  bool _isAddingDevice = false; // Loading state for adding device

  // Store firestore subscriptions per device so we can cancel them
  final Map<String, StreamSubscription<DocumentSnapshot>> _deviceSubscriptions = {};

  // ========================
  // NOTIFICATIONS VARIABLES
  // ========================
  int _unreadNotificationCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  // ========================
  // LIFECYCLE METHODS
  // ========================
  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadUserDevices();
    _testRealtimeDBConnection();
    _listenToNotifications(); // Start listening for unread notifications
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
  void didPopNext() {
    // Called when returning to this route — refresh
    _loadUserDevices();
    _loadWeather();
    super.didPopNext();
  }

  @override
  void dispose() {
    // Cancel notification subscription
    _notificationSubscription?.cancel();

    // Cancel all device subscriptions
    for (final sub in _deviceSubscriptions.values) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    _deviceSubscriptions.clear();

    // Unsubscribe from route events
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}

    super.dispose();
  }

  // ========================
  // FIRESTORE LISTENERS
  // ========================
  void _setupFirestoreListeners() {
    // Cancel old subscriptions first
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();

    for (final device in _devices) {
      final deviceId = device['id'];
      if (deviceId == null) continue;

      final subscription = _firestore
          .collection('devices')
          .doc(deviceId)
          .snapshots()
          .listen((documentSnapshot) {
        if (!mounted) return;
        if (documentSnapshot.exists) {
          final data = documentSnapshot.data();
          if (data != null && data.containsKey('status')) {
            final bool isOn = data['status'] == true;
            _deviceStatus.value = {..._deviceStatus.value, deviceId: isOn};
          }
        }
      }, onError: (error) {
        debugPrint("Firestore listener error for $deviceId: $error");
      });

      _deviceSubscriptions[deviceId] = subscription;
    }
  }

  // ========================
  // REALTIME DB LISTENERS
  // ========================
  void _setupRealtimeDBListeners() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.email).get();
    final householdId = userDoc.data()?['householdId'];
    if (householdId == null) return;

    for (final device in _devices) {
      final deviceId = device['id'];
      if (deviceId == null) continue;
      final path = '$householdId/$deviceId/status';
      try {
        _realtimeDB.child(path).onValue.listen((DatabaseEvent event) {
          if (!mounted) return;
          if (event.snapshot.exists) {
            final status = event.snapshot.value;
            final bool isOn = status == true;
            _deviceStatus.value = {..._deviceStatus.value, deviceId: isOn};
          }
        }, onError: (error) {
          debugPrint("Realtime DB listener error for $deviceId: $error");
        });
      } catch (e) {
        debugPrint("Error attaching Realtime DB listener for $deviceId: $e");
      }
    }
  }

  Future<void> _testRealtimeDBConnection() async {
    try {
      final testPath = 'test_connection';
      await _realtimeDB.child(testPath).set({
        'test': 'Hello from Flutter',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      final snapshot = await _realtimeDB.child(testPath).get();
      debugPrint(snapshot.exists ? "Realtime DB read OK" : "Realtime DB read FAILED");
      // Optionally remove test data
      await _realtimeDB.child(testPath).remove();
    } catch (e) {
      debugPrint("Realtime DB test error: $e");
    }
  }

  // ========================
  // DEVICE MANAGEMENT
  // ========================
  Future<void> _loadUserDevices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.email).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data() ?? {};
      final householdId = userData['householdId'];
      if (householdId == null || householdId.toString().isEmpty) return;

      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      if (!householdDoc.exists) return;

      final deviceIds = List<String>.from(householdDoc.data()?['devices'] ?? []);
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

      // Attach listeners for the newly loaded devices
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to add a device.')));
        return;
      }

      final deviceRef = _firestore.collection('devices').doc(id);
      final deviceDoc = await deviceRef.get();
      if (!deviceDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device not found in the system.')));
        return;
      }

      final deviceData = deviceDoc.data() ?? {};
      final existingHouseholdId = deviceData['householdId'];
      if (existingHouseholdId != null && existingHouseholdId.toString().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This device is already assigned to another household.')));
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.email).get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User profile not found.')));
        return;
      }

      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are not assigned to any household.')));
        return;
      }

      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      if (!householdDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your household does not exist.')));
        return;
      }

      if (mounted) setState(() => _isAddingDevice = true);

      // Add to household devices array
      await _firestore.collection('households').doc(householdId).set({
        'devices': FieldValue.arrayUnion([id]),
      }, SetOptions(merge: true));

      // Update device doc
      await deviceRef.update({
        'householdId': householdId,
        'status': false,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Realtime DB setup
      final deviceType = deviceData['type'] ?? 'Unknown';
      final deviceName = deviceData['name'] ?? id;
      final realtimePath = '$householdId/$id';

      final canWriteToRTDB = await _testRealtimeDBWrite(householdId, id);
      if (canWriteToRTDB) {
        try {
          await _realtimeDB.child('$realtimePath/status').set(false).timeout(const Duration(seconds: 5));
          await _realtimeDB.child('$realtimePath/type').set(deviceType);
          await _realtimeDB.child('$realtimePath/name').set(deviceName);
          await _realtimeDB.child('$realtimePath/addedAt').set(DateTime.now().millisecondsSinceEpoch);
        } catch (e) {
          debugPrint("Realtime DB write error after adding device: $e");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device added but Realtime Database setup had issues.'), backgroundColor: Colors.orange));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device added but could not connect to Realtime Database.'), backgroundColor: Colors.orange));
      }

      await _loadUserDevices();

      if (mounted) setState(() => _isAddingDevice = false);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device added to household successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Error adding device: $e');
      if (mounted) setState(() => _isAddingDevice = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding device: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<bool> _testRealtimeDBWrite(String householdId, String deviceId) async {
    try {
      final testPath = '$householdId/test_$deviceId';
      final testData = {'test': 'write_test', 'timestamp': DateTime.now().millisecondsSinceEpoch};
      await _realtimeDB.child(testPath).set(testData).timeout(const Duration(seconds: 5));
      final snapshot = await _realtimeDB.child(testPath).get().timeout(const Duration(seconds: 3));
      if (snapshot.exists) {
        await _realtimeDB.child(testPath).remove();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Realtime DB write test error: $e");
      return false;
    }
  }

  // Add device dialog pane (unchanged)
  Future<void> _showAddDeviceDialog() async {
    final inHousehold = await _isUserInHousehold();
    if (!inHousehold) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be part of a household before adding a device.')));
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
              TextField(controller: controller, decoration: const InputDecoration(hintText: 'Device ID', border: OutlineInputBorder())),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, "scan"), child: const Text('Scan QR')),
            ElevatedButton(onPressed: () {
              final id = controller.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a Device ID')));
                return;
              }
              Navigator.pop(context, id);
            }, child: const Text('Add Device')),
          ],
        );
      },
    );

    if (res == "scan") {
      final scannedId = await Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerPage()));
      if (scannedId != null && scannedId.toString().isNotEmpty) {
        await _addDeviceById(scannedId.toString());
      }
    } else if (res != null && res.isNotEmpty) {
      await _addDeviceById(res);
    }
  }

  Future<bool> _isUserInHousehold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final userDoc = await _firestore.collection('users').doc(user.email).get();
      if (!userDoc.exists) return false;
      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) return false;
      final householdDoc = await _firestore.collection('households').doc(householdId).get();
      return householdDoc.exists;
    } catch (e) {
      debugPrint('Error checking household: $e');
      return false;
    }
  }

  // ========================
  // WEATHER METHODS
  // ========================
  Future<void> _loadWeather() async {
    try {
      await weatherAPI.fetchData();
      await weatherAPI.callApi();
      if (!mounted) return;
      setState(() {
        _stateName = weatherAPI.stateName ?? "Unknown";
        _cityName = weatherAPI.cityName ?? "Unknown";
        _temp = weatherAPI.currentTemp;
        _weatherLabel = weatherAPI.weatherMain ?? weatherAPI.weatherDescription ?? "Weather";
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
    } else if (id >= 300 && id < 600) {
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

    return SvgPicture.asset(svgPath, width: size, height: size, color: Colors.white);
  }

  // ========================
  // NOTIFICATION METHODS
  // ========================
  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Cancel previous subscription (safe guard)
    _notificationSubscription?.cancel();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.email)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = snapshot.docs.length;
      });
    }, onError: (e) {
      debugPrint('Notification listener error: $e');
    });
  }

  // ========================
  // AUTHENTICATION METHODS
  // ========================
  Future<void> _signout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  // ========================
  // DEVICE CONTROL METHODS
  // ========================
  void powerSwitchChanged(bool value, String deviceId) async {
    debugPrint("Switch changed for $deviceId -> $value");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.email).get();
      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) {
        debugPrint("No householdId found for user");
        return;
      }

      // Update local state immediately
      _deviceStatus.value = {..._deviceStatus.value, deviceId: value};

      // Persist to Firestore
      await _firestore.collection('devices').doc(deviceId).update({
        'status': value,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Persist to Realtime DB
      await _realtimeDB.child('$householdId/$deviceId/status').set(value);
    } catch (e) {
      debugPrint("Error toggling device: $e");
      // revert local state
      _deviceStatus.value = {..._deviceStatus.value, deviceId: !_deviceStatus.value[deviceId]!};
    }
  }

  Widget _pageForDevice(Map<String, dynamic> device) {
    return DeviceControlPage(
      deviceId: device['id'] ?? '',
      deviceName: device['name'] ?? 'Unknown Device',
      deviceType: device['type'] ?? 'Unknown Type',
    );
  }

  String _getStatusText(String deviceId, String deviceType) => _deviceStatus.value[deviceId] == true ? 'On' : 'Off';

  Color _getStatusColor(String deviceId, String deviceType) => _deviceStatus.value[deviceId] == true ? Colors.green : Colors.red;

  // ========================
  // ACTIVITY LOGGING
  // ========================
  Future<void> logActivity({required String action, String? deviceId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.email).get();
    final userData = userDoc.data() ?? {};
    final householdId = userData['householdId'];
    final username = userData['username'] ?? "Unknown User";

    if (householdId == null) return;

    await _firestore.collection('households').doc(householdId).collection('activityLogs').add({
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
                          onPressed: () => drawerController.toggleDrawer(),
                        ),
                        const Spacer(),

                        // ===================================
                        // NOTIFICATION BELL WITH RED DOT
                        // ===================================
                        Stack(
                          clipBehavior: Clip.none, // Ensure badge is visible outside bounds
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.notifications,
                                size: iconSize,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                // Open notification page
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationPage(),
                                  ),
                                );

                                // Refresh devices / notifications after returning
                                if (!mounted) return;
                                await _loadUserDevices();
                              },
                            ),

                            // Red dot / unread badge
                            if (_unreadNotificationCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: iconSize * 0.4,
                                    minHeight: iconSize * 0.4,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _unreadNotificationCount.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: iconSize * 0.25,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                             // Add Device Button
                            IconButton(
                              icon: Icon(
                                Icons.add_circle,
                                size: iconSize,
                                color: Colors.white,
                              ),
                              onPressed: _showAddDeviceDialog,
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
