// Libraries
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';

// Paths
import 'package:smart_horizon_home/services/weather_services.dart';
import 'package:smart_horizon_home/ui/view_devices.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/clothe_hanger.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_inside.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_outside.dart';

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

  // List of corresponding pages (same order as smartDevices)
  final List<Widget> devicePages = const [
    ParcelBack(),
    ParcelFront(),
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
      await weatherAPI.fetchCity();
      await weatherAPI.fetchState();
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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Drawer Controller Variable
    final drawerController = AdvancedDrawerController();

    return AdvancedDrawer(
      // Drawer appearance and settings
      controller: drawerController,
      openScale: 0.7,
      openRatio: 0.65,
      animationCurve: Curves.easeInOutSine,
      animateChildDecoration: true,
      childDecoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),

      // Drawer
      drawer: SafeArea(
        child: ListTileTheme(
          textColor: Colors.black,
          iconColor: Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ListTile(
                      onTap: () {
                        drawerController.hideDrawer();
                      },
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
                    animationDuration: Duration(milliseconds: 250),
                    enableFeedback: true,
                  ),
                  onPressed: () {
                    _signout();
                  },
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

              // Footer
              DefaultTextStyle(
                style: const TextStyle(fontSize: 14, color: Colors.black),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16.0),
                  child: const Text('Smart Horizon Home'),
                ),
              ),
            ],
          ),
        ),
      ),

      // Homepage screen
      child: Scaffold(

        body: SafeArea(
          
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
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(
                          Icons.menu,
                          size: 35,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          drawerController.toggleDrawer();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Welcome bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Home",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  if (uid != null)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("users")
                          .doc(uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            "...",
                            style: TextStyle(fontSize: 30),
                          );
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Text(
                            "No username",
                            style: TextStyle(fontSize: 30),
                          );
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;

                        return Text(
                          data?['username'] ?? "",
                          style: const TextStyle(fontSize: 30),
                        );
                      },
                    )
                  else
                    const Text("Not logged in", style: TextStyle(fontSize: 30)),
                ],
              ),
            ),

            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Divider(thickness: 4),
            ),

            // Weather UI
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 15,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isLoadingWeather
                    ? const Center(child: CircularProgressIndicator())
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Weather Icon (placeholder for now)
                          Icon(Icons.cloud, size: 60),

                          // Temperature
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Weather",
                                style: TextStyle(fontSize: 20),
                              ),

                              // Display temperature
                              Text(
                                "$_temp°C",
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // Location
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Display City
                                Text(
                                  _cityName,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                // State | District
                                Text(
                                  _stateName,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
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

            // Smart devices grid
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 25),
                itemCount: smartDevices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      onChanged: (value) => powerSwitchChanged(value, index),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
