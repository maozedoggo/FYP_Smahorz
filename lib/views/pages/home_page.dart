import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:smart_horizon_home/ui/view_devices.dart';

import 'package:smart_horizon_home/services/weather_services.dart';
import 'package:smart_horizon_home/views/pages/notification-page/notification_page.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/clothe_hanger.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_outside.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_inside.dart';
import 'package:smart_horizon_home/views/pages/profile-page/profile_page.dart';
import 'package:smart_horizon_home/views/pages/settings-page/settings_page.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WeatherService weatherAPI = WeatherService();
  bool _isLoadingWeather = true;
  String _cityName = "City";
  int _temp = 0;
  String _stateName = "State";

  final List<List<dynamic>> smartDevices = [
    // legacy placeholder; kept for reference but not used when devices are loaded
    ["Parcel Box", "Outside", "lib/icons/door-open.png", true],
    ["Parcel Box", "Inside", "lib/icons/door-open.png", true],
    ["Cloth Hanger", "", "lib/icons/drying-rack.png", true],
  ];
  final List<Widget> devicePages = const [
    ParcelFront(),
    ParcelBack(),
    ClotheHanger(),
  ];
  // dynamic device list loaded from Firestore (devices assigned to the user)
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadUserDevices();
  }

  Future<void> _loadUserDevices() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();

      if (!userDoc.exists) return;
      final userData = userDoc.data() ?? {};
      final householdId = userData['householdId'];
      if (householdId == null || householdId.toString().isEmpty) {
        debugPrint("User has no householdId.");
        return;
      }

      // Fetch the household document
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      if (!householdDoc.exists) return;
      final householdData = householdDoc.data() ?? {};
      final deviceIds = List<String>.from(
        householdData['devices'] ?? <String>[],
      );

      // Fetch each device by ID
      final List<Map<String, dynamic>> loaded = [];
      for (final id in deviceIds) {
        final d = await FirebaseFirestore.instance
            .collection('devices')
            .doc(id)
            .get();
        if (!d.exists) continue;
        final dd = d.data() ?? {};
        loaded.add({
          'id': id,
          'name': dd['name'] ?? id,
          'type': dd['type'] ?? 'Unknown',
          'status': dd['status'] ?? true,
        });
      }

      if (!mounted) return;
      setState(() {
        _devices = loaded;
      });
    } catch (e) {
      debugPrint("Error loading household devices: $e");
    }
  }

  // Show dialog to add device by ID; fetches from 'devices' collection and records
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
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert Your Device ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Device ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = controller.text.trim();
              if (id.isEmpty) return;
              Navigator.pop(context, true);
              await _addDeviceById(id);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (res == true) {
      await _loadUserDevices();
    }
  }

  Future<bool> _isUserInHousehold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();

      if (!userDoc.exists) return false;
      final data = userDoc.data() ?? {};
      final householdId = data['householdId'];

      if (householdId == null || householdId.toString().isEmpty) {
        return false;
      }

      // Optionally check that the household exists
      final householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      return householdDoc.exists;
    } catch (e) {
      debugPrint('Error checking household: $e');
      return false;
    }
  }

  Future<void> _addDeviceById(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Verify device exists
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(id)
          .get();

      if (!deviceDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device not found.')));
        return;
      }

      // Get user's household ID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .get();

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

      // Add device to the household’s device list
      await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .set({
            'devices': FieldValue.arrayUnion([id]),
          }, SetOptions(merge: true));

      // Reload UI
      await _loadUserDevices();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device added to household.')),
      );
    } catch (e) {
      debugPrint('Error adding device to household: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding device: $e')));
    }
  }

  Future<void> _loadWeather() async {
    try {
      await weatherAPI.fetchData();
      await weatherAPI.callApi();

      if (!mounted) return;
      setState(() {
        _stateName = weatherAPI.stateName ?? "Unknown";
        _cityName = weatherAPI.cityName ?? "Unknown";
        _temp = weatherAPI.currentTemp;
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() => _isLoadingWeather = false);
      debugPrint("Error loading weather: $e");
    }
  }

  Future<void> _signout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false, // This removes all previous routes
    );
  }

  void powerSwitchChanged(bool value, int index) {
    setState(() {
      if (_devices.isNotEmpty) {
        if (index >= 0 && index < _devices.length) {
          _devices[index]['status'] = value;
        }
      } else {
        if (index >= 0 && index < smartDevices.length) {
          smartDevices[index][3] = value;
        }
      }
    });
  }

  Widget _pageForIndex(int index) {
    if (_devices.isNotEmpty) {
      final dev = _devices[index];
      final type = (dev['type'] ?? '').toString().toLowerCase();
      final name = (dev['name'] ?? '').toString().toLowerCase();
      if (type.contains('clothe') || type.contains('hanger'))
        return const ClotheHanger();
      if (type.contains('parcel') || name.contains('parcel')) {
        if (name.contains('inside') || type.contains('inside'))
          return const ParcelBack();
        return const ParcelFront();
      }
      return const ClotheHanger();
    } else {
      final type = (smartDevices[index][0] as String).toLowerCase();
      final part = (smartDevices[index][1] as String).toLowerCase();
      if (type.contains('parcel')) {
        if (part.contains('inside')) return const ParcelBack();
        return const ParcelFront();
      }
      if (type.contains('cloth') || type.contains('hanger'))
        return const ClotheHanger();
      return const ParcelFront();
    }
  }

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
      child: AdvancedDrawer(
        controller: drawerController,
        openScale: 0.7,
        openRatio: 0.65,
        animationCurve: Curves.easeInOutSine,
        animateChildDecoration: true,
        childDecoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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
                          onTap: () => drawerController.hideDrawer(),
                          leading: const Icon(Icons.home),
                          title: const Text('Home'),
                        ),
                        ListTile(
                          onTap: () {
                            drawerController.hideDrawer();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProfilePage()),
                            );
                          },
                          leading: const Icon(Icons.account_circle_rounded),
                          title: const Text('Profile'),
                        ),
                        ListTile(
                          onTap: () {
                            drawerController.hideDrawer();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SettingsPage()),
                            );
                          },
                          leading: const Icon(Icons.settings),
                          title: const Text('Settings'),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _signout,
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
                  // Top bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
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
                        IconButton(
                          icon: Icon(
                            Icons.notifications,
                            size: iconSize,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NotificationPage(),
                              ),
                            );
                          },
                        ),
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

                  // Welcome text
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
                            stream: FirebaseFirestore.instance
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
                              if (!snapshot.hasData || !snapshot.data!.exists) {
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

                  // Weather container
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(screenWidth * 0.05),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.2),
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.05,
                            ),
                            border: Border.all(
                              color: const Color.fromRGBO(255, 255, 255, 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.25,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05,
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
                                    Icon(
                                      Icons.cloud,
                                      size: screenWidth * 0.15,
                                      color: Colors.white,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Weather",
                                          style: TextStyle(
                                            fontSize: subtitleFontSize,
                                            color: Colors.white,
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
                    ),
                  ),

                  // Devices grid or empty state when no devices added
                  Expanded(
                    child: _devices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.device_hub,
                                  size: 56,
                                  color: Colors.white24,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "No devices added yet",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          )
                        : GridView.builder(
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
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _pageForIndex(index),
                                  ),
                                ),
                                child: ViewDevices(
                                  deviceType: dev['type'] ?? '',
                                  devicePart: dev['name'] ?? '',
                                  iconPath: iconPath,
                                  status: dev['status'] ?? true,
                                  onChanged: (value) =>
                                      powerSwitchChanged(value, index),
                                ),
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
    );
  }
}
