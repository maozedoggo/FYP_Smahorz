import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final double horizontalPadding = 40.0;
  final double verticalPadding = 20.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.menu, size: 50, color: Colors.grey[800]),

                  Icon(Icons.person, size: 50, color: Colors.grey[800]),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome Home",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),

                  Text("Name", style: TextStyle(fontSize: 30)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
