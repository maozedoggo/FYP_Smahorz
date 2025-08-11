import 'package:flutter/material.dart';
import 'package:smart_horizon_home/login/login_page.dart'; // lowercase filename suggested

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(213, 255, 255, 255),
      ),
      home: LoginPage(),
    );
  }
}
