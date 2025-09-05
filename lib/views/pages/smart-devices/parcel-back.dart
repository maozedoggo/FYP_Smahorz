import 'package:flutter/material.dart';

class ParcelBack extends StatefulWidget {
  const ParcelBack({super.key});

  @override
  State<ParcelBack> createState() => _ParcelBackState();
}

class _ParcelBackState extends State<ParcelBack> {
  // State variable
  bool isUnlocked = false;

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
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
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
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.meeting_room, color: Colors.orange, size: 40),
                  SizedBox(width: 10),
                  Text(
                    "Outside Door",
                    style: TextStyle(color: Colors.white, fontSize: 18),
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
                // TODO: implement navigation to schedule page
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
