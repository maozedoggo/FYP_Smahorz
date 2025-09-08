import 'package:flutter/material.dart';
import 'package:smart_horizon_home/ui/view_devices.dart';
// import 'package:smart_horizon_home/views/pages/profile/profile_page.dart';
import 'package:smart_horizon_home/views/pages/profile-page/profile_page.dart';
// Make sure that the file 'profile_page.dart' defines a class named 'ProfilePage'
import 'package:smart_horizon_home/views/pages/settings-page/settings_page.dart';
import 'package:smart_horizon_home/views/pages/login/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final double horizontalPadding = 40.0;
  final double verticalPadding = 20.0;

  List smartDevices = [
    ["Parcel Box", "Outside", "lib/icons/door-open.png", true],
    ["Parcel Box", "Inside", "lib/icons/door-open.png", true],
    ["Cloth Hanger", "", "lib/icons/drying-rack.png", true],
  ];

  void powerSwitchChanged(bool value, int index) {
    setState(() {
      smartDevices[index][3] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Devices'),
              onTap: () {
                Navigator.pop(context); // Already on HomePage
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, size: 35, color: Colors.black),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Welcome bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Welcome Home",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  Text("Name", style: TextStyle(fontSize: 30)),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Divider(thickness: 4, color: Colors.grey),
            ),

            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(25),
                itemCount: smartDevices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  return ViewDevices(
                    deviceType: smartDevices[index][0],
                    devicePart: smartDevices[index][1],
                    iconPath: smartDevices[index][2],
                    status: smartDevices[index][3],
                    onChanged: (value) => powerSwitchChanged(value, index),
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
