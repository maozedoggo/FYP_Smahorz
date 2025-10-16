import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/schedule_pages/schedule.dart';

class ParcelFront extends StatefulWidget {
  const ParcelFront({super.key});

  @override
  State<ParcelFront> createState() => _ParcelFrontState();
}

class _ParcelFrontState extends State<ParcelFront> {
  // State variable
  bool isUnlocked = false;
  String devicename = "Parcel Outside";

  void toggleUnlock() {
    setState(() {
      isUnlocked = !isUnlocked;
    });
  }

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
                  onPressed: () {
                    Navigator.pop(context); // go back to previous page
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Top Text
              const Text(
                "Security right on the palm of your hand",
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Outside Door Button
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 30,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.door_back_door,
                      color: Color.fromARGB(255, 0, 0, 0),
                      size: 40,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Outside Door",
                      style: TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Unlock Button
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  onPressed: toggleUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUnlocked ? Colors.red : Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isUnlocked ? "Lock" : "Unlock",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Add Schedule Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SchedulePage(deviceName: devicename),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.calendar_month,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
                label: const Text(
                  "Add Schedule",
                  style: TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
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
