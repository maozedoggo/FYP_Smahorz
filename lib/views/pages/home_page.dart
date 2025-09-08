import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:smart_horizon_home/ui/view_devices.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/clothe_hanger.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_inside.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/parcel_outside.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  // Smart Device Switch
  void powerSwitchChanged(bool value, int index) {
    setState(() {
      smartDevices[index][3] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Icon(Icons.menu, size: 35, color: Colors.grey[800])],
              ),
            ),

            const SizedBox(height: 20),

            // Welcome bar and user name
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

            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.0),
              child: Divider(thickness: 4),
            ),

            // Weather UI - Reduced vertical padding
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 15, // Reduced from 15
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Weather Icon
                    Icon(Icons.cloud, size: 60),

                    // Temperature
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Cloudy", style: TextStyle(fontSize: 20)),
                        Text(
                          "30C",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    // Location (constrained so it won’t overflow)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 120,
                      ), // tweak width to your liking
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Bangi,", style: TextStyle(fontSize: 20)),
                          Text(
                            "Selangor",
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

            // Smart devices grid - Reduced vertical padding
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                ), // Reduced vertical padding
                itemCount: smartDevices.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      // Navigate to corresponding page using the list
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
          ],
        ),
      ),
    );
  }
}
