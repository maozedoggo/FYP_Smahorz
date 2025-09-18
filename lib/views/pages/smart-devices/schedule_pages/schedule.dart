import 'package:flutter/material.dart';

class SchedulePage extends StatefulWidget {
  final String deviceName;

  const SchedulePage({super.key, required this.deviceName});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
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
                  icon: const Icon(Icons.arrow_back),
                  color: Colors.black,
                  onPressed: () {
                    Navigator.pop(context); // go back to previous page
                  },
                ),
              ),
            ),

            // Calendar
            Container(
              
            )
          ],
        ),
      ),
    );
  }
}
