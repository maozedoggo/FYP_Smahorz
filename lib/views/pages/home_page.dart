// Libraries
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';

// Paths
import 'package:smart_horizon_home/services/weather_services.dart';
import 'package:smart_horizon_home/ui/view_devices.dart';
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
  // Access weather service class
  final WeatherService weatherAPI = WeatherService();

  // Padding's variables
  final double horizontalPadding = 40.0;
  final double verticalPadding = 20.0;

  // List of Smart Devices [Name, Part, Icon, Status]
  final List<List<dynamic>> smartDevices = [
    ["Parcel Box", "Outside", "lib/icons/door-open.png", true],
    ["Parcel Box", "Inside", "lib/icons/door-open.png", true],
    ["Cloth Hanger", "", "lib/icons/drying-rack.png", true],
  ];

  // List of smartdevices pages
  final List<Widget> devicePages = const [
    ParcelFront(),
    ParcelBack(),
    ClotheHanger(),
  ];

  // Fetch weather data
  bool _isLoadingWeather = true;
  String _cityName = "City";
  int _temp = 0;
  String _stateName = "State";

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      await weatherAPI.fetchData();
      await weatherAPI.callApi();

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

  // Smart Device Switch
  void powerSwitchChanged(bool value, int index) {
    setState(() {
      smartDevices[index][3] = value;
    });
  }

  // Sign out
  Future<void> _signout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    final drawerController = AdvancedDrawerController();

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
                              MaterialPageRoute(
                                builder: (context) => ProfilePage(),
                              ),
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
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(),
                              ),
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
                      style: ButtonStyle(
                        animationDuration: const Duration(milliseconds: 250),
                      ),
                      onPressed: _signout,
                      icon: Icon(
                        Icons.logout_rounded,
                        color: Colors.red[700],
                        size: 28,
                      ),
                      label: Text(
                        "Logout",
                        style: TextStyle(color: Colors.red[700], fontSize: 18),
                      ),
                    ),
                  ),
                  DefaultTextStyle(
                    style: const TextStyle(fontSize: 14, color: Colors.white),
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
                      horizontal: 30,
                      vertical: verticalPadding,
                    ),
                    child: Row(
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(
                              Icons.menu,
                              size: 35,
                              color: Colors.white,
                            ),
                            onPressed: () => drawerController.toggleDrawer(),
                          ),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(
                              Icons.notifications,
                              size: 35,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(
                              Icons.add_circle,
                              size: 35,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Welcome text
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome Home",
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
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
                                return const Text(
                                  "...",
                                  style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.white70,
                                  ),
                                );
                              }
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return const Text(
                                  "No username",
                                  style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.white70,
                                  ),
                                );
                              }
                              final data =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              return Text(
                                data?['username'] ?? "",
                                style: const TextStyle(
                                  fontSize: 26,
                                  color: Colors.white,
                                  shadows: [
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
                          const Text(
                            "Not logged in",
                            style: TextStyle(
                              fontSize: 26,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.0,
                      vertical: 8,
                    ),
                    child: Divider(thickness: 3, color: Colors.white38),
                  ),

                  // Weather container
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 15,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(255, 255, 255, 0.2),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(255, 255, 255, 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
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
                                    const Icon(
                                      Icons.cloud,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Weather",
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          "$_temp°C",
                                          style: const TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
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
                                      constraints: const BoxConstraints(
                                        maxWidth: 120,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _cityName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            _stateName,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
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

                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      itemCount: smartDevices.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                          ),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => devicePages[index],
                              ),
                            );
                          },
                          child: ViewDevices(
                            deviceType: smartDevices[index][0],
                            devicePart: smartDevices[index][1],
                            iconPath: smartDevices[index][2],
                            status: smartDevices[index][3],
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
