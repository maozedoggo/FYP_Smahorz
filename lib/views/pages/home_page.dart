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
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  // ===========================================================================
  // DEPENDENCIES & SERVICES
  // ===========================================================================
  final WeatherService _weatherService = WeatherService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDB = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://smahorz-fyp-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref();

  Timer? _weatherCheckTimer;
  final AdvancedDrawerController _drawerController = AdvancedDrawerController();

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
  final ValueNotifier<Map<String, dynamic>> _deviceStatus = ValueNotifier({});
  bool _isAddingDevice = false;
  Map<String, StreamSubscription<DocumentSnapshot>> _deviceSubscriptions = {};

  // ===========================================================================
  // LIFECYCLE METHODS
  // ===========================================================================
  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupPeriodicWeatherChecks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  void _setupPeriodicWeatherChecks() {
    _weatherCheckTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (mounted) {
        _loadWeather();
      }
    });
  }

  void _initializeApp() async {
    try {
      await Permission.notification.isDenied.then((value) {
        if (value) {
          Permission.notification.request();
        }
      });
    } catch (e) {
      print("Notification permission error: $e");
    }

    _loadWeather();
    _loadUserDevices();
  }

  @override
  void dispose() {
    _weatherCheckTimer?.cancel();
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();

    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  // ===========================================================================
  // FIRESTORE METHODS
  // ===========================================================================
  void _setupFirestoreListeners() {
    print("Setting up Firestore listeners for ${_devices.length} devices");

    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();

    for (final device in _devices) {
      final deviceId = device['id'];
      final deviceType = device['type']?.toString().toLowerCase() ?? '';

      final subscription = _firestore
          .collection('devices')
          .doc(deviceId)
          .snapshots()
          .listen(
            (documentSnapshot) {
              if (documentSnapshot.exists && mounted) {
                final data = documentSnapshot.data();
                if (data != null && data.containsKey('status')) {
                  final statusData = data['status'];

                  if (deviceType.contains('parcel')) {
                    final bool insideStatus = statusData is Map
                        ? statusData['insideStatus'] == true
                        : false;
                    final bool outsideStatus = statusData is Map
                        ? statusData['outsideStatus'] == true
                        : false;

                    _deviceStatus.value = {
                      ..._deviceStatus.value,
                      deviceId: {
                        'insideStatus': insideStatus,
                        'outsideStatus': outsideStatus,
                      },
                    };
                  } else {
                    final bool isOn =
                        statusData == true ||
                        (statusData is Map
                            ? statusData['status'] == true
                            : false);
                    _deviceStatus.value = {
                      ..._deviceStatus.value,
                      deviceId: isOn,
                    };
                  }
                }
              }
            },
            onError: (error) {
              print("Firestore listener error for $deviceId: $error");
            },
          );

      _deviceSubscriptions[deviceId] = subscription;
    }
  }

  // ===========================================================================
  // REALTIME DATABASE METHODS
  // ===========================================================================
  void _setupRealtimeDBListeners() async {
    print("Setting up Realtime DB listeners for ${_devices.length} devices");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.email).get();
    final householdId = userDoc.data()?['householdId'];
    if (householdId == null) {
      print("No household ID found for Realtime DB listeners");
      return;
    }

    for (final device in _devices) {
      final deviceId = device['id'];
      final deviceType = device['type']?.toString().toLowerCase() ?? '';

      if (deviceType.contains('parcel')) {
        final insidePath = '$householdId/$deviceId/insideStatus';
        final outsidePath = '$householdId/$deviceId/outsideStatus';

        _realtimeDB.child(insidePath).onValue.listen((DatabaseEvent event) {
          if (event.snapshot.exists && mounted) {
            final insideStatus = event.snapshot.value == true;
            final currentStatus = _deviceStatus.value[deviceId] ?? {};
            _deviceStatus.value = {
              ..._deviceStatus.value,
              deviceId: {...currentStatus, 'insideStatus': insideStatus},
            };
          }
        });

        _realtimeDB.child(outsidePath).onValue.listen((DatabaseEvent event) {
          if (event.snapshot.exists && mounted) {
            final outsideStatus = event.snapshot.value == true;
            final currentStatus = _deviceStatus.value[deviceId] ?? {};
            _deviceStatus.value = {
              ..._deviceStatus.value,
              deviceId: {...currentStatus, 'outsideStatus': outsideStatus},
            };
          }
        });
      } else {
        final path = '$householdId/$deviceId/status';
        _realtimeDB.child(path).onValue.listen((DatabaseEvent event) {
          if (event.snapshot.exists && mounted) {
            final bool isOn = event.snapshot.value == true;
            _deviceStatus.value = {..._deviceStatus.value, deviceId: isOn};
          }
        });
      }
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
      final statusMap = <String, dynamic>{};

      for (final id in deviceIds) {
        final d = await _firestore.collection('devices').doc(id).get();
        if (!d.exists) continue;
        final dd = d.data() ?? {};
        loaded.add({
          'id': id,
          'name': dd['name'] ?? id,
          'type': dd['type'] ?? 'Unknown',
        });

        final deviceType = dd['type']?.toString().toLowerCase() ?? '';
        if (deviceType.contains('parcel')) {
          final statusData = dd['status'];
          statusMap[id] = {
            'insideStatus': statusData is Map
                ? statusData['insideStatus'] ?? false
                : false,
            'outsideStatus': statusData is Map
                ? statusData['outsideStatus'] ?? false
                : false,
          };
        } else {
          statusMap[id] = dd['status'] ?? false;
        }
      }

      if (!mounted) return;
      setState(() => _devices = loaded);
      _deviceStatus.value = statusMap;

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
            content: Text('You are not assigned to any household.'),
          ),
        );
        return;
      }

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

      if (mounted) {
        setState(() => _isAddingDevice = true);
      }

      await _firestore.collection('households').doc(householdId).set({
        'devices': FieldValue.arrayUnion([id]),
      }, SetOptions(merge: true));

      final deviceType = deviceData['type'] ?? 'Unknown';
      final deviceName = deviceData['name'] ?? id;

      await deviceRef.update({
        'householdId': householdId,
        'status': deviceType.toLowerCase().contains('parcel')
            ? {'insideStatus': false, 'outsideStatus': false}
            : false,
        'addedAt': FieldValue.serverTimestamp(),
      });

      final realtimePath = '$householdId/$id';
      if (deviceType.toLowerCase().contains('parcel')) {
        await _realtimeDB.child('$realtimePath/insideStatus').set(false);
        await _realtimeDB.child('$realtimePath/outsideStatus').set(false);
      } else {
        await _realtimeDB.child('$realtimePath/status').set(false);
      }

      await _realtimeDB.child('$realtimePath/type').set(deviceType);
      await _realtimeDB.child('$realtimePath/name').set(deviceName);
      await _realtimeDB
          .child('$realtimePath/addedAt')
          .set(DateTime.now().millisecondsSinceEpoch);

      await _loadUserDevices();

      if (mounted) {
        setState(() => _isAddingDevice = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device added to household successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error adding device: $e');
      if (mounted) {
        setState(() => _isAddingDevice = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding device: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
  // DEVICE CONTROL METHODS
  // ===========================================================================
  void powerSwitchChanged(
    bool value,
    String deviceId, [
    String switchType = 'status',
  ]) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.email)
          .get();
      final householdId = userDoc.data()?['householdId'];
      if (householdId == null || householdId.toString().isEmpty) return;

      _updateLocalDeviceStatus(deviceId, switchType, value);

      // FIX: Create the complete update data in one step
      final updateData = switchType == 'status'
          ? {'status': value, 'lastUpdated': FieldValue.serverTimestamp()}
          : {
              'status.$switchType': value,
              'lastUpdated': FieldValue.serverTimestamp(),
            };

      await _firestore.collection('devices').doc(deviceId).update(updateData);

      final path = switchType == 'status' ? 'status' : switchType;
      await _realtimeDB.child('$householdId/$deviceId/$path').set(value);
    } catch (e) {
      print("Error controlling device: $e");
      _updateLocalDeviceStatus(deviceId, switchType, !value);
    }
  }

  void _updateLocalDeviceStatus(
    String deviceId,
    String switchType,
    bool value,
  ) {
    final currentStatus = _deviceStatus.value[deviceId];

    if (switchType == 'insideStatus' || switchType == 'outsideStatus') {
      final Map<String, dynamic> statusMap = currentStatus is Map
          ? Map<String, dynamic>.from(currentStatus)
          : {};
      statusMap[switchType] = value;
      _deviceStatus.value = {..._deviceStatus.value, deviceId: statusMap};
    } else {
      _deviceStatus.value = {..._deviceStatus.value, deviceId: value};
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
    final status = _deviceStatus.value[deviceId];
    final deviceTypeLower = deviceType.toLowerCase();

    if (deviceTypeLower.contains('parcel')) {
      final inside = status is Map ? status['insideStatus'] ?? false : false;
      final outside = status is Map ? status['outsideStatus'] ?? false : false;
      return 'In: ${inside ? 'On' : 'Off'}, Out: ${outside ? 'On' : 'Off'}';
    } else {
      final isOn =
          status == true || (status is Map ? status['status'] ?? false : false);
      return isOn ? 'On' : 'Off';
    }
  }

  Color _getStatusColor(String deviceId, String deviceType) {
    final status = _deviceStatus.value[deviceId];
    final deviceTypeLower = deviceType.toLowerCase();

    if (deviceTypeLower.contains('parcel')) {
      final inside = status is Map ? status['insideStatus'] ?? false : false;
      final outside = status is Map ? status['outsideStatus'] ?? false : false;
      return (inside || outside) ? Colors.green : Colors.red;
    } else {
      final isOn =
          status == true || (status is Map ? status['status'] ?? false : false);
      return isOn ? Colors.green : Colors.red;
    }
  }

  // ===========================================================================
  // WEATHER METHODS
  // ===========================================================================
  Future<void> _loadWeather() async {
    try {
      await _weatherService.fetchData();
      await _weatherService.callApi();

      if (!mounted) return;
      setState(() {
        _stateName = _weatherService.stateName ?? "Unknown";
        _cityName = _weatherService.cityName ?? "Unknown";
        _temp = _weatherService.currentTemp;
        _weatherLabel =
            _weatherService.weatherMain ??
            _weatherService.weatherDescription ??
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
  // NAVIGATION HELPER METHODS
  // ===========================================================================
  Future<void> _navigateToPage(Widget page) async {
    _drawerController.hideDrawer();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadUserDevices();
  }

  Future<void> _navigateToDevicePage(Map<String, dynamic> dev) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _pageForDevice(dev)),
    );
    if (mounted) await _loadUserDevices();
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
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
            controller: _drawerController,
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
                                  : () => _drawerController.hideDrawer(),
                              leading: const Icon(Icons.home),
                              title: const Text('Home'),
                            ),
                            ListTile(
                              onTap: _isAddingDevice
                                  ? null
                                  : () => _navigateToPage(ProfilePage()),
                              leading: const Icon(Icons.account_circle_rounded),
                              title: const Text('Profile'),
                            ),
                            ListTile(
                              onTap: _isAddingDevice
                                  ? null
                                  : () => _navigateToPage(SettingsPage()),
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
                      // TOP APP BAR
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
                                  : () => _drawerController.toggleDrawer(),
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
                                  : () => _navigateToPage(NotificationPage()),
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

                      // WELCOME SECTION
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
                                      ConnectionState.waiting)
                                    return Text(
                                      "...",
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Colors.white70,
                                      ),
                                    );
                                  if (!snapshot.hasData ||
                                      !snapshot.data!.exists)
                                    return Text(
                                      "No username",
                                      style: TextStyle(
                                        fontSize: subtitleFontSize,
                                        color: Colors.white70,
                                      ),
                                    );
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

                      // WEATHER CARD
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
                                      _weatherService.statusID,
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

                      // DEVICES GRID
                      Expanded(
                        child: ValueListenableBuilder<Map<String, dynamic>>(
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
                                    : type.contains('parcel')
                                    ? 'lib/icons/parcel-box.png'
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
                                      : () => _navigateToDevicePage(dev),
                                  child: AbsorbPointer(
                                    absorbing: _isAddingDevice,
                                    child: ViewDevices(
                                      deviceType: dev['type'] ?? '',
                                      devicePart: statusText,
                                      iconPath: iconPath,
                                      status: statusMap[dev['id']] ?? false,
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

          if (_isAddingDevice)
            Container(
              color: Colors.black54,
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
