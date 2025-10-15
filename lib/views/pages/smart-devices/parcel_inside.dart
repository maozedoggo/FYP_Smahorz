import 'package:flutter/material.dart';
import 'package:smart_horizon_home/views/pages/smart-devices/schedule_pages/schedule.dart';

class ParcelBack extends StatefulWidget {

  const ParcelBack({super.key});

  @override
  State<ParcelBack> createState() => _ParcelBackState();
}

class _ParcelBackState extends State<ParcelBack> {
  // State variable
  bool isUnlocked = false;
  String deviceName = "Parcel Inside";

  void toggleUnlock() {
    setState(() {
      isUnlocked = !isUnlocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.black,
                  onPressed: () {
                    Navigator.pop(context); // go back to previous page
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Outside Door Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 15,
                  horizontal: 30,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.meeting_room, color: Colors.orange, size: 40),
                    SizedBox(width: 10),
                    Text(
                      "Outside Door",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
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
                    builder: (context) => SchedulePage(deviceName: deviceName),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.calendar_month, color: Colors.amber),
              label: const Text(
                "Add Schedule",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
